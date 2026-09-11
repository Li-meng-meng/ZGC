/****************************************************************************
 * ZGC 覆盖层：Plan View 工具栏重绘
 * 同路径覆盖上游 qml/QGroundControl/Toolbar/PlanViewToolBar.qml
 * （经 CustomOverrideInterceptor 改写加载，注册见 custom/CMakeLists.txt custom_qml_overrides）。
 * 任务：A3-20260908-modern1（ZFYZ-30）。仅视觉/样式层变更：
 *   - :27-34 底部 1px 黑色分隔线删除（连带 toolsFlickable 的 1px bottomMargin 收回）
 *   - :72/:104 任务同步进度条 colorGreen → primaryButton（随品牌色板收敛）
 *   - 全部 id / 属性 / 信号（toolbarButtonClicked）/ Connections / Timer 逻辑与上游一致
 * I 轮增量（A3-20260910-roundI-lookref，ZFYZ-59）：
 *   - P1 连接态 chrome 配色：条底随连接态绑定——断开＝深灰黑(mapButton)、连接＝志翔红(primaryButton)
 *   - 小同步进度段 primaryButton → buttonHighlightText（连接态红底红段不可见的连带修正）
 * 上游原文位置：src/Toolbar/PlanViewToolBar.qml
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.PlanView

Rectangle {
    id: _root
    width: parent.width
    height: ScreenTools.toolbarHeight
    // ZGC: P1 连接态 chrome 配色——断开＝深灰黑(mapButton)、连接＝志翔红(primaryButton)，与 FlyViewToolBar 同参；
    // 按钮自带 button 底（双主题自适对比），条上裸标签可读性见交付报告注记 — ZFYZ-59
    color: _activeVehicle ? qgcPal.primaryButton : qgcPal.mapButton

    property var planMasterController
    property bool showRallyPointsHelp: false

    signal toolbarButtonClicked()

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property real _controllerProgressPct: planMasterController.missionController.progressPct

    QGCPalette { id: qgcPal }

    // ZGC: 上游此处有 1px 黑色底部分隔线（Light 主题），卡片化工具栏不再需要 — ZFYZ-30

    QGCToolBarButton {
        id: qgcButton
        objectName: "toolbar_qgcLogo"
        height: parent.height
        icon.source: "/res/QGCLogoFull.svg"
        logo: true
        onClicked: mainWindow.showToolSelectDialog()
    }

    QGCFlickable {
        id: toolsFlickable
        anchors.left: qgcButton.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        contentWidth: toolIndicators.width
        flickableDirection: Flickable.HorizontalFlick

        PlanToolBarIndicators {
            id: toolIndicators
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            planMasterController: _root.planMasterController
            showRallyPointsHelp: _root.showRallyPointsHelp
            onToolbarButtonClicked: _root.toolbarButtonClicked()
        }
    }

    // Small mission download progress bar
    Rectangle {
        id: progressBar
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        height: 4
        width: _controllerProgressPct * parent.width
        color: qgcPal.buttonHighlightText // ZGC: 进度段转亮色——P1 连接态条底为志翔红，红底红段不可见（上游 colorGreen，ZFYZ-30 曾收敛为 primaryButton）— ZFYZ-59
        visible: false

        onVisibleChanged: {
            if (visible) {
                largeProgressBar._userHide = false
            }
        }
    }

    // Large mission download progress bar
    Rectangle {
        id: largeProgressBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height
        color: qgcPal.window
        visible: _showLargeProgress

        property bool _userHide: false
        property bool _showLargeProgress: progressBar.visible && !_userHide && qgcPal.globalTheme === QGCPalette.Light

        Connections {
            target: QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) { largeProgressBar._userHide = false }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: _controllerProgressPct * parent.width
            color: qgcPal.primaryButton // ZGC: 进度条随品牌色板收敛（上游 colorGreen）— ZFYZ-30
        }

        QGCLabel {
            anchors.centerIn: parent
            text: qsTr("Syncing Mission")
            font.pointSize: ScreenTools.largeFontPointSize
            visible: _controllerProgressPct !== 1
        }

        QGCLabel {
            anchors.centerIn: parent
            text: qsTr("Done")
            font.pointSize: ScreenTools.largeFontPointSize
            visible: _controllerProgressPct === 1
        }

        QGCLabel {
            anchors.margins: _margin
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: qsTr("Click anywhere to hide")

            property real _margin: ScreenTools.defaultFontPixelWidth / 2
        }

        MouseArea {
            anchors.fill: parent
            onClicked: largeProgressBar._userHide = true
        }
    }

    // Progress bar
    Connections {
        target: planMasterController.missionController

        function onProgressPctChanged(progressPct) {
            if (progressPct === 1) {
                if (_root.visible) {
                    resetProgressTimer.start()
                } else {
                    progressBar.visible = false
                }
            } else if (progressPct > 0) {
                progressBar.visible = true
            }
        }
    }

    Timer {
        id: resetProgressTimer
        interval: 3000
        onTriggered: progressBar.visible = false
    }
}
