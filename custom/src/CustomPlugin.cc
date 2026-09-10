/****************************************************************************
 * ZGC Custom Core Plugin
 * 由 custom-example/src/CustomPlugin.{h,cc} 引导，按任务 A2-20260903-brand-ui（ZFYZ-5）裁剪：
 * 移除 PerimeterScan 系列、CustomSettings、PX4 离线编辑默认值示例与示例调色板覆盖，
 * 仅保留品牌所需的 URL 拦截器与应用显示名机制。上游零修改。
 * A3d 界面现代化首轮（ZFYZ-30）：恢复并落地品牌调色板覆盖（paletteOverride），
 * 品牌主色沿用志翔红 #D94232（custom/res/Images/QGCLogoFull.png 主色）。
 ****************************************************************************/

#include "CustomPlugin.h"

#include "QGCLoggingCategory.h"
#include "QGCPalette.h"  // ZGC: paletteOverride 覆盖 QGCPalette 声明色名 — ZFYZ-30

#include <QtCore/QApplicationStatic>
#include <QtCore/QFile>
#include <QtGui/QGuiApplication>
#include <QtQml/QQmlApplicationEngine>

QGC_LOGGING_CATEGORY(CustomLog, "Custom.CustomPlugin")

Q_APPLICATION_STATIC(CustomPlugin, _customPluginInstance);

CustomPlugin::CustomPlugin(QObject *parent)
    : QGCCorePlugin(parent)
{
    // ZGC: F 轮字阶/密度系统——安装全局密度选项（工具栏高度乘数 0.85）。
    // 插件单例先于 QML 引擎创建，ScreenTools.qml 首次 _setBasePointSize 取值时已就绪。
    _options = new ZGCOptions(this);
    qCDebug(CustomLog) << this;
}

QGCOptions *CustomPlugin::options()
{
    // ZGC: F 轮字阶/密度——返回 ZGCOptions（上游返回默认 _defaultOptions）— ZFYZ-42
    return _options;
}

QGCCorePlugin *CustomPlugin::instance()
{
    return _customPluginInstance();
}

void CustomPlugin::init()
{
    QGCCorePlugin::init();

    // 应用显示名走覆盖层呈现（A3a）：QGC_APP_NAME 按 R1 裁决保持 ASCII，窗口标题跟随
    // Qt applicationDisplayName（上游未显式设置，此处为唯一来源），在 QGCApplication.cc
    // 创建 QML 根窗口之前生效。字符串用 \u 转义书写，保证代码与字面量为纯 ASCII，
    // 在任何 MSVC 源字符集下都能得到正确的 Unicode 码点（内容为“志翔地面站”）。
    QGuiApplication::setApplicationDisplayName(QStringLiteral(u"\u5FD7\u7FD4\u5730\u9762\u7AD9"));
}

/*===========================================================================*/
/* \u54C1\u724C\u8272\u677F\u5168\u91CF\u8986\u76D6\uFF08A \u9879 \u00B7 ZFYZ-30\uFF09                                          */
/*                                                                           */
/* \u54C1\u724C\u4E3B\u8272 #D94232\uFF08\u5FD7\u7FD4\u7EA2\uFF0C\u53D6\u81EA custom/res/Images/QGCLogoFull.png \u50CF\u7D20\u4E3B\u8272\uFF09\uFF0C */
/* \u8F85\u52A9\u9636 #E85C4A\uFF08\u63D0\u4EAE\uFF09/ #B93524\uFF08\u538B\u6697\uFF09\u3002\u8986\u76D6 QGCPalette.cc \u5168\u90E8 48 \u4E2A\u58F0\u660E\u8272\u540D  */
/* \uFF0838 \u4E2A\u4E3B\u9898\u8272 + 5 \u4E2A\u975E\u4E3B\u9898\u8272 + 5 \u4E2A\u5355\u503C\u8272\uFF09\uFF0Cindoor(Light)/outdoor(Dark) \u53CC\u4E3B\u9898  */
/* \u5404\u7ED9 Enabled/Disabled \u5168\u5957\u503C\u3002\u4E2D\u6027\u5E95\u8272\u6539\u4E3A\u65E0\u84DD\u76F8\u6696\u7070\u9636\uFF0C\u66FF\u6362\u4E0A\u6E38\u9ED8\u8BA4\u84DD\u9AD8\u4EAE\u4E0E      */
/* \u7070\u84DD primaryButton\uFF1B\u8BED\u4E49\u8272\uFF08\u7EFF/\u9EC4/\u6A59/\u7EA2/\u84DD\uFF09\u4EC5\u6309\u4E3B\u9898\u8C03\u5BF9\u6BD4\u5EA6\uFF0C\u6620\u5C04\u5173\u7CFB\u4E0D\u53D8\u3002     */
/*===========================================================================*/

