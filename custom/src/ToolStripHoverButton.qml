/****************************************************************************
 * ZGC 覆盖层：ToolStrip 按钮胶囊化
 * 同路径覆盖上游 qml/QGroundControl/Controls/ToolStripHoverButton.qml
 * （经 CustomOverrideInterceptor 改写加载，注册见 custom/CMakeLists.txt custom_qml_overrides）。
 * 任务：A3-20260909-roundD-toolstrip（ZFYZ-39）。仅视觉/样式层变更：
 *   - 按钮由「图标上/文字下」竖排方块（height=width）改为「图标左/文字右」横排胶囊：
 *     默认高度 defaultFontPixelHeight * 2.75（上游默认 height=width 方块），圆角取 height/2
 *   - 内容 Item 由 Column 改 Row，图标区收敛为正方形槽位；innerImage /
 *     innerImageColorful / innerImageSecondColor 三图标与全部着色逻辑原样保留
 *   - 选中/按下态走 qgcPal.buttonHighlight（A 轮色板已映射志翔红 #D94232），
 *     悬停态 qgcPal.toolStripHoverColor，着色规则逐行同上游
 *   - 新增只读属性 capsuleNaturalWidth（横排内容自然宽度），供覆盖层 ToolStrip 量宽；
 *     默认 width 绑定由上游 :10（contentLayoutItem.contentWidth，Item 无此属性、
 *     实际被 anchors/外部赋值永久覆盖的死绑定）改为 capsuleNaturalWidth，意图一致
 *   - contentMargins 默认值 innerText.height*0.1 → defaultFontPixelWidth*0.75（胶囊内边距）
 *   - imageScale 默认值 0.6/0.8 → 0.85/0.9（横排槽位下图标视觉尺寸与上游方块对齐）
 *   - 全部 id / 别名（radius/fontPointSize/imageSource/contentWidth）/ 属性 / 信号 /
 *     onClicked 拖放面板逻辑与上游一致，逻辑未动
 * 上游原文位置：src/QmlControls/ToolStripHoverButton.qml
 ****************************************************************************/

import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Button {
    id:             control
    objectName:     toolStripAction ? toolStripAction.objectName : ""
    width:          capsuleNaturalWidth
    height:         ScreenTools.defaultFontPixelHeight * 2.75
    hoverEnabled:   !ScreenTools.isMobile
    enabled:        toolStripAction ? toolStripAction.enabled : true
    visible:        toolStripAction ? toolStripAction.visible : true
    imageSource:    (toolStripAction && modelData) ? (toolStripAction.showAlternateIcon ? modelData.alternateIconSource : modelData.iconSource) : ""
    text:           toolStripAction ? toolStripAction.text : ""
    checked:        toolStripAction ? toolStripAction.checked : false
    checkable:      toolStripAction ? (toolStripAction.dropPanelComponent || (modelData && modelData.checkable)) : false

    property var    toolStripAction:    undefined
    property var    dropPanel:          undefined
    property alias  radius:             buttonBkRect.radius
    property alias  fontPointSize:      innerText.font.pointSize
    property alias  imageSource:        innerImage.source
    property alias  contentWidth:       innerText.contentWidth

    property bool forceImageScale11: false
    property real imageScale:        forceImageScale11 && (text == "") ? 0.9 : 0.85
    property real contentMargins:    ScreenTools.defaultFontPixelWidth * 0.75
    property real iconTextSpacing:   ScreenTools.defaultFontPixelWidth * 0.5

    // ZGC: 横排胶囊内容自然宽度（供 ToolStrip 覆盖层量取最宽按钮定条宽），不依赖最终 width — ZFYZ-39
    readonly property real capsuleNaturalWidth: (contentMargins * 2) + _iconSide + iconTextSpacing +
                                                innerText.contentWidth
    readonly property real _iconSide:           contentLayoutItem.height * imageScale

    property color _currentContentColor:  (checked || pressed) ? qgcPal.buttonHighlightText : qgcPal.text
    property color _currentContentColorSecondary:  (checked || pressed) ? qgcPal.text : qgcPal.buttonHighlight

    signal dropped(int index)

    onCheckedChanged: { if (toolStripAction) toolStripAction.checked = checked }

    onClicked: {
        if (mainWindow.allowViewSwitch()) {
            dropPanel.hide()
            if (!toolStripAction.dropPanelComponent) {
                toolStripAction.triggered(this)
            } else if (checked) {
                var panelEdgeTopPoint = mapToItem(_root, width, 0)
                dropPanel.show(panelEdgeTopPoint, toolStripAction.dropPanelComponent, this)
                checked = true
                control.dropped(index)
            }
        } else if (checkable) {
            checked = !checked
        }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    contentItem: Item {
        id:                 contentLayoutItem
        anchors.fill:       parent
        anchors.margins:    contentMargins

        Row {
            anchors.centerIn:   parent
            spacing:            control.iconTextSpacing

            Item {
                id:                         iconSlot
                width:                      control._iconSide
                height:                     control._iconSide
                anchors.verticalCenter:     parent.verticalCenter

                Image {
                    id:                         innerImageColorful
                    anchors.fill:               parent
                    smooth:                     true
                    mipmap:                     true
                    fillMode:                   Image.PreserveAspectFit
                    antialiasing:               true
                    sourceSize.height:          height
                    sourceSize.width:           width
                    source:                     control.imageSource
                    visible:                    source != "" && !!modelData && modelData.fullColorIcon
                }

                QGCColoredImage {
                    id:                         innerImage
                    anchors.fill:               parent
                    smooth:                     true
                    mipmap:                     true
                    color:                      _currentContentColor
                    fillMode:                   Image.PreserveAspectFit
                    antialiasing:               true
                    sourceSize.height:          height
                    sourceSize.width:           width
                    visible:                    source != "" && !(modelData && modelData.fullColorIcon)

                    QGCColoredImage {
                        id:                         innerImageSecondColor
                        source:                     modelData ? modelData.alternateIconSource : ""
                        anchors.fill:               parent
                        smooth:                     true
                        mipmap:                     true
                        color:                      _currentContentColorSecondary
                        fillMode:                   Image.PreserveAspectFit
                        antialiasing:               true
                        sourceSize.height:          height
                        sourceSize.width:           width
                        visible:                    source != "" && !!modelData && modelData.biColorIcon
                    }
                }
            }

            QGCLabel {
                id:                         innerText
                text:                       control.text
                color:                      _currentContentColor
                anchors.verticalCenter:     parent.verticalCenter
                font.bold:                  !innerImage.visible && !innerImageColorful.visible
                opacity:                    !innerImage.visible ? 0.8 : 1.0
            }
        }
    }

    background: Rectangle {
        id:     buttonBkRect
        radius: height / 2
        color:  (control.checked || control.pressed) ?
                    qgcPal.buttonHighlight :
                    ((control.enabled && control.hovered) ? qgcPal.toolStripHoverColor : "transparent")
    }
}
