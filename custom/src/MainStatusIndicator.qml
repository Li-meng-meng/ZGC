/****************************************************************************
 * ZGC 覆盖层：主状态指示器语义色胶囊化
 * 同路径覆盖上游 qml/QGroundControl/Toolbar/MainStatusIndicator.qml
 * （经 CustomOverrideInterceptor 改写加载，注册见 custom/CMakeLists.txt custom_qml_overrides）。
 * 任务：A3-20260908-modern1（ZFYZ-30）。仅视觉/样式层变更：
 *   - :49-105 裸 "red"/"green"/"yellow"/brandingPurple 字符串色 → qgcPal 语义色
 *     （colorRed/colorGreen/colorYellow/primaryButton），条件→色相映射关系不变
 *   - 主状态标签增加语义色胶囊底（仅有机连接时显示），文本色保持 qgcPal.text
 *   - 全部 id / 函数（mainStatusText/dropMainStatusIndicator 等）/信号接口与上游一致
 * 二轮修复（ZFYZ-30 · A4 门禁退回）：补显式 import QGroundControl.Toolbar ——
 *   覆盖件自 :/Custom/qml/ 散文件加载，不享有 Toolbar 模块隐式导入，
 *   模块内类型（MainStatusIndicatorOfflinePage/VehicleMessageList）需显式 import
 * I 轮增量（A3-20260910-roundI-lookref，ZFYZ-59）：
 *   - P1 语义状态色本地化：mainStatusText() 的语义赋值目标 _mainStatusBGColor（上游经上下文链
 *     写外层工具栏 chrome）→ 本地 _mainStatusSemanticColor，绿/黄/红映射关系不变，仅驱动状态胶囊；
 *     chrome 改由 FlyViewToolBar 连接态绑定接管（断开＝深灰黑、连接＝志翔红）
 *   - P4 胶囊条扩展：新增 RTK 固定态胶囊（gpsRtk.valid，绿色）与电池胶囊（最低电量节，
 *     threshold1/2 三档配色同 BatteryIndicator），飞行模式由相邻 FlightModeIndicator 承担
 * 上游原文位置：src/Toolbar/MainStatusIndicator.qml
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Toolbar

RowLayout {
    id:         control
    spacing:    ScreenTools.defaultFontPixelWidth

    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool   _armed:             _activeVehicle ? _activeVehicle.armed : false
    property real   _margins:           ScreenTools.defaultFontPixelWidth
    property real   _spacing:           ScreenTools.defaultFontPixelWidth / 2
    property bool   _allowForceArm:      false
    property bool   _healthAndArmingChecksSupported: _activeVehicle ? _activeVehicle.healthAndArmingCheckReport.supported : false
    property bool   _vehicleFlies:      _activeVehicle ? _activeVehicle.airShip || _activeVehicle.fixedWing || _activeVehicle.vtol || _activeVehicle.multiRotor : false
    property var    _vehicleInAir:      _activeVehicle ? _activeVehicle.flying || _activeVehicle.landing : false
    property bool   _vtolInFWDFlight:   _activeVehicle ? _activeVehicle.vtolInFwdFlight : false

    // ZGC: P1 语义状态色本地化——上游 mainStatusText() 经 QML 上下文链把语义色写入外层
    // 工具栏 _mainStatusBGColor（chrome），I 轮 chrome 改为连接态绑定后，语义色映射（C 轮
    // 建立的绿/黄/红通道，映射关系不变）改写入本本地属性，仅驱动状态胶囊 — ZFYZ-59
    property color  _mainStatusSemanticColor: qgcPal.mapButton

    function dropMainStatusIndicator() {
        let overallStatusComponent = _activeVehicle ? overallStatusIndicatorPage : overallStatusOfflineIndicatorPage
        mainWindow.showIndicatorDrawer(overallStatusComponent, control)
    }

    QGCPalette { id: qgcPal }

    QGCLabel {
        id:                 mainStatusLabel
        Layout.fillHeight:  true
        Layout.preferredWidth: contentWidth + (vehicleMessagesIcon.visible ? vehicleMessagesIcon.width + control.spacing : 0)
        verticalAlignment:  Text.AlignVCenter
        text:               mainStatusText()
        // ZGC: 断开态 chrome 为深灰黑实底，标签转亮色文字保双主题对比 — ZFYZ-59
        color:              _activeVehicle ? qgcPal.text : qgcPal.primaryButtonText
        font.pointSize:     ScreenTools.largeFontPointSize

        // ZGC: 语义色胶囊底——随 _mainStatusSemanticColor 语义色（P1 起语义通道本地化），仅视觉承载 — ZFYZ-30/ZFYZ-59
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left:           parent.left
            anchors.right:          parent.right
            anchors.leftMargin:     -(ScreenTools.defaultFontPixelWidth / 2)
            anchors.rightMargin:    -(ScreenTools.defaultFontPixelWidth / 2)
            height:                 mainStatusLabel.contentHeight + (ScreenTools.defaultFontPixelHeight / 2)
            z:                      -1
            radius:                 height / 2
            color:                  Qt.rgba(_mainStatusSemanticColor.r, _mainStatusSemanticColor.g, _mainStatusSemanticColor.b, 0.2)
            border.color:           Qt.rgba(_mainStatusSemanticColor.r, _mainStatusSemanticColor.g, _mainStatusSemanticColor.b, 0.55)
            border.width:           1
            visible:                _activeVehicle
        }

        property string _commLostText:      qsTr("Comms Lost")
        property string _readyToFlyText:    qsTr("Ready")
        property string _notReadyToFlyText: qsTr("Not Ready")
        property string _disconnectedText:  qsTr("Disconnected - Click to manually connect")
        property string _armedText:         qsTr("Armed")
        property string _flyingText:        qsTr("Flying")
        property string _landingText:       qsTr("Landing")

        function mainStatusText() {
            var statusText
            if (_activeVehicle) {
                if (_communicationLost) {
                    _mainStatusSemanticColor = qgcPal.colorRed // ZGC: 语义通道本地化（原写 _mainStatusBGColor），映射不变 — ZFYZ-59
                    return mainStatusLabel._commLostText
                }
                if (_activeVehicle.armed) {
                    _mainStatusSemanticColor = qgcPal.colorGreen // ZGC: 语义通道本地化（原写 _mainStatusBGColor），映射不变 — ZFYZ-59

                    if (_healthAndArmingChecksSupported) {
                        if (_activeVehicle.healthAndArmingCheckReport.canArm) {
                            if (_activeVehicle.healthAndArmingCheckReport.hasWarningsOrErrors) {
                                _mainStatusSemanticColor = qgcPal.colorYellow // ZGC: 语义通道本地化（原写 _mainStatusBGColor），映射不变 — ZFYZ-59
                            }
                        } else {
                            _mainStatusSemanticColor = qgcPal.colorRed // ZGC: 语义通道本地化（原写 _mainStatusBGColor），映射不变 — ZFYZ-59
                        }
                    }

                    if (_activeVehicle.flying) {
                        return mainStatusLabel._flyingText
                    } else if (_activeVehicle.landing) {
                        return mainStatusLabel._landingText
                    } else {
                        return mainStatusLabel._armedText
                    }
                } else {
                    if (_healthAndArmingChecksSupported) {
                        if (_activeVehicle.healthAndArmingCheckReport.canArm) {
                            if (_activeVehicle.healthAndArmingCheckReport.hasWarningsOrErrors) {
                                _mainStatusSemanticColor = qgcPal.colorYellow // ZGC: 语义通道本地化（原写 _mainStatusBGColor），映射不变 — ZFYZ-59
                            } else {
                                _mainStatusSemanticColor = qgcPal.colorGreen // ZGC: 语义通道本地化（原写 _mainStatusBGColor），映射不变 — ZFYZ-59
                            }
                            return mainStatusLabel._readyToFlyText
                        } else {
                            _mainStatusSemanticColor = qgcPal.colorRed // ZGC: 语义通道本地化（原写 _mainStatusBGColor），映射不变 — ZFYZ-59
                            return mainStatusLabel._notReadyToFlyText
                        }
                    } else if (_activeVehicle.readyToFlyAvailable) {
                        if (_activeVehicle.readyToFly) {
                            _mainStatusSemanticColor = qgcPal.colorGreen // ZGC: 语义通道本地化（原写 _mainStatusBGColor），映射不变 — ZFYZ-59
                            return mainStatusLabel._readyToFlyText
                        } else {
                            _mainStatusSemanticColor = qgcPal.colorYellow // ZGC: 语义通道本地化（原写 _mainStatusBGColor），映射不变 — ZFYZ-59
                            return mainStatusLabel._notReadyToFlyText
                        }
                    } else {
                        // Best we can do is determine readiness based on AutoPilot component setup and health indicators from SYS_STATUS
                        if (_activeVehicle.allSensorsHealthy && _activeVehicle.autopilotPlugin.setupComplete) {
                            _mainStatusSemanticColor = qgcPal.colorGreen // ZGC: 语义通道本地化（原写 _mainStatusBGColor），映射不变 — ZFYZ-59
                            return mainStatusLabel._readyToFlyText
                        } else {
                            _mainStatusSemanticColor = qgcPal.colorYellow // ZGC: 语义通道本地化（原写 _mainStatusBGColor），映射不变 — ZFYZ-59
                            return mainStatusLabel._notReadyToFlyText
                        }
                    }
                }
            } else {
                _mainStatusSemanticColor = qgcPal.mapButton // ZGC: 离线态走中性深灰（胶囊隐藏不显示），chrome 由工具栏连接态绑定接管 — ZFYZ-59
                return mainStatusLabel._disconnectedText
            }
        }

        QGCColoredImage {
            id:                     vehicleMessagesIcon
            anchors.verticalCenter: parent.verticalCenter
            anchors.right:          parent.right
            width:                  ScreenTools.defaultFontPixelWidth * 2
            height:                 width
            source:                 "/res/VehicleMessages.png"
            color:                  getIconColor()
            sourceSize.width:       width
            fillMode:               Image.PreserveAspectFit
            visible:                _activeVehicle && _activeVehicle.messageCount > 0

            function getIconColor() {
                let iconColor = qgcPal.text
                if (_activeVehicle) {
                    if (_activeVehicle.messageTypeWarning) {
                        iconColor = qgcPal.colorOrange
                    } else if (_activeVehicle.messageTypeError) {
                        iconColor = qgcPal.colorRed
                    }
                }
                return iconColor
            }
        }

        QGCMouseArea {
            anchors.fill:   parent
            onClicked:      dropMainStatusIndicator()
        }
    }

    QGCLabel {
        id:                 vtolModeLabel
        Layout.fillHeight:  true
        verticalAlignment:  Text.AlignVCenter
        text:               _vtolInFWDFlight ? qsTr("FW(vtol)") : qsTr("MR(vtol)")
        color:              qgcPal.text
        font.pointSize:     _vehicleInAir ? ScreenTools.largeFontPointSize : ScreenTools.defaultFontPointSize
        visible:            _activeVehicle && _activeVehicle.vtol

        QGCMouseArea {
            anchors.fill: parent
            onClicked: {
                if (_vehicleInAir) {
                    mainWindow.showIndicatorDrawer(vtolTransitionIndicatorPage)
                }
            }
        }
    }

    // ZGC: P4 内联状态胶囊条扩展——RTK 固定态胶囊（C 轮胶囊结构复用；行内聚合＝状态词＋模式＋RTK＋电池，
    // 飞行模式已由工具栏相邻 FlightModeIndicator 内联展示，不在此重复）— ZFYZ-59
    QGCLabel {
        id:                 rtkCapsuleLabel
        Layout.fillHeight:  true
        verticalAlignment:  Text.AlignVCenter
        text:               qsTr("RTK Fixed")
        color:              qgcPal.text
        font.pointSize:     ScreenTools.defaultFontPointSize
        visible:            _activeVehicle && QGroundControl.gpsRtk.valid.value

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left:           parent.left
            anchors.right:          parent.right
            anchors.leftMargin:     -(ScreenTools.defaultFontPixelWidth / 2)
            anchors.rightMargin:    -(ScreenTools.defaultFontPixelWidth / 2)
            height:                 rtkCapsuleLabel.contentHeight + (ScreenTools.defaultFontPixelHeight / 2)
            z:                      -1
            radius:                 height / 2
            color:                  Qt.rgba(qgcPal.colorGreen.r, qgcPal.colorGreen.g, qgcPal.colorGreen.b, 0.2)
            border.color:           Qt.rgba(qgcPal.colorGreen.r, qgcPal.colorGreen.g, qgcPal.colorGreen.b, 0.55)
            border.width:           1
        }
    }

    // ZGC: P4 电池胶囊——取电量最低一节电池，配色映射同上游 BatteryIndicator 百分比分档
    // （threshold1/threshold2 用户设置），百分比不可得时整枚隐藏 — ZFYZ-59
    QGCLabel {
        id:                 batteryCapsuleLabel
        Layout.fillHeight:  true
        verticalAlignment:  Text.AlignVCenter
        text:               _batteryText()
        color:              qgcPal.text
        font.pointSize:     ScreenTools.defaultFontPointSize
        visible:            _activeVehicle && _batteryText() !== ""

        function _lowestBattery() {
            var lowest = null
            for (var i = 0; i < _activeVehicle.batteries.count; i++) {
                var battery = _activeVehicle.batteries.get(i)
                if (!lowest) {
                    lowest = battery
                    continue
                }
                var lowestPercent  = lowest.percentRemaining.rawValue
                var batteryPercent = battery.percentRemaining.rawValue
                if (!isNaN(batteryPercent) && (isNaN(lowestPercent) || batteryPercent < lowestPercent)) {
                    lowest = battery
                }
            }
            return lowest
        }

        function _batteryText() {
            var battery = _lowestBattery()
            if (!battery || isNaN(battery.percentRemaining.rawValue)) {
                return ""
            }
            return battery.percentRemaining.valueString + battery.percentRemaining.units
        }

        function _batteryColor() {
            var battery = _lowestBattery()
            if (!battery || isNaN(battery.percentRemaining.rawValue)) {
                return qgcPal.text
            }
            var threshold1 = QGroundControl.settingsManager.batteryIndicatorSettings.threshold1.rawValue
            var threshold2 = QGroundControl.settingsManager.batteryIndicatorSettings.threshold2.rawValue
            if (battery.percentRemaining.rawValue > threshold1) {
                return qgcPal.colorGreen
            } else if (battery.percentRemaining.rawValue > threshold2) {
                return qgcPal.colorYellowGreen
            } else {
                return qgcPal.colorYellow
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left:           parent.left
            anchors.right:          parent.right
            anchors.leftMargin:     -(ScreenTools.defaultFontPixelWidth / 2)
            anchors.rightMargin:    -(ScreenTools.defaultFontPixelWidth / 2)
            height:                 batteryCapsuleLabel.contentHeight + (ScreenTools.defaultFontPixelHeight / 2)
            z:                      -1
            radius:                 height / 2

            property color _semanticColor: batteryCapsuleLabel._batteryColor()

            color:        Qt.rgba(_semanticColor.r, _semanticColor.g, _semanticColor.b, 0.2)
            border.color: Qt.rgba(_semanticColor.r, _semanticColor.g, _semanticColor.b, 0.55)
            border.width: 1
        }
    }

    Component {
        id: overallStatusOfflineIndicatorPage

        MainStatusIndicatorOfflinePage {
            Component.onCompleted:   mainWindow.suppressCriticalVehicleMessages = true
            Component.onDestruction: mainWindow.suppressCriticalVehicleMessages = false
        }
    }

    Component {
        id: overallStatusIndicatorPage

        ToolIndicatorPage {
            showExpand:                         true
            waitForParameters:                  false
            expandedComponentWaitForParameters: true
            contentComponent:                   mainStatusContentComponent
            expandedComponent:                  mainStatusExpandedComponent

            Component.onCompleted:   mainWindow.suppressCriticalVehicleMessages = true
            Component.onDestruction: mainWindow.suppressCriticalVehicleMessages = false
        }
    }

    Component {
        id: mainStatusContentComponent

        ColumnLayout {
            id:         mainLayout
            spacing:    _spacing

            property bool parametersReady: QGroundControl.multiVehicleManager.parameterReadyVehicleAvailable

            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth
                visible: parametersReady

                QGCDelayButton {
                    enabled:    _armed || !_healthAndArmingChecksSupported || _activeVehicle.healthAndArmingCheckReport.canArm
                    text:       _armed ? qsTr("Disarm") : (control._allowForceArm ? qsTr("Force Arm") : qsTr("Arm"))

                    onActivated: {
                        if (_armed) {
                            _activeVehicle.armed = false
                        } else {
                            if (_allowForceArm) {
                                _allowForceArm = false
                                _activeVehicle.forceArm()
                            } else {
                                _activeVehicle.armed = true
                            }
                        }
                        mainWindow.closeIndicatorDrawer()
                    }
                }

                LabelledComboBox {
                    id:                 primaryLinkCombo
                    Layout.alignment:   Qt.AlignTop
                    label:              qsTr("Primary Link")
                    alternateText:      _primaryLinkName
                    visible:            _activeVehicle && _activeVehicle.vehicleLinkManager.linkNames.length > 1

                    property var    _rgLinkNames:       _activeVehicle ? _activeVehicle.vehicleLinkManager.linkNames : [ ]
                    property var    _rgLinkStatus:      _activeVehicle ? _activeVehicle.vehicleLinkManager.linkStatuses : [ ]
                    property string _primaryLinkName:   _activeVehicle ? _activeVehicle.vehicleLinkManager.primaryLinkName : ""

                    function updateComboModel() {
                        let linkModel = []
                        for (let i = 0; i < _rgLinkNames.length; i++) {
                            let linkStatus = _rgLinkStatus[i]
                            linkModel.push(_rgLinkNames[i] + (linkStatus === "" ? "" : " " + _rgLinkStatus[i]))
                        }
                        primaryLinkCombo.model = linkModel
                        primaryLinkCombo.currentIndex = -1
                    }

                    Component.onCompleted:  updateComboModel()
                    on_RgLinkNamesChanged:  updateComboModel()
                    on_RgLinkStatusChanged: updateComboModel()

                    onActivated:    (index) => {
                        _activeVehicle.vehicleLinkManager.primaryLinkName = _rgLinkNames[index]; currentIndex = -1
                        mainWindow.closeIndicatorDrawer()
                    }
                }
            }

            SettingsGroupLayout {
                //Layout.fillWidth:   true
                heading:            qsTr("Vehicle Messages")

                VehicleMessageList {
                    id: vehicleMessageList
                    visible: !noMessages
                }

                QGCLabel {
                    text: qsTr("No new vehicle messages")
                    visible: vehicleMessageList.noMessages
                }
            }

            SettingsGroupLayout {
                //Layout.fillWidth:   true
                heading:            qsTr("Sensor Status")
                visible:            parametersReady && !_healthAndArmingChecksSupported

                GridLayout {
                    rowSpacing:     _spacing
                    columnSpacing:  _spacing
                    rows:           _activeVehicle.sysStatusSensorInfo.sensorNames.length
                    flow:           GridLayout.TopToBottom

                    Repeater {
                        model: _activeVehicle.sysStatusSensorInfo.sensorNames
                        QGCLabel { text: modelData }
                    }

                    Repeater {
                        model: _activeVehicle.sysStatusSensorInfo.sensorStatus
                        QGCLabel { text: modelData }
                    }
                }
            }

            SettingsGroupLayout {
                //Layout.fillWidth:   true
                heading:            qsTr("Overall Status")
                visible:            parametersReady && _healthAndArmingChecksSupported && _activeVehicle.healthAndArmingCheckReport.problemsForCurrentMode.count > 0

                // List health and arming checks
                Repeater {
                    model:      _activeVehicle ? _activeVehicle.healthAndArmingCheckReport.problemsForCurrentMode : null
                    delegate:   listdelegate
                }
            }

            Component {
                id: listdelegate

                Column {
                    Row {
                        spacing: ScreenTools.defaultFontPixelHeight

                        QGCLabel {
                            id:           message
                            text:         object.message
                            textFormat:   TextEdit.RichText
                            color:        object.severity == 'error' ? qgcPal.colorRed : object.severity == 'warning' ? qgcPal.colorOrange : qgcPal.text
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (object.description != "")
                                        object.expanded = !object.expanded
                                }
                            }
                        }

                        QGCColoredImage {
                            id:                     arrowDownIndicator
                            anchors.verticalCenter: parent.verticalCenter
                            height:                 1.5 * ScreenTools.defaultFontPixelWidth
                            width:                  height
                            source:                 "/qmlimages/arrow-down.png"
                            color:                  qgcPal.text
                            visible:                object.description != ""
                            MouseArea {
                                anchors.fill:       parent
                                onClicked:          object.expanded = !object.expanded
                            }
                        }
                    }

                    QGCLabel {
                        id:                 description
                        text:               object.description
                        textFormat:         TextEdit.RichText
                        clip:               true
                        visible:            object.expanded

                        property var fact:  null

                        onLinkActivated: (link) => {
                            if (link.startsWith('param://')) {
                                var paramName = link.substr(8);
                                fact = controller.getParameterFact(-1, paramName, true)
                                if (fact != null) {
                                    paramEditorDialogFactory.open()
                                }
                            } else {
                                Qt.openUrlExternally(link);
                            }
                        }

                        FactPanelController {
                            id: controller
                        }

                        QGCPopupDialogFactory {
                            id: paramEditorDialogFactory

                            dialogComponent: paramEditorDialogComponent
                        }

                        Component {
                            id: paramEditorDialogComponent

                            ParameterEditorDialog {
                                title:          qsTr("Edit Parameter")
                                fact:           description.fact
                                destroyOnClose: true
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: mainStatusExpandedComponent

        ColumnLayout {
            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 60
            spacing:                margins / 2

            property real margins: ScreenTools.defaultFontPixelHeight

            Loader {
                Layout.fillWidth:   true
                source:             _activeVehicle.expandedToolbarIndicatorSource("MainStatus")
            }

            SettingsGroupLayout {
                Layout.fillWidth:   true
                heading:            qsTr("Force Arm")
                headingDescription: qsTr("Force arming bypasses pre-arm checks. Use with caution.")
                visible:            _activeVehicle && !_armed

                QGCCheckBoxSlider {
                    Layout.fillWidth:   true
                    text:               qsTr("Allow Force Arm")
                    checked:            false
                    onClicked:          _allowForceArm = true
                }
            }

            SettingsGroupLayout {
                Layout.fillWidth:   true
                visible:            QGroundControl.corePlugin.showAdvancedUI

                GridLayout {
                    columns:            2
                    rowSpacing:         ScreenTools.defaultFontPixelHeight / 2
                    columnSpacing:      ScreenTools.defaultFontPixelWidth *2
                    Layout.fillWidth:   true

                    QGCLabel { Layout.fillWidth: true; text: qsTr("Vehicle Parameters") }
                    QGCButton {
                        text: qsTr("Configure")
                        onClicked: {
                            mainWindow.showVehicleConfigParametersPage()
                            mainWindow.closeIndicatorDrawer()
                        }
                    }

                    QGCLabel { Layout.fillWidth: true; text: qsTr("Vehicle Configuration") }
                    QGCButton {
                        text: qsTr("Configure")
                        onClicked: {
                            mainWindow.showVehicleConfig()
                            mainWindow.closeIndicatorDrawer()
                        }
                    }
                }
            }
        }
    }
}
