#pragma once

#include <QtQml/QQmlAbstractUrlInterceptor>

#include "QGCCorePlugin.h"
#include "QGCOptions.h"  // ZGC: ZGCOptions 需 QGCOptions 基类 — ZFYZ-42
#include "QGCPalette.h"  // ZGC: paletteOverride 签名需要 QGCPalette::PaletteColorInfo_t — ZFYZ-30

class QQmlApplicationEngine;

Q_DECLARE_LOGGING_CATEGORY(CustomLog)

/*===========================================================================*/

/// F 轮字阶/密度系统：ZGC 全局密度选项——工具栏高度乘数 0.85（上游 QGCOptions 默认 1.0）。
/// 经 CustomPlugin::options() 注入，ScreenTools.qml _setBasePointSize 消费
/// （toolbarHeight = 3×defaultFontPixelHeight×乘数）。仅覆写密度项，其余选项与上游一致。
class ZGCOptions : public QGCOptions
{
    Q_OBJECT

public:
    explicit ZGCOptions(QObject *parent = nullptr)
        : QGCOptions(parent) {}

    // Overrides from QGCOptions

    /// 工具栏密度收紧（A3-20260909-roundF-typescale）。
    double toolbarHeightMultiplier() const final { return 0.85; }  // ZGC: 密度收紧 1.0 → 0.85 — ZFYZ-42
};

/*===========================================================================*/

class CustomPlugin : public QGCCorePlugin
{
    Q_OBJECT

public:
    explicit CustomPlugin(QObject *parent = nullptr);

    static QGCCorePlugin *instance();

    // Overrides from QGCCorePlugin

    /// 在主窗口创建前设置用户可见的应用显示名（志翔地面站）。
    void init() final;
    /// Attaches the override url interceptor so /Custom/... resources shadow upstream ones.
    QQmlApplicationEngine *createQmlApplicationEngine(QObject *parent) final;
    /// Releases the url interceptor attached in createQmlApplicationEngine before the engine is destroyed
    void destroyQmlApplicationEngine(QQmlApplicationEngine *qmlEngine) final;
    /// 品牌色板全量覆盖：对 QGCPalette 全部声明色名给出志翔品牌色值（Light/Dark 双主题）。— ZFYZ-30
    void paletteOverride(const QString &colorName, QGCPalette::PaletteColorInfo_t &colorInfo) final;
    /// F 轮字阶/密度：返回 ZGC 密度选项（工具栏高度乘数 0.85），替换上游默认 QGCOptions。— ZFYZ-42
    QGCOptions *options() final;

private:
    QQmlApplicationEngine *_qmlEngine = nullptr;
    ZGCOptions *_options = nullptr;  // ZGC: F 轮字阶/密度全局选项实例 — ZFYZ-42
    class CustomOverrideInterceptor *_urlInterceptor = nullptr;
};

/*===========================================================================*/

/// 将 qrc:/<path> 改写为 qrc:/Custom/<path>（若覆盖层提供同名资源）。
/// 品牌资源（Logo 等）与 QML 页面级覆盖均依赖此机制，上游零修改。
class CustomOverrideInterceptor : public QQmlAbstractUrlInterceptor
{
public:
    CustomOverrideInterceptor();

    QUrl intercept(const QUrl &url, QQmlAbstractUrlInterceptor::DataType type) final;
};