void CustomPlugin::paletteOverride(const QString &colorName, QGCPalette::PaletteColorInfo_t &colorInfo)
{
    // \u2014\u2014 \u4E2D\u6027\u8868\u9762\u9636\uFF08\u7A97\u53E3/\u9634\u5F71/\u5206\u7EC4\uFF09\u2014\u2014
    if (colorName == QStringLiteral("window")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#ffffff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#f5f6f8");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#1a1d21");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#141619");
    } else if (colorName == QStringLiteral("windowTransparent")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#ccffffff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#ccffffff");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#cc1a1d21");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#cc141619");
    } else if (colorName == QStringLiteral("windowShadeLight")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#b8bdc4");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#c9ced4");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#3e444b");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#32373d");
    } else if (colorName == QStringLiteral("windowShade")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#eef0f3");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#dde1e6");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#23272c");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#1c1f23");
    } else if (colorName == QStringLiteral("windowShadeDark")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#e3e6ea");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#cdd2d8");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#141619");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#0f1113");

    // \u2014\u2014 \u6587\u672C \u2014\u2014
    } else if (colorName == QStringLiteral("text")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#23272c");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#7a8087");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#e8eaed");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#7a8087");
    } else if (colorName == QStringLiteral("warningText")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#c73524");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#c73524");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#ff6b5e");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#ff6b5e");

    // \u2014\u2014 \u6309\u94AE\u65CF \u2014\u2014
    } else if (colorName == QStringLiteral("button")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#ffffff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#f2f3f5");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#2a2e33");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#23262a");
    } else if (colorName == QStringLiteral("buttonBorder")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#c9ced4");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#dde1e6");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#3e444b");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#2e3237");
    } else if (colorName == QStringLiteral("buttonText")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#23272c");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#7a8087");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#e8eaed");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#7a8087");
    } else if (colorName == QStringLiteral("buttonHighlight")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#d94232");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#eef0f3");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#d94232");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#3a3f45");
    } else if (colorName == QStringLiteral("buttonHighlightText")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#ffffff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#7a8087");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#ffffff");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#7a8087");
    } else if (colorName == QStringLiteral("primaryButton")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#d94232");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#c9ced4");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#d94232");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#3a3f45");
    } else if (colorName == QStringLiteral("primaryButtonText")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#ffffff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#ffffff");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#ffffff");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#8a9098");

    // \u2014\u2014 \u8F93\u5165\u6846 \u2014\u2014
    } else if (colorName == QStringLiteral("textField")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#ffffff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#f2f3f5");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#23272c");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#2a2e33");
    } else if (colorName == QStringLiteral("textFieldText")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#23272c");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#9aa0a6");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#e8eaed");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#7a8087");

    // \u2014\u2014 \u5730\u56FE\u90E8\u4EF6 \u2014\u2014
    } else if (colorName == QStringLiteral("mapButton")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#23272c");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#6a7077");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#1f2226");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#141619");
    } else if (colorName == QStringLiteral("mapButtonHighlight")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#d94232");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#6a7077");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#d94232");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#3a3f45");
    } else if (colorName == QStringLiteral("mapIndicator")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#d94232");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#6a7077");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#d94232");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#3a3f45");
    } else if (colorName == QStringLiteral("mapIndicatorChild")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#b93524");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#6a7077");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#b93524");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#3a3f45");

    // \u2014\u2014 \u8BED\u4E49\u8272\uFF08\u6620\u5C04\u5173\u7CFB\u4E0D\u53D8\uFF0C\u4EC5\u8C03\u5404\u4E3B\u9898\u5BF9\u6BD4\u5EA6\uFF09\u2014\u2014
    } else if (colorName == QStringLiteral("colorGreen")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#12934a");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#12934a");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#3fd069");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#1f6b3c");
    } else if (colorName == QStringLiteral("colorYellow")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#b08900");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#b08900");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#ffd60a");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#8a7510");
    } else if (colorName == QStringLiteral("colorYellowGreen")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#6e9423");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#6e9423");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#9bd33a");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#5c7a20");
    } else if (colorName == QStringLiteral("colorOrange")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#c46a0a");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#c46a0a");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#ff9f0a");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#8f5a0a");
    } else if (colorName == QStringLiteral("colorRed")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#c73524");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#c73524");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#ff5d4d");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#8c2f26");
    } else if (colorName == QStringLiteral("colorGrey")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#7a8087");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#7a8087");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#9aa0a6");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#5f6368");
    } else if (colorName == QStringLiteral("colorBlue")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#1a72ff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#1a72ff");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#4c9fff");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#2f5e8c");

    // \u2014\u2014 \u544A\u8B66\u5F39\u7A97 \u2014\u2014
    } else if (colorName == QStringLiteral("alertBackground")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#f5b93c");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#f5b93c");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#f2b01e");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#f2b01e");
    } else if (colorName == QStringLiteral("alertBorder")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#b08900");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#b08900");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#7a5c10");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#7a5c10");
    } else if (colorName == QStringLiteral("alertText")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#1a1d21");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#1a1d21");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#1a1d21");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#1a1d21");

    // \u2014\u2014 \u5176\u4F59\u90E8\u4EF6 \u2014\u2014
    } else if (colorName == QStringLiteral("missionItemEditor")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#ffffff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#eef0f3");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#23272c");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#141619");
    } else if (colorName == QStringLiteral("toolStripHoverColor")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#e9ebee");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#dde1e6");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#2e3339");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#23272c");
    } else if (colorName == QStringLiteral("statusFailedText")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#23272c");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#7a8087");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#e8eaed");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#7a8087");
    } else if (colorName == QStringLiteral("statusPassedText")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#23272c");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#7a8087");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#e8eaed");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#7a8087");
    } else if (colorName == QStringLiteral("statusPendingText")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#23272c");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#7a8087");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#e8eaed");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#7a8087");
    } else if (colorName == QStringLiteral("toolbarBackground")) {
        // \u8FD1\u5B9E\u5E95\u5DE5\u5177\u680F\u8868\u9762\uFF08\u4E0A\u6E38\u4E3A\u5168\u900F\u660E\uFF09\uFF1BFly \u53F3\u4E0A\u9762\u677F/\u5DE5\u5177\u9875\u5DE5\u5177\u6761/Plan \u5DE5\u5177\u6761\u5171\u7528\u6B64\u5E95\u3002
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#f7ffffff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#f7ffffff");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#e61a1d21");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#e61a1d21");
    } else if (colorName == QStringLiteral("groupBorder")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#e85c4a");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#c9ced4");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#3e444b");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#2e3237");
    } else if (colorName == QStringLiteral("modifiedParamValue")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#c46a0a");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#c46a0a");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#ff9f0a");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#8f5a0a");

    // \u2014\u2014 \u975E\u4E3B\u9898\u8272\uFF08Disabled/Enabled \u4E24\u7EC4\uFF09\u2014\u2014
    } else if (colorName == QStringLiteral("brandingPurple")) {
        // \u6D88\u706D\u4E0A\u6E38\u54C1\u724C\u7D2B #4A2C6D\uFF1A\u7EDF\u4E00\u6539\u5199\u4E3A\u5FD7\u7FD4\u7EA2\uFF08Fly \u5DE5\u5177\u680F\u6E10\u53D8\u7B49\u6D88\u8D39\u70B9\u968F\u4E4B\u54C1\u724C\u5316\uFF09\u3002
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#d94232");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#d94232");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#d94232");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#d94232");
    } else if (colorName == QStringLiteral("brandingBlue")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#1a72ff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#48d6ff");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#4c9fff");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#48d6ff");
    } else if (colorName == QStringLiteral("toolStripFGColor")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#ffffff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#707070");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#ffffff");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#707070");
    } else if (colorName == QStringLiteral("photoCaptureButtonColor")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#ffffff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#707070");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#ffffff");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#707070");
    } else if (colorName == QStringLiteral("videoCaptureButtonColor")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#f32836");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#f89a9e");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#f32836");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#f89a9e");

    // \u2014\u2014 \u5355\u503C\u8272\uFF08\u56DB\u7EC4\u540C\u503C\uFF0C\u4E0D\u968F\u4E3B\u9898/\u72B6\u6001\u53D8\u5316\uFF09\u2014\u2014
    } else if (colorName == QStringLiteral("mapWidgetBorderLight")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#ffffff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#ffffff");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#ffffff");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#ffffff");
    } else if (colorName == QStringLiteral("mapWidgetBorderDark")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#141619");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#141619");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#141619");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#141619");
    } else if (colorName == QStringLiteral("mapMissionTrajectory")) {
        // \u4EFB\u52A1\u822A\u8FF9\u7EBF\uFF1A\u4E0A\u6E38\u6A59 #be781c \u2192 \u54C1\u724C\u7EA2\u63D0\u4EAE\u9636\uFF0C\u4FDD\u8BC1\u5730\u56FE\u74E6\u7247\u4E0A\u53EF\u89C1\u3002
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#e85c4a");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#e85c4a");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#e85c4a");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#e85c4a");
    } else if (colorName == QStringLiteral("surveyPolygonInterior")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#22b355");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#22b355");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#22b355");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#22b355");
    } else if (colorName == QStringLiteral("surveyPolygonTerrainCollision")) {
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]   = QColor("#e03131");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled]  = QColor("#e03131");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]    = QColor("#e03131");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]   = QColor("#e03131");
    }
}

