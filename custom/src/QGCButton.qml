/****************************************************************************
 * ZGC 覆盖层：QGCButton 密度收紧（竖向 padding 字高 50% → 30%，全 UI 按钮生效）
 * 同路径覆盖上游 qml/QGroundControl/Controls/QGCButton.qml
 * （经 CustomOverrideInterceptor 改写加载，注册见 custom/CMakeLists.txt custom_qml_overrides）。
 * 任务：A3-20260909-roundF-typescale（ZFYZ-42）。仅密度层变更：
 *   - heightFactor 默认值 0.5 → 0.3：竖向 padding 由字高 50% 收至 30%（上游偏肥），
 *     收紧后按钮自然高度 ≈ implicitButtonHeight（1.6×字高，ScreenTools.qml:106），去虚胖
 *   - 显式覆盖 heightFactor 的调用点不受影响（属性契约不变）；图标按钮补偿式同上游
 *   - 其余（primary/highlight/border/图标布局/RowLayout 内容项）与上游逐行一致
 * 上游原文位置：src/QmlControls/QGCButton.qml
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Standard push button control:
///     If there is both an icon and text the icon will be to the left of the text
///     If icon only, icon will be centered
Button {
    property bool primary: false
    property bool showBorder: qgcPal.globalTheme === QGCPalette.Light
    property real backRadius: ScreenTools.defaultBorderRadius
    property real heightFactor: 0.3 // ZGC: 竖向 padding 密度收紧 字高 50% → 30%（上游偏肥）— ZFYZ-42
    property string iconSource: ""
    property real fontWeight: Font.Normal // default for qml Text
    property real pointSize: ScreenTools.defaultFontPointSize

    property alias wrapMode: text.wrapMode
    property alias horizontalAlignment: text.horizontalAlignment
    property alias backgroundColor: backRect.color
    property alias textColor: text.color

    id: control
    hoverEnabled: !ScreenTools.isMobile
    topPadding: _verticalPadding
    bottomPadding: _verticalPadding
    leftPadding: _horizontalPadding
    rightPadding: _horizontalPadding
    focusPolicy: Qt.ClickFocus
    font.family: ScreenTools.normalFontFamily
    text: ""

    property bool _showHighlight: enabled && (pressed | checked)
    property int _horizontalPadding: ScreenTools.defaultFontPixelWidth * 2
    property int _verticalPadding: Math.round(ScreenTools.defaultFontPixelHeight * heightFactor) - (iconSource === "" ? 0 : (_iconHeight - ScreenTools.defaultFontPixelHeight)  / 2)
    property real _iconHeight: text.height * 1.5

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    background: Rectangle {
        id: backRect
        radius: backRadius
        implicitWidth: ScreenTools.implicitButtonWidth
        implicitHeight: ScreenTools.implicitButtonHeight
        border.width: showBorder ? 1 : 0
        border.color: qgcPal.buttonBorder
        color: primary ? qgcPal.primaryButton : qgcPal.button

        Rectangle {
            anchors.fill: parent
            color: qgcPal.buttonHighlight
            opacity: _showHighlight ? 1 : control.enabled && control.hovered ? .2 : 0
            radius: parent.radius
        }
    }

    contentItem: RowLayout {
        spacing: ScreenTools.defaultFontPixelWidth

        QGCColoredImage {
            id: icon
            Layout.alignment: Qt.AlignHCenter
            source: control.iconSource
            height: _iconHeight
            width: height
            color: text.color
            fillMode: Image.PreserveAspectFit
            sourceSize.height: height
            visible: control.iconSource !== ""
        }

        QGCLabel {
            id: text
            Layout.alignment: Qt.AlignHCenter
            text: control.text
            font.pointSize: control.pointSize
            font.family: control.font.family
            font.weight: fontWeight
            color: _showHighlight ? qgcPal.buttonHighlightText : (primary ? qgcPal.primaryButtonText : qgcPal.buttonText)
            visible: control.text !== ""
        }
    }
}
