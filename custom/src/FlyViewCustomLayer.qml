/****************************************************************************
 * ZGC 覆盖层：Fly View 自定义叠加层——复飞急停常驻按钮
 * 同路径覆盖上游空壳 qml/QGroundControl/FlyView/FlyViewCustomLayer.qml
 * （上游注释明示供 custom build 以自己的 QML 覆盖该资源；经 CustomOverrideInterceptor
 * 改写加载，注册见 custom/CMakeLists.txt custom_qml_overrides）。任务：ZFYZ-轨迹复飞-批3。
 *
 * 上游契约逐字保留：parentToolInsets / totalToolInsets / mapControl 属性与
 * QGCToolInsets 透传（FlyView.qml 以 anchors.fill + z=+2 挂载，全屏视频时隐藏）。
 *
 * 急停按钮语义（任务单安全红线）：
 *   - 复飞任务执行窗口内（zgcTrajectorySafety.reflyMissionActive）常驻显示；
 *     窗口由 C++ 安全闸门维护：sendToVehicle 发起时刻置位，载具上锁解除或活动
 *     载具消失自动关闭——链路任何环节半途失败不会关闭窗口（宁可多显示）。
 *   - 可用性只依赖载具实时状态（armed && flying），不依赖复飞链路任何状态；
 *   - 动作走既有 GuidedActionsController：confirmAction(actionRTL) → 原生确认条
 *     （含 Smart RTL 选项）→ 原生 executeAction → Vehicle::guidedModeRTL。
 *     不自研飞控指令；一键后仍由原生确认条把握最终执行（防误触）。
 *   - 覆盖件不享模块隐式导入，import 全部显式声明。
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: _root

    property var parentToolInsets               // These insets tell you what screen real estate is available for positioning the controls in your overlay
    property var totalToolInsets:   _toolInsets // These are the insets for your custom overlay additions
    property var mapControl

    // since this file is a placeholder for the custom layer in a standard build, we will just pass through the parent insets
    QGCToolInsets {
        id:                     _toolInsets
        leftEdgeTopInset:       parentToolInsets.leftEdgeTopInset
        leftEdgeCenterInset:    parentToolInsets.leftEdgeCenterInset
        leftEdgeBottomInset:    parentToolInsets.leftEdgeBottomInset
        rightEdgeTopInset:      parentToolInsets.rightEdgeTopInset
        rightEdgeCenterInset:   parentToolInsets.rightEdgeCenterInset
        rightEdgeBottomInset:   parentToolInsets.rightEdgeBottomInset
        topEdgeLeftInset:       parentToolInsets.topEdgeLeftInset
        topEdgeCenterInset:     parentToolInsets.topEdgeCenterInset
        topEdgeRightInset:      parentToolInsets.topEdgeRightInset
        bottomEdgeLeftInset:    parentToolInsets.bottomEdgeLeftInset
        bottomEdgeCenterInset:  parentToolInsets.bottomEdgeCenterInset
        bottomEdgeRightInset:   parentToolInsets.bottomEdgeRightInset
    }

    // ZGC: 复飞急停常驻按钮——显示由安全闸门窗口驱动，可用性只看载具实时状态，
    // 动作直达原生 GuidedActionsController（急停不依赖复飞链路自身状态）— ZFYZ-轨迹复飞-批3
    readonly property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    Rectangle {
        id: emergencyStop

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom:           parent.bottom
        anchors.bottomMargin:     ScreenTools.defaultFontPixelHeight * 2

        visible:  zgcTrajectorySafety.reflyMissionActive && _root._activeVehicle
        // ZGC: 只依赖载具实时状态——即使复飞链路半途失败，只要载具在飞就能触发 — ZFYZ-轨迹复飞-批3
        enabled:  _root._activeVehicle && _root._activeVehicle.armed && _root._activeVehicle.flying
        opacity:  enabled ? 1 : 0.4

        radius: ScreenTools.defaultBorderRadius * 2
        color:  mouseArea.containsMouse ? qgcPal.buttonHighlight : qgcPal.primaryButton
        border.color: qgcPal.alertBorder
        border.width: 1

        width:  stopLayout.implicitWidth  + ScreenTools.defaultFontPixelWidth * 4
        height: stopLayout.implicitHeight + ScreenTools.defaultFontPixelHeight

        QGCPalette { id: qgcPal }

        ColumnLayout {
            id: stopLayout

            anchors.centerIn: parent
            spacing: ScreenTools.defaultFontPixelHeight * 0.2

            QGCLabel {
                Layout.alignment: Qt.AlignHCenter
                text:             qsTr("复飞任务执行中")
                font.pointSize:   ScreenTools.smallFontPointSize
                color:            qgcPal.primaryButtonText
            }

            QGCLabel {
                Layout.alignment: Qt.AlignHCenter
                text:             qsTr("复飞急停")
                font.pointSize:   ScreenTools.mediumFontPointSize
                font.bold:        true
                color:            qgcPal.primaryButtonText
            }
        }

        MouseArea {
            id: mouseArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onClicked: {
                // ZGC: 急停动作直达原生引导动作链（RTL＝中止任务并返航）；确认条/Smart RTL
                // 选项/最终执行全部由既有 GuidedActionsController 把握，零自研飞控指令。
                // 载具已在 RTL 模式等场景下确认条按原生 hideTrigger 自隐。— ZFYZ-轨迹复飞-批3
                globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionRTL)
            }
        }
    }
}
