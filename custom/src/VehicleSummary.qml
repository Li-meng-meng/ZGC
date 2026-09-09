/****************************************************************************
 * ZGC 覆盖层：Setup 页 Vehicle Summary 卡片升级（统一圆角＋hover 抬升＋状态徽章化）
 * 同路径覆盖上游 qml/QGroundControl/VehicleSetup/VehicleSummary.qml
 * （经 CustomOverrideInterceptor 改写加载，注册见 custom/CMakeLists.txt custom_qml_overrides）。
 * 任务：A3-20260909-roundE-vehsum（ZFYZ-40）。仅视觉/样式层变更，信息结构与交互契约不变：
 *   - 统一圆角：卡片 radius defaultFontPixelHeight/4 → ScreenTools.defaultBorderRadius
 *     （全 UI 按钮/面板统一圆角值）
 *   - hover 抬升：HoverHandler 悬停时底色 windowShade→toolStripHoverColor（A 轮色板 hover
 *     语义，同 D 轮 ToolStrip 悬停态）、描边淡入志翔红（buttonHighlight 45% alpha）、
 *     整卡沿 transform Translate 上浮（不参与布局）；ColorAnimation/NumberAnimation 过渡
 *   - 状态徽章化：红绿圆点外包语义色胶囊（C 轮 MainStatusIndicator 徽章同构：20% 填充＋
 *     55% 描边）；点色（colorGreen/colorRed）与可见条件逐值同上游
 *   - 标题去按钮伪装：QGCButton 透明底＋无边框＋Font.Bold（点击区域与 onClicked 行为不变）
 *   - 布局结构、全部 id/属性、capitalizeWords、showVehicleComponentPanel 跳转、
 *     Loader（summaryQmlSource/vehicleComponent）契约与上游一致
 * 上游原文位置：src/Vehicle/VehicleSetup/VehicleSummary.qml
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id:             _summaryRoot
    anchors.fill:   parent
    anchors.rightMargin: ScreenTools.defaultFontPixelWidth
    anchors.leftMargin:  ScreenTools.defaultFontPixelWidth
    color:          qgcPal.window

    property real _minSummaryW:     ScreenTools.isTinyScreen ? ScreenTools.defaultFontPixelWidth * 28 : ScreenTools.defaultFontPixelWidth * 36
    property real _summaryBoxSpace: ScreenTools.defaultFontPixelWidth * 2
    property real _margins:        ScreenTools.defaultFontPixelHeight / 2

    // ZGC: 卡片 hover 抬升幅度（约 2px，随字号缩放） — ZFYZ-40
    readonly property real _hoverLift: ScreenTools.defaultFontPixelHeight / 5

    function capitalizeWords(sentence) {
        return sentence.replace(/(?:^|\s)\S/g, function(a) { return a.toUpperCase(); });
    }

    QGCPalette {
        id:                 qgcPal
        colorGroupEnabled:  enabled
    }

    QGCFlickable {
        clip:               true
        anchors.fill:       parent
        contentHeight:      summaryColumn.height
        contentWidth:       _summaryRoot.width
        flickableDirection: Flickable.VerticalFlick

        Column {
            id:             summaryColumn
            width:          _summaryRoot.width
            spacing:        ScreenTools.defaultFontPixelHeight

            QGCLabel {
                width:			parent.width
                wrapMode:		Text.WordWrap
                color:			setupComplete ? qgcPal.text : qgcPal.warningText
                font.bold:      true
                horizontalAlignment: Text.AlignHCenter
                text:           setupComplete ?
                    qsTr("Your vehicle configuration summary appears below. Select components on the left to review or fine-tune settings.") :
                    qsTr("WARNING: Configuration tasks remain before this vehicle is ready to fly. Open the red-marked components on the left to finish setup.")

                property bool setupComplete: QGroundControl.multiVehicleManager.activeVehicle ? QGroundControl.multiVehicleManager.activeVehicle.autopilotPlugin.setupComplete : false
            }

            GridLayout {
                id:             _gridCtl
                width:          _summaryRoot.width
                columns:        Math.max(1, Math.floor((_summaryRoot.width + _summaryBoxSpace) / (_minSummaryW + _summaryBoxSpace)))
                columnSpacing:  _summaryBoxSpace
                rowSpacing:     ScreenTools.defaultFontPixelHeight

                Repeater {
                    model: QGroundControl.multiVehicleManager.activeVehicle ? QGroundControl.multiVehicleManager.activeVehicle.autopilotPlugin.vehicleComponents : undefined

                    // Outer summary item rectangle
                    // ZGC: 卡片升级——统一圆角＋hover 抬升（底色/描边/上浮），加载与点击行为不变 — ZFYZ-40
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        implicitWidth: _minSummaryW
                        implicitHeight: mainLayout.implicitHeight + (_margins * 2)
                        // ZGC: 统一圆角（全 UI 统一值，ScreenTools.qml:115） — ZFYZ-40
                        radius: ScreenTools.defaultBorderRadius
                        // ZGC: hover 底色走 A 轮色板 hover 语义（同 D 轮 ToolStrip 悬停态） — ZFYZ-40
                        color: cardHover.hovered ? qgcPal.toolStripHoverColor : qgcPal.windowShade
                        visible: modelData.summaryQmlSource.toString() !== ""
                        border.width: 1
                        // ZGC: hover 描边淡入志翔红（buttonHighlight 45% alpha），常态同上游 — ZFYZ-40
                        border.color: cardHover.hovered ?
                            Qt.rgba(qgcPal.buttonHighlight.r, qgcPal.buttonHighlight.g,
                                    qgcPal.buttonHighlight.b, 0.45) :
                            Qt.rgba(qgcPal.text.r, qgcPal.text.g, qgcPal.text.b, 0.1)

                        // ZGC: hover 抬升＋过渡（transform 不参与布局，悬停态整卡上浮） — ZFYZ-40
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        transform: Translate {
                            y: cardHover.hovered ? -_summaryRoot._hoverLift : 0
                            Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                        }
                        HoverHandler { id: cardHover }

                        readonly property real titleHeight: ScreenTools.defaultFontPixelHeight * 2

                        ColumnLayout {
                            id: mainLayout
                            anchors.margins: _margins
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: ScreenTools.defaultFontPixelHeight / 2

                            // Title bar
                            QGCButton {
                                Layout.fillWidth: true
                                Layout.preferredHeight: titleHeight
                                text: capitalizeWords(modelData.name)
                                rightPadding: setupIndicator.visible ? setupIndicator.width + ScreenTools.defaultFontPixelWidth * 2 : leftPadding
                                // ZGC: 标题去按钮伪装（点击区域与 onClicked 行为不变） — ZFYZ-40
                                backgroundColor: "transparent"
                                showBorder: false
                                // ZGC: 标题层级加粗（QGCButton 内容 Label 只绑 fontWeight，control.font.bold 不下传） — ZFYZ-40
                                fontWeight: Font.Bold

                                // Setup indicator
                                // ZGC: 状态徽章化——圆点外包语义色胶囊（填充 20%＋描边 55%，C 轮徽章同构），点与可见条件逐值同上游 — ZFYZ-40
                                Rectangle {
                                    id:                     setupIndicator
                                    anchors.rightMargin:    ScreenTools.defaultFontPixelWidth
                                    anchors.right:          parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    readonly property color statusColor: modelData.setupComplete ?
                                                                            qgcPal.colorGreen : qgcPal.colorRed
                                    width:                  setupDot.width + ScreenTools.defaultFontPixelWidth * 1.25
                                    height:                 setupDot.height + ScreenTools.defaultFontPixelHeight * 0.4
                                    radius:                 height / 2
                                    color:                  Qt.rgba(statusColor.r, statusColor.g, statusColor.b, 0.2)
                                    border.width:           1
                                    border.color:           Qt.rgba(statusColor.r, statusColor.g, statusColor.b, 0.55)
                                    visible:                modelData.requiresSetup && modelData.setupSource !== ""

                                    Rectangle {
                                        id:                     setupDot
                                        anchors.centerIn:       parent
                                        width:                  ScreenTools.defaultFontPixelWidth
                                        height:                 width
                                        radius:                 width / 2
                                        color:                  parent.statusColor
                                    }
                                }

                                onClicked : {
                                    if (modelData.setupSource !== "") {
                                        setupView.showVehicleComponentPanel(modelData)
                                    }
                                }
                            }

                            // Summary Qml
                            Loader {
                                id: summaryLoader
                                Layout.fillWidth: true
                                Layout.preferredWidth: item ? item.implicitWidth : 0
                                Layout.preferredHeight: item ? item.implicitHeight : 0
                                source: modelData.summaryQmlSource

                                property var vehicleComponent: modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
