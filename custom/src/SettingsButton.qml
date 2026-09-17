/****************************************************************************
 * ZGC 覆盖层：侧栏选中态感知增强
 * 同路径覆盖上游 qml/QGroundControl/Controls/SettingsButton.qml
 * （经 CustomOverrideInterceptor 改写加载，注册见 custom/CMakeLists.txt custom_qml_overrides）。
 * 任务：ZFYZ-69 修复轮（红上红缺陷链 · C2）。上游状态-前景机制本已正确
 * （textColor = checked||pressed ? buttonHighlightText : buttonText），但白细线图标与
 * 1px chevron × 志翔红底 #D94232 仅 4.39:1，100% 缩放下感知不可辨（调研报告 §3 像素取证）。
 * 仅感知层增强，选择器/展开接口（expandable/expanded/toggleExpand）与上游一致：
 *   - 图标槽加白色 10% 半透胶囊垫底（仅 checked||pressed 红底态显示，随 textColor 同参），
 *     细线图标获得实体承载（手法同 ToolStripHoverButton 选中胶囊）
 *   - chevron 放大 0.75 → 1.0 字高（SVG 笔画随尺寸等比加粗，1x 下可辨）
 *   - 其余（textColor 联动/背景 opacity/标签）与上游逐行一致
 * 上游原文位置：src/QmlControls/SettingsButton.qml
 * 消费点：AppSettings.qml 设置页侧栏、ConfigButton（VehicleConfigView 侧栏，继承本件）
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Button {
    id:             control
    padding:        ScreenTools.defaultFontPixelWidth * 0.75
    hoverEnabled:   !ScreenTools.isMobile
    autoExclusive:  true
    icon.color:     textColor

    property color textColor: checked || pressed ? qgcPal.buttonHighlightText : qgcPal.buttonText
    property bool expandable: false
    property bool expanded:   false

    signal toggleExpand()

    QGCPalette {
        id:                 qgcPal
        colorGroupEnabled:  control.enabled
    }

    background: Rectangle {
        color:      qgcPal.buttonHighlight
        opacity:    checked || pressed ? 1 : enabled && hovered ? .2 : 0
        radius:     ScreenTools.defaultFontPixelWidth / 2
    }

    contentItem: RowLayout {
        spacing: ScreenTools.defaultFontPixelWidth

        Item {
            id:                     iconCapsule
            // ZGC: 图标槽扩为胶囊容器（图标 1.0 字高居中＋两侧各 0.25 字高垫底）— ZFYZ-69
            implicitWidth:          ScreenTools.defaultFontPixelHeight * 1.5
            implicitHeight:         ScreenTools.defaultFontPixelHeight
            Layout.alignment:       Qt.AlignVCenter

            // ZGC: 白色 10% 半透胶囊垫底——红底态细线图标获得实体承载，随红底态显隐 — ZFYZ-69
            Rectangle {
                anchors.fill:   parent
                radius:         height / 2
                color:          Qt.rgba(1, 1, 1, 0.1)
                visible:        control.checked || control.pressed
            }

            QGCColoredImage {
                anchors.centerIn:   parent
                source:             control.icon.source
                color:              control.icon.color
                width:              ScreenTools.defaultFontPixelHeight
                height:             ScreenTools.defaultFontPixelHeight
            }
        }

        QGCLabel {
            id:                     displayText
            Layout.fillWidth:       true
            text:                   control.text
            color:                  control.textColor
            horizontalAlignment:    QGCLabel.AlignLeft
        }

        QGCColoredImage {
            visible:    control.expandable
            source:     "/InstrumentValueIcons/cheveron-right.svg"
            color:      control.textColor
            // ZGC: chevron 放大 0.75 → 1.0 字高——笔画随尺寸等比加粗，1x 缩放下可辨 — ZFYZ-69
            width:      ScreenTools.defaultFontPixelHeight
            height:     width
            rotation:   control.expanded ? 90 : 0

            MouseArea {
                anchors.fill: parent
                anchors.margins: -ScreenTools.defaultFontPixelWidth
                onClicked: control.toggleExpand()
            }
        }
    }
}
