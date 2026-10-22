/****************************************************************************
 * ZGC CrashDump — 崩溃自动取证钩子（Windows MiniDump，custom 层，上游零修改）
 *
 * 背景（ZFYZ-crashdump-hook）：取证报告 workspace/logs/ZFYZ-trajectory-refly-
 * crash-repro-20261022.md——上游 src/Utilities/Platform/Platform.cc 的
 * WindowsUnhandledExceptionFilter 打印后返回 EXCEPTION_EXECUTE_HANDLER ＋
 * SEM_NOGPFAULTERRORBOX，结构性短路 WER：进程崩溃永远无 dump，轨迹复飞冒烟
 * 崩溃 0/10 无法归因。本文件经 SetUnhandledExceptionFilter 覆挂自有过滤器：
 * 先写 MiniDump、再向 stderr 打一行故障信息（异常码/故障地址/所属模块），
 * 最后链回既有过滤器，完整保持上游语义（打印 "QGC: unhandled SEH" 并终止）。
 *
 * 挂接点（唯一）：CustomPlugin 构造函数最早处调用 InstallZgcCrashDumpFilter()。
 * 调用时序保证上游 filter 必已注册：main → Platform::initialize（注册 UEF）→
 * app.init() → QGCCorePlugin::instance()（QGCApplication.cc）→ 本调用。
 *
 * 回退路径：移除 CustomPlugin.cc 的挂接 1 行（含 include 共 2 行）＋删除本文件与
 * CrashDump.cc ＋还原 custom/CMakeLists.txt 的 CUSTOM_SOURCES/CUSTOM_LIBRARIES
 * 条目即可完全回退；上游 tracked 文件零依赖、零触碰。
 *
 * 自证钩子（仅取证自证用，勿用于生产排查以外的场景）：环境变量 ZGC_CRASH_TEST=1
 * 时，启动后约 5 秒经 QTimer 触发一次可控空指针写入，专供门禁实证 dump 管道
 * 端到端可用；默认（未设变量）零行为、零开销。
 ****************************************************************************/

#pragma once

/// 覆挂 ZGC 崩溃取证过滤器（保存既有过滤器指针并于取证后链回）。
/// 须在上游 Platform UEF 注册之后调用（CustomPlugin 构造函数时序已保证）；
/// 非 Windows 平台为空操作。
void InstallZgcCrashDumpFilter();
