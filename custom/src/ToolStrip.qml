/****************************************************************************
 * ZGC 覆盖层：ToolStrip 按钮组胶囊化（Fly/Plan 左条共用本件）
 * 同路径覆盖上游 qml/QGroundControl/Controls/ToolStrip.qml
 * （经 CustomOverrideInterceptor 改写加载，注册见 custom/CMakeLists.txt custom_qml_overrides；
 * 配套覆盖 ToolStripHoverButton.qml —— 按钮胶囊形态由两件共同生效，缺一会形态不一致）。
 * 任务：A3-20260909-roundD-toolstrip（ZFYZ-39）。仅视觉/样式层变更：
 *   - 容器：半透明底（windowTransparent）与上游一致，圆角加大（defaultFontPixelWidth*1.5）
 *     并加 1px buttonBorder 发丝描边；宽度由固定 7*defaultFontPixelWidth 改为按按钮
 *     内容自然宽度自适应（_buttonsNaturalWidth），腾出横排「图标+标签」空间
 *   - 按钮间距 defaultFontPixelWidth*0.25 → *0.75（组线悬挂空隙＋胶囊呼吸感）；
 *     flickable 边距 *0.4 → *0.75（胶囊内边距）
 *   - 分组分隔线：_groupStartIcons 表按动作 iconSource 识别组首按钮，1px windowShadeLight
 *     发丝线悬挂于按钮上方空隙（居中），未列入表的动作不分组（安全退化）；
 *     上方无可见按钮时分隔线自动隐藏（首个可见按钮前不出线）
 *   - 默认字号 smallFontPointSize → defaultFontPointSize（小字号密度问题的可读性修正，
 *     fontSize 属性仍可外部覆盖）
 *   - simulateClick(buttonIndex) 契约不变（点击第 buttonIndex 个按钮），经 repeater.itemAt 取按钮
 *   - model/maxHeight 别名、dropped 信号、互斥选中逻辑、ToolStripDropPanel 挂接、
 *     死区鼠标（DeadMouseArea）与上游一致，逻辑未动
 * 上游原文位置：src/QmlControls/ToolStrip.qml
 *
 * 运行时缺陷修复记录（ZFYZ-43 门禁退回，门禁 1/3 轮）：
 *   首版委托为包裹 Column（分隔线+按钮，声明 required modelData/index、根依赖位置器
 *   隐式高度、visible: button.visible 链、量宽对 wrap.visible 过滤）。Fly 页（model 为
 *   JS 数组字面量）正常，Plan 页（model 为 C++ QQmlListProperty<QObject>，走 ObjectData
 *   适配器路径）整条塌缩为约 16px 圆点、按钮全部不可见（基线同 commit 对照 5 按钮正常，
 *   stderr 无告警）。修复：委托结构回正上游形态——委托根即按钮本体（显式 height，
 *   不依赖位置器隐式高度）、不声明 required 属性（沿用上游上下文 modelData/index）、
 *   不引入包裹层 visible 链；分隔线改为按钮内部子件（负 y 悬挂按钮上方空隙，
 *   不占布局高度，组线可见性改查同列按钮 visible，避免对 ListProperty 的 JS 下标索引）；
 *   条宽量取直接取按钮 capsuleNaturalWidth（仍按按钮 visible 剔除隐藏动作）。
 *   经 shadow-module 纯 QML 复现环境（qml.exe + 桩类型）验证数组/单对象/ObjectData
 *   三种模型路径下新结构均正常成列。
 ****************************************************************************/

