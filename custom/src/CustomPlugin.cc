/****************************************************************************
 * ZGC Custom Core Plugin
 * 由 custom-example/src/CustomPlugin.{h,cc} 引导，按任务 A2-20260903-brand-ui（ZFYZ-5）裁剪：
 * 移除 PerimeterScan 系列、CustomSettings、PX4 离线编辑默认值示例与示例调色板覆盖，
 * 仅保留品牌所需的 URL 拦截器与应用显示名机制。上游零修改。
 ****************************************************************************/

#include "CustomPlugin.h"

#include "QGCLoggingCategory.h"

#include <QtCore/QApplicationStatic>
#include <QtCore/QFile>
#include <QtGui/QGuiApplication>
#include <QtQml/QQmlApplicationEngine>

QGC_LOGGING_CATEGORY(CustomLog, "Custom.CustomPlugin")

Q_APPLICATION_STATIC(CustomPlugin, _customPluginInstance);

CustomPlugin::CustomPlugin(QObject *parent)
    : QGCCorePlugin(parent)
{
    qCDebug(CustomLog) << this;
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
