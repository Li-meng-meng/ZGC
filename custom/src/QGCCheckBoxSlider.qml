/****************************************************************************
 * ZGC 覆盖层：开关滑钮选中态反白
 * 同路径覆盖上游 qml/QGroundControl/Controls/QGCCheckBoxSlider.qml
 * （经 CustomOverrideInterceptor 改写加载，注册见 custom/CMakeLists.txt custom_qml_overrides）。
 * 任务：ZFYZ-69 修复轮（红上红缺陷链 · P2 #7）。胶囊指示器选中态为 buttonHighlight
 * （志翔红），上游滑钮圆片恒着 buttonText（深色）——选中时深钮落红底对比不足（调研报告
 * §4.2 #7）。仅一处改状态驱动前景：选中圆片 → buttonHighlightText（白），未选中保持
 * buttonText（浅底深钮语义不变）。其余（hover 高亮/边框/标签）与上游逐行一致。
 * 上游原文位置：src/QmlControls/QGCCheckBoxSlider.qml
 * 消费点：Force Arm 开关、飞行模式编辑复选滑钮等
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

AbstractButton   {
    id:         control
    checkable:  true
    padding:    0

    property bool _showBorder:      qgcPal.globalTheme === QGCPalette.Light
    property int  _sliderInset:     2
    property bool _showHighlight:   enabled && (pressed || checked)

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    contentItem: Item {
        implicitWidth:  (label.visible ? label.contentWidth + ScreenTools.defaultFontPixelWidth : 0) + indicator.width
        implicitHeight: label.contentHeight

        QGCLabel {
            id:             label
            anchors.left:   parent.left
            text:           visible ? control.text : "X"
            visible:        control.text !== ""
        }

        Rectangle {
            id:                     indicator
            anchors.right:          parent.right
            anchors.verticalCenter: parent.verticalCenter
            height:                 ScreenTools.defaultFontPixelHeight
            width:                  height * 2
            radius:                 height / 2
            color:                  checked ? qgcPal.buttonHighlight : qgcPal.button
            border.width:           _showBorder ? 1 : 0
            border.color:           qgcPal.buttonBorder

            Rectangle {
                anchors.fill:   parent
                color:          qgcPal.buttonHighlight
                opacity:        _showHighlight ? 1 : control.enabled && control.hovered ? .2 : 0
                radius:         parent.radius
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x:                      checked ? indicator.width - width - _sliderInset : _sliderInset
                height:                 parent.height - (_sliderInset * 2)
                width:                  height
                radius:                 height / 2
                color:                  checked ? qgcPal.buttonHighlightText : qgcPal.buttonText // ZGC: 选中圆片落 buttonHighlight 红胶囊上，状态驱动反白（原恒 buttonText 深色）— ZFYZ-69
            }
        }
    }
}