import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id:         _root
    color:      qgcPal.windowTransparent
    width:      _buttonsNaturalWidth + (flickable.anchors.margins * 2) + (ScreenTools.defaultFontPixelWidth * 0.5)
    height:     Math.min(maxHeight, toolStripColumn.height + (flickable.anchors.margins * 2))
    radius:     ScreenTools.defaultFontPixelWidth * 1.5
    border.color:   qgcPal.buttonBorder
    border.width:   1

    property alias  model:              repeater.model
    property real   maxHeight           ///< Maximum height for control, determines whether text is hidden to make control shorter
    property var    fontSize:           ScreenTools.defaultFontPointSize

    property var _dropPanel: dropPanel

    // ZGC: 组首按钮识别表——iconSource 为上游稳定的资源路径常量（不随语言/索引变化）。
    // /res/takeoff.svg             Fly 引导动作组首（Takeoff）；Plan 插入工具组首（Takeoff）
    // qrc:/qmlimages/HamburgerThin.svg  Fly 附加动作组首（Actions）
    // /res/chevron-double-right.svg     Plan 信息组首（Stats）
    readonly property var _groupStartIcons: [
        "/res/takeoff.svg",
        "qrc:/qmlimages/HamburgerThin.svg",
        "/res/chevron-double-right.svg"
    ]

    // ZGC: 显式调色板实例——覆盖件自 :/Custom/qml/ 散文件加载，不依赖上游动态 id 解析 — ZFYZ-39
    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    // ZGC: 可见按钮的最大自然宽度（含隐藏动作剔除），驱动条宽自适应 — ZFYZ-39
    readonly property real _buttonsNaturalWidth: {
        var w = 0
        for (var i = 0; i < repeater.count; i++) {
            var button = repeater.itemAt(i)
            if (button && button.visible) {
                w = Math.max(w, button.capsuleNaturalWidth)
            }
        }
        return w
    }

    // ZGC: 组首按钮上方是否存在可见按钮（决定分隔线是否显示），随动作 visible 变化自动刷新 — ZFYZ-39
    function _hasVisibleButtonAbove(index) {
        for (var i = 0; i < index; i++) {
            var button = repeater.itemAt(i)
            if (button && button.visible) {
                return true
            }
        }
        return false
    }

    function _isGroupStart(iconSource) {
        return _groupStartIcons.indexOf(iconSource ? iconSource.toString() : "") >= 0
    }

    function simulateClick(buttonIndex) {
        var button = repeater.itemAt(buttonIndex)
        if (!button) {
            return
        }
        if (button.checkable) {
            button.checked = !button.checked
        }
        button.clicked()
    }

    signal dropped(int index)

    DeadMouseArea {
        anchors.fill: parent
    }

    QGCFlickable {
        id:                 flickable
        anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.75
        anchors.fill:       parent
        contentHeight:      toolStripColumn.height
        flickableDirection: Flickable.VerticalFlick
        clip:               true

        Column {
            id:             toolStripColumn
            anchors.left:   parent.left
            anchors.right:  parent.right
            spacing:        ScreenTools.defaultFontPixelWidth * 0.75

            Repeater {
                id: repeater

                // ZGC: 委托根保持上游形态（按钮本体，显式 height）——首版包裹 Column 结构在
                // Plan 页 ObjectData 适配器路径下塌缩，见文件头修复记录 — ZFYZ-43
                ToolStripHoverButton {
                    id:                 button
                    anchors.left:       toolStripColumn.left
                    anchors.right:      toolStripColumn.right
                    height:             ScreenTools.defaultFontPixelHeight * 2.75
                    radius:             height / 2
                    fontPointSize:      _root.fontSize
                    toolStripAction:    modelData
                    dropPanel:          _dropPanel
                    onDropped: (index) => _root.dropped(index)

                    onCheckedChanged: {
                        // We deal with exclusive check state manually since usinug autoExclusive caused all sorts of crazt problems
                        if (checked) {
                            for (var i=0; i<repeater.count; i++) {
                                if (i != index) {
                                    var button = repeater.itemAt(i)
                                    if (button && button.checked) {
                                        button.checked = false
                                    }
                                }
                            }
                        }
                    }

                    // ZGC: 组分隔线——按钮内部子件，负 y 悬挂于上方按钮间空隙中心；
                    // 不占布局高度、不影响按钮内容布局；仅组首按钮且上方有可见按钮时显示 — ZFYZ-39
                    Rectangle {
                        anchors.horizontalCenter:   parent.horizontalCenter
                        y:                          -(toolStripColumn.spacing + height) / 2
                        width:                      parent.width * 0.6
                        height:                     1
                        color:                      qgcPal.windowShadeLight
                        visible:                    _root._isGroupStart(modelData ? modelData.iconSource : "") &&
                                                        _root._hasVisibleButtonAbove(index)
                    }
                }
            }
        }
    }

    ToolStripDropPanel {
        id:         dropPanel
        toolStrip:  _root
    }
}