QQmlApplicationEngine* CustomPlugin::createQmlApplicationEngine(QObject* parent)
{
    _qmlEngine = QGCCorePlugin::createQmlApplicationEngine(parent);
    // 模板中的 qrc:/qml/Custom/Widgets 与 qrc:/qml/Custom/Plan 导入路径已随示例模块裁剪（A2）。

    _urlInterceptor = new CustomOverrideInterceptor();
    _qmlEngine->addUrlInterceptor(_urlInterceptor);

    return _qmlEngine;
}

void CustomPlugin::destroyQmlApplicationEngine(QQmlApplicationEngine *qmlEngine)
{
    if (qmlEngine && (qmlEngine == _qmlEngine)) {
        qmlEngine->removeUrlInterceptor(_urlInterceptor);
        delete _urlInterceptor;
        _urlInterceptor = nullptr;
        _qmlEngine = nullptr;
    }

    QGCCorePlugin::destroyQmlApplicationEngine(qmlEngine);
}

/*===========================================================================*/

CustomOverrideInterceptor::CustomOverrideInterceptor()
    : QQmlAbstractUrlInterceptor()
{

}

QUrl CustomOverrideInterceptor::intercept(const QUrl &url, QQmlAbstractUrlInterceptor::DataType type)
{
    // Logo 替换即依赖此改写：QML 中的 "/res/QGCLogoFull.svg" 会命中
    // :/Custom/res/QGCLogoFull.svg（别名精确等于上游请求名），改写后加载 ZGC 品牌图。
    switch (type) {
    case QQmlAbstractUrlInterceptor::QmlFile:
    case QQmlAbstractUrlInterceptor::UrlString:
        if (url.scheme() == QStringLiteral("qrc")) {
            const QString origPath = url.path();
            const QString overrideRes = QStringLiteral(":/Custom%1").arg(origPath);
            if (QFile::exists(overrideRes)) {
                const QString relPath = overrideRes.mid(2);
                QUrl result;
                result.setScheme(QStringLiteral("qrc"));
                result.setPath('/' + relPath);
                return result;
            }
        }
        break;
    default:
        break;
    }

    return url;
}
