/****************************************************************************
 * ZGC 覆盖层：滑块确认箭头红底态反白
 * 同路径覆盖上游 qml/QGroundControl/Controls/SliderSwitch.qml
 * （经 CustomOverrideInterceptor 改写加载，注册见 custom/CMakeLists.txt custom_qml_overrides）。
 * 任务：ZFYZ-69 修复轮（红上红缺陷链 · P2 #6）。滑块 knob 恒为 primaryButton（志翔红），
 * 上游 knob 内右滑箭头着 buttonText（深色）落红底，确认动作 affordance 劣化（调研报告
 * §4.2 #6）。仅一处前景 token 变更：箭头 → primaryButtonText（白，与 knob 底色绑定一致）。
 * 提示文字仍为 buttonText（落 windowShade 浅底，语义正确不动）；拖拽/键盘滑动接口不变。
 * 上游原文位置：src/QmlControls/SliderSwitch.qml
 * 消费点：Fly 视角引导动作确认（解锁/降落等 SliderSwitch 弹层）
 ****************************************************************************/

import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

/// The SliderSwitch control implements a sliding switch control similar to the power off
/// control on an iPhone. It supports holding the space bar to slide the switch.
Rectangle {
    id:             _root
    implicitWidth:  label.contentWidth + (_diameter * 2.5) + (_border * 4)
    implicitHeight: label.height * 2.5
    radius:         height /2
    color:          qgcPal.windowShade

    signal accept   ///< Action confirmed

    property string confirmText                         ///< Text for slider
    property alias  fontPointSize: label.font.pointSize ///< Point size for text

    property real _border:                      4
    property real _diameter:                    height - (_border * 2)
    property real _dragStartX:                  _border
    property real _dragStopX:                   _root.width - (_diameter + _border)

    Keys.onSpacePressed: (event) => {
        if (visible && event.modifiers === Qt.NoModifier && !sliderDragArea.drag.active) {
            event.accepted = true
            sliderAnimation.start()
        }
    }

    Keys.onReleased: (event) => {
        if (visible && event.key === Qt.Key_Space && !event.isAutoRepeat) {
            event.accepted = true
            resetSpaceBarSliding()
        }
    }

    function resetSpaceBarSliding() {
        slider.reset()
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    QGCLabel {
        id:                         label
        x:                          _diameter + _border
        width:                      parent.width - x
        anchors.verticalCenter:     parent.verticalCenter
        horizontalAlignment:        Text.AlignHCenter
        text:                       confirmText
        color:                      qgcPal.buttonText
    }

    Rectangle {
        id:         slider
        x:          _border
        y:          _border
        height:     _diameter
        width:      _diameter
        radius:     _diameter / 2
        color:      qgcPal.primaryButton

        QGCColoredImage {
            anchors.centerIn:       parent
            width:                  parent.width  * 0.8
            height:                 parent.height * 0.8
            sourceSize.height:      height
            fillMode:               Image.PreserveAspectFit
            smooth:                 false
            mipmap:                 false
            color:                  qgcPal.primaryButtonText // ZGC: 箭头恒落 primaryButton 红 knob 内，前景反白（原 buttonText 深色落红底）— ZFYZ-69
            cache:                  false
            source:                 "/res/ArrowRight.svg"
        }

        PropertyAnimation on x {
            id:         sliderAnimation
            duration:   1500
            from:       _dragStartX
            to:         _dragStopX
            running:    false

            onFinished: {
                slider.reset()
                _root.accept()
            }
        }

        function reset() {
            slider.x = _border
            sliderAnimation.stop()
        }
    }

    QGCMouseArea {
        id:                 sliderDragArea
        anchors.leftMargin: -ScreenTools.defaultFontPixelWidth * 15
        fillItem:           slider
        drag.target:        slider
        drag.axis:          Drag.XAxis
        drag.minimumX:      _dragStartX
        drag.maximumX:      _dragStopX
        preventStealing:    true

        property bool dragActive: drag.active

        onDragActiveChanged: {
            if (!sliderDragArea.drag.active) {
                if (slider.x > _dragStopX - _border) {
                    _root.accept()
                }
                slider.reset()
            }
        }
    }
}
