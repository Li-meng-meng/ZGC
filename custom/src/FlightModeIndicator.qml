/****************************************************************************
 * ZGC 覆盖层：飞行模式指示器红底态前景反白
 * 同路径覆盖上游 qml/QGroundControl/Toolbar/FlightModeIndicator.qml
 * （经 CustomOverrideInterceptor 改写加载，注册见 custom/CMakeLists.txt custom_qml_overrides）。
 * 任务：ZFYZ-69 修复轮（红上红缺陷链 · P2 #5）。本件仅用于工具栏行内（唯一消费点
 * FlyViewToolBar）：连接态 chrome＝志翔红、断开态＝深灰黑(mapButton)，primaryButtonText
 * （白）在两态底色上均满足对比；上游 qgcPal.text 深色落红底为调研报告 §4.2 #5 缺陷。
 * 仅前景 token 变更，接口（fontPointSize/showIndicator/editMode 等）与上游一致：
 *   - 飞行模式图标/文字：qgcPal.text → qgcPal.primaryButtonText
 *   - VTOL 模式小字：上游未显式着色（默认深色），补显式 primaryButtonText 同参
 *   - 其余（抽屉内容 component 树）与上游逐行一致——抽屉弹出层为窗口底，不属红底态
 * 上游原文位置：src/Toolbar/FlightModeIndicator.qml
 * 本覆盖件为散文件加载，不享有 Toolbar 模块隐式导入；本件未实例化 Toolbar 模块内类型，
 * 沿用上游 import 列表即可（ToolIndicatorPage 等均属 QGroundControl.Controls）。
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Item {
    id:                     control
    Layout.preferredWidth:  mainLayout.width

    property bool   showIndicator:          true
    property bool   waitForParameters:      false

    property real fontPointSize:    ScreenTools.largeFontPointSize
    property var  activeVehicle:    QGroundControl.multiVehicleManager.activeVehicle
    property bool allowEditMode:    true
    property bool editMode:         false

    property bool _isVTOL:          activeVehicle ? activeVehicle.vtol : false
    property bool _vtolInFWDFlight: activeVehicle ? activeVehicle.vtolInFwdFlight : false
    property var  _vehicleInAir:    activeVehicle ? activeVehicle.flying || activeVehicle.landing : false

    QGCPalette { id: qgcPal }

    RowLayout {
        id:                     mainLayout
        anchors.verticalCenter: parent.verticalCenter
        spacing:                ScreenTools.defaultFontPixelWidth / 2

        QGCColoredImage {
            id:                     flightModeIcon
            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 3
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight
            fillMode:               Image.PreserveAspectFit
            mipmap:                 true
            color:                  qgcPal.primaryButtonText // ZGC: 工具栏行内红底态前景反白（原 qgcPal.text 深色落红底）— ZFYZ-69
            source:                 "/qmlimages/FlightModesComponentIcon.png"
        }

        QGCLabel {
            id:                 flightModeLabel
            text:               activeVehicle ? activeVehicle.flightMode : qsTr("N/A", "No data to display")
            color:              qgcPal.primaryButtonText // ZGC: 工具栏行内红底态前景反白（原 qgcPal.text 深色落红底）— ZFYZ-69
            font.pointSize:     fontPointSize

        }

        QGCLabel {
            id:                     vtolModeLabel
            Layout.alignment:       Qt.AlignVCenter
            horizontalAlignment:    Text.AlignHCenter
            text:                   _vtolInFWDFlight ? qsTr("FW\nVTOL") : qsTr("MR\nVTOL")
            color:                  qgcPal.primaryButtonText // ZGC: 上游未显式着色默认深色落红底，补显式反白同参 — ZFYZ-69
            font.pointSize:         ScreenTools.smallFontPointSize
            wrapMode:               Text.WordWrap
            visible:                _isVTOL
        }
    }

    MouseArea {
        anchors.fill:   mainLayout
        onClicked:      mainWindow.showIndicatorDrawer(drawerComponent, control)
    }

    Component {
        id: drawerComponent

        ToolIndicatorPage {
            showExpand:         true
            waitForParameters:                  false
            expandedComponentWaitForParameters: true

            contentComponent:    flightModeContentComponent
            expandedComponent:   flightModeExpandedComponent

            onExpandedChanged: {
                if (!expanded) {
                    editMode = false
                }
            }
        }
    }

    Component {
        id: flightModeContentComponent

        ColumnLayout {
            id:         modeColumn
            spacing:    ScreenTools.defaultFontPixelWidth / 2

            property var    activeVehicle:            QGroundControl.multiVehicleManager.activeVehicle
            property var    flightModeSettings:       QGroundControl.settingsManager.flightModeSettings
            property var    hiddenFlightModesFact:    null
            property var    hiddenFlightModesList:    []

            Component.onCompleted: {
                // Hidden flight modes are classified by firmware and vehicle class
                var hiddenFlightModesPropPrefix
                if (activeVehicle.px4Firmware) {
                    hiddenFlightModesPropPrefix = "px4HiddenFlightModes"
                } else if (activeVehicle.apmFirmware) {
                    hiddenFlightModesPropPrefix = "apmHiddenFlightModes"
                } else {
                    control.allowEditMode = false
                }
                if (control.allowEditMode) {
                    var hiddenFlightModesProp = hiddenFlightModesPropPrefix + activeVehicle.vehicleClassInternalName()
                    if (flightModeSettings.hasOwnProperty(hiddenFlightModesProp)) {
                        hiddenFlightModesFact = flightModeSettings[hiddenFlightModesProp]
                        // Split string into list of flight modes
                        if (hiddenFlightModesFact && hiddenFlightModesFact.value !== "") {
                            hiddenFlightModesList = hiddenFlightModesFact.value.split(",")
                        }
                    } else {
                        control.allowEditMode = false
                    }
                }
                hiddenModesLabel.calcVisible()
            }

            Connections {
                target: control
                function onEditModeChanged() {
                    if (editMode) {
                        for (var i=0; i<modeRepeater.count; i++) {
                            var button      = modeRepeater.itemAt(i).children[0]
                            var checkBox    = modeRepeater.itemAt(i).children[1]

                            checkBox.checked = !hiddenFlightModesList.find(item => { return item === button.text } )
                        }
                    }
                }
            }

            QGCDelayButton {
                id:                 vtolTransitionButton
                Layout.fillWidth:   true
                text:               _vtolInFWDFlight ? qsTr("Transition to Multi-Rotor") : qsTr("Transition to Fixed Wing")
                visible:            _isVTOL && _vehicleInAir

                onActivated: {
                    _activeVehicle.vtolInFwdFlight = !_vtolInFWDFlight
                    mainWindow.closeIndicatorDrawer()
                }
            }

            Repeater {
                id:     modeRepeater
                model:  activeVehicle ? activeVehicle.flightModes : []

                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth
                    visible: editMode || !hiddenFlightModesList.find(item => { return item === modelData } )

                    QGCDelayButton {
                        id:                 modeButton
                        text:               modelData
                        delay:              flightModeSettings.requireModeChangeConfirmation.rawValue ? defaultDelay : 0
                        Layout.fillWidth:   true

                        onActivated: {
                            if (editMode) {
                                parent.children[1].toggle()
                                parent.children[1].clicked()
                            } else {
                                //var controller = globals.guidedControllerFlyView
                                //controller.confirmAction(controller.actionSetFlightMode, modelData)
                                activeVehicle.flightMode = modelData
                                mainWindow.closeIndicatorDrawer()
                            }
                        }
                    }

                    QGCCheckBoxSlider {
                        visible: editMode

                        onClicked: {
                            hiddenFlightModesList = []
                            for (var i=0; i<modeRepeater.count; i++) {
                                var checkBox = modeRepeater.itemAt(i).children[1]
                                if (!checkBox.checked) {
                                    hiddenFlightModesList.push(modeRepeater.model[i])
                                }
                            }
                            hiddenFlightModesFact.value = hiddenFlightModesList.join(",")
                            hiddenModesLabel.calcVisible()
                        }
                    }
                }
            }

            QGCLabel {
                id:                     hiddenModesLabel
                text:                   qsTr("Some Modes Hidden")
                Layout.fillWidth:       true
                font.pointSize:         ScreenTools.smallFontPointSize
                horizontalAlignment:    Text.AlignHCenter
                visible:                false

                function calcVisible() {
                    hiddenModesLabel.visible = hiddenFlightModesList.length > 0
                }
            }
        }
    }

    Component {
        id: flightModeExpandedComponent

        ColumnLayout {
            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 60
            spacing:                margins / 2

            property var  qgcPal:               QGroundControl.globalPalette
            property real margins:              ScreenTools.defaultFontPixelHeight
            property var  flightModeSettings:   QGroundControl.settingsManager.flightModeSettings

            Loader {
                Layout.fillWidth:   true
                source:             _activeVehicle.expandedToolbarIndicatorSource("FlightMode")
            }

            SettingsGroupLayout {
                Layout.fillWidth:  true

                FactCheckBoxSlider {
                    Layout.fillWidth:   true
                    text:               qsTr("Click and Hold to Confirm Mode Change")
                    fact:               flightModeSettings.requireModeChangeConfirmation
                }

                RowLayout {
                    Layout.fillWidth:   true
                    enabled:            control.allowEditMode

                    QGCLabel {
                        Layout.fillWidth:   true
                        text:               qsTr("Edit Displayed Flight Modes")
                    }

                    QGCCheckBoxSlider {
                        onClicked: control.editMode = checked
                    }
                }

                LabelledButton {
                    Layout.fillWidth:   true
                    label:              qsTr("Flight Modes")
                    buttonText:         qsTr("Configure")
                    visible:            _activeVehicle.autopilotPlugin.knownVehicleComponentAvailable(AutoPilotPlugin.KnownFlightModesVehicleComponent) &&
                                            QGroundControl.corePlugin.showAdvancedUI

                    onClicked: {
                        mainWindow.showKnownVehicleComponentConfigPage(AutoPilotPlugin.KnownFlightModesVehicleComponent)
                        mainWindow.closeIndicatorDrawer()
                    }
                }
            }
        }
    }
}
