/****************************************************************************
 * ZGC CrashDump 实现 — 见 CrashDump.h 头注释（回退路径/挂接点/自证钩子约定）— ZFYZ-crashdump-hook
 *
 * 崩溃上下文纪律：过滤器内禁止堆分配——仅栈缓冲 ＋ WinAPI 直呼（字符串格式化用
 * user32 wsprintfW 而非 CRT，宽转窄用 WideCharToMultiByte，杜绝 CRT/locale 路径）。
 * 命名对齐上游 src/Utilities/Platform/Platform.cc（文件级静态 g_ 前缀、匿名命名空间）。
 ****************************************************************************/

#include "CrashDump.h"

#include <QtCore/QtGlobal>  // Q_OS_WIN（平台守卫分支之前必须先取到定义）— ZFYZ-crashdump-hook

#if defined(Q_OS_WIN)
    #include <windows.h>
    #include <DbgHelp.h>
#endif

#if defined(Q_OS_WIN)
#include <chrono>

#include <QtCore/QTimer>

#include "QGCLoggingCategory.h"

QGC_LOGGING_CATEGORY(ZgcCrashDumpLog, "Custom.CrashDump")

namespace {

LPTOP_LEVEL_EXCEPTION_FILTER g_zgcPrevUef = nullptr;
volatile LONG g_zgcInFilter = 0;
void *volatile g_zgcProbeAddr = nullptr;  // 自证钩子崩溃点地址（volatile 防编译器/静态分析折叠为常量 null）

/// 定位故障地址所属模块名（GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS，栈缓冲收容）。
void moduleForAddress(const void *address, wchar_t *buf, DWORD bufChars)
{
    buf[0] = L'\0';
    HMODULE module = nullptr;
    const DWORD flags = GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT;
    if (!GetModuleHandleExW(flags, reinterpret_cast<LPCWSTR>(address), &module) || !module) {
        return;
    }
    (void) GetModuleFileNameW(module, buf, bufChars);
}

/// dump 目录：exe 同级 crash-dumps/（不存在则创建）；创建失败回退 %TEMP%。
/// 返回值：目录串（不含结尾分隔符）是否就绪。
bool crashDumpDir(wchar_t *dir, DWORD dirChars)
{
    wchar_t exePath[MAX_PATH] = {};
    const DWORD exeLen = GetModuleFileNameW(nullptr, exePath, MAX_PATH);
    if ((exeLen > 0) && (exeLen < MAX_PATH)) {
        DWORD cut = exeLen;
        while ((cut > 0) && (exePath[cut - 1] != L'\\') && (exePath[cut - 1] != L'/')) {
            --cut;
        }
        // ZGC: 连尾分隔符一起剥掉——原先 exePath[cut] 截断会保留尾分隔符，与下方 "\\%s" 拼接形成双分隔符（门禁 stderr 实证）— ZFYZ-crashdump-hook
        exePath[(cut > 0) ? (cut - 1) : 0] = L'\0';
        if (wsprintfW(dir, L"%s\\crash-dumps", exePath) > 0) {
            if (CreateDirectoryW(dir, nullptr) || (GetLastError() == ERROR_ALREADY_EXISTS)) {
                return true;
            }
        }
    }

    // 回退 %TEMP%（GetTempPathW 结果以反斜杠结尾，剥掉以统一拼接规则）
    const DWORD tempLen = GetTempPathW(dirChars, dir);
    if ((tempLen > 0) && (tempLen < dirChars)) {
        if ((dir[tempLen - 1] == L'\\') || (dir[tempLen - 1] == L'/')) {
            dir[tempLen - 1] = L'\0';
        }
        return true;
    }
    return false;
}

/// 写 MiniDump（MiniDumpNormal｜WithThreadInfo｜WithUnloadedModules，定位够用、不必全内存）。
bool writeMiniDump(const wchar_t *fullPath, EXCEPTION_POINTERS *ep)
{
    const HANDLE hFile = CreateFileW(fullPath, GENERIC_WRITE, 0, nullptr,
                                     CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (hFile == INVALID_HANDLE_VALUE) {
        return false;
    }

    MINIDUMP_EXCEPTION_INFORMATION mei;
    mei.ThreadId = GetCurrentThreadId();
    mei.ExceptionPointers = ep;
    mei.ClientPointers = FALSE;
    const MINIDUMP_TYPE dumpType = static_cast<MINIDUMP_TYPE>(
        MiniDumpNormal | MiniDumpWithThreadInfo | MiniDumpWithUnloadedModules);

    const BOOL ok = MiniDumpWriteDump(GetCurrentProcess(), GetCurrentProcessId(), hFile, dumpType,
                                      ep ? &mei : nullptr, nullptr, nullptr);
    (void) CloseHandle(hFile);
    return ok != FALSE;
}

/// stderr 直呼一行（宽串经 WideCharToMultiByte 转窄，全程栈缓冲）。
void stderrLine(const wchar_t *wide)
{
    char narrow[1024] = {};
    const int narrowLen = WideCharToMultiByte(CP_ACP, 0, wide, -1, narrow, static_cast<int>(sizeof(narrow)),
                                              nullptr, nullptr);
    if (narrowLen <= 0) {
        return;
    }
    const HANDLE hStdErr = GetStdHandle(STD_ERROR_HANDLE);
    if (hStdErr && (hStdErr != INVALID_HANDLE_VALUE)) {
        DWORD written = 0;
        (void) WriteFile(hStdErr, narrow, static_cast<DWORD>(narrowLen) - 1, &written, nullptr);
    }
}

/// 链回既有过滤器（上游 Platform.cc WindowsUnhandledExceptionFilter），保持上游语义
/// （打印 "QGC: unhandled SEH" 并以 EXCEPTION_EXECUTE_HANDLER 终止）。
LONG chainToPrev(EXCEPTION_POINTERS *ep)
{
    if (g_zgcPrevUef) {
        return g_zgcPrevUef(ep);
    }
    return EXCEPTION_EXECUTE_HANDLER;
}

LONG WINAPI ZgcCrashDumpFilter(EXCEPTION_POINTERS *ep)
{
    // 重入保护：本过滤器自身若再崩溃，不递归取证，立即转交上游语义。
    if (InterlockedCompareExchange(&g_zgcInFilter, 1, 0) != 0) {
        return chainToPrev(ep);
    }

    // ① MiniDump：exe 同级 crash-dumps/ZGC-crash-<yyyyMMdd-HHmmss>-<pid>.dmp，失败回退 %TEMP%
    wchar_t dir[MAX_PATH + 32] = {};
    if (crashDumpDir(dir, MAX_PATH + 32)) {
        SYSTEMTIME st = {};
        GetLocalTime(&st);
        wchar_t fileName[96] = {};
        (void) wsprintfW(fileName, L"ZGC-crash-%04u%02u%02u-%02u%02u%02u-%u.dmp",
                         st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond,
                         static_cast<unsigned>(GetCurrentProcessId()));
        wchar_t fullPath[MAX_PATH + 160] = {};
        (void) wsprintfW(fullPath, L"%s\\%s", dir, fileName);
        const bool dumpOk = writeMiniDump(fullPath, ep);
        // dump 落点单独一行，供取证/门禁确认端到端管道
        stderrLine(dumpOk ? fullPath : L"ZGC: minidump FAILED\n");
    } else {
        stderrLine(L"ZGC: minidump dir FAILED\n");
    }

    // ② 一行故障信息：异常码、故障地址、所属模块名
    const DWORD code = (ep && ep->ExceptionRecord) ? ep->ExceptionRecord->ExceptionCode : 0;
    const void *faultAddr = (ep && ep->ExceptionRecord) ? ep->ExceptionRecord->ExceptionAddress : nullptr;
    wchar_t module[MAX_PATH + 1] = {};
    moduleForAddress(faultAddr, module, MAX_PATH);
    wchar_t faultLine[MAX_PATH + 128] = {};
    (void) wsprintfW(faultLine, L"ZGC: crash 0x%08X at 0x%p in %s\n",
                     static_cast<unsigned>(code), faultAddr, module);
    (void) OutputDebugStringW(faultLine);
    stderrLine(faultLine);

    return chainToPrev(ep);  // ③ 保持上游语义
}

/// 自证钩子（仅取证自证用）：ZGC_CRASH_TEST=1 时启动后约 5 秒触发一次可控空指针写入，
/// 实证 dump 管道端到端。默认（未设变量）零行为、零开销。
void armCrashSelfTest()
{
    if (!qEnvironmentVariableIsSet("ZGC_CRASH_TEST")) {
        return;
    }
    (void) QTimer::singleShot(std::chrono::seconds(5), []() {
        qCWarning(ZgcCrashDumpLog) << "ZGC_CRASH_TEST: writing through null pointer now (intentional crash)";
        *static_cast<volatile int *>(g_zgcProbeAddr) = 0x5A;  // 0xC0000005，进入 ZgcCrashDumpFilter
    });
}

} // namespace

void InstallZgcCrashDumpFilter()
{
    g_zgcPrevUef = SetUnhandledExceptionFilter(ZgcCrashDumpFilter);
    armCrashSelfTest();
}
#else  // !Q_OS_WIN
void InstallZgcCrashDumpFilter()
{
}
#endif // Q_OS_WIN
