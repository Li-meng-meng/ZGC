/****************************************************************************
 * ZGC 覆盖层：Fly View 自定义引导动作钩子
 * 同路径覆盖上游空壳 qml/QGroundControl/FlyView/CustomGuidedActionsController.qml
 * （上游注释明示供 custom build 覆盖以添加自定义 guided 动作；经 CustomOverrideInterceptor
 * 改写加载，注册见 custom/CMakeLists.txt custom_qml_overrides）。任务：ZFYZ-轨迹复飞-批2。
 *
 * 与 FlyViewAdditionalCustomActionsList 覆盖件（录制入口动作项）配对使用：
 *   - Actions 汉堡面板把动作项点击固定路由到 guidedController.confirmAction(actionCode)；
 *   - GuidedActionsController.confirmAction 对 customActionStart(10000) 起的未知 code 落入
 *     default → 本件 customConfirmAction（配置原生确认条标题/文案并返回 true）；
 *   - 用户在确认条按下确认 → executeAction → default → 本件 customExecuteAction →
 *     打开录制入口覆盖件注入的面板。
 * zgcEntryPanel 由 FlyViewAdditionalCustomActionsList 覆盖件在 onCompleted 时反向注入
 * （其自身创建于 ToolStripAction 的 property var 之下，两侧无静态引用可达）。
 ****************************************************************************/

import QtQml

QtObject {
    /// 录制入口覆盖件（FlyViewAdditionalCustomActionsList 覆盖）反向注入的面板宿主
    property var zgcEntryPanel: null

    // ZGC 动作码：与 FlyViewAdditionalCustomActionsList.recordActionCode 一致，
    // 取 GuidedActionsController.customActionStart（10000）起的 custom build 保留段
    readonly property int _zgcActionRecordPanel: 10000

    function customConfirmAction(actionCode, actionData, mapIndicator, confirmDialog) {
        if (actionCode !== _zgcActionRecordPanel) {
            return false // false = action not handled here
        }
        // ZGC: 复用原生引导确认条（与全部 guided 动作同一交互/安全语义）；显式清掉
        // 上一次动作遗留的 hideTrigger 绑定，防确认条被陈旧条件自动隐藏 — ZFYZ-轨迹复飞-批2
        confirmDialog.title = qsTr("轨迹录制")
        confirmDialog.message = zgcEntryPanel ? zgcEntryPanel.statusSummary : qsTr("打开轨迹录制面板")
        confirmDialog.hideTrigger = false
        return true
    }

    function customExecuteAction(actionCode, actionData, sliderOutputValue, optionChecked) {
        if (actionCode !== _zgcActionRecordPanel) {
            return false // false = action not handled here
        }
        if (!zgcEntryPanel) {
            console.warn("ZGC: recording entry panel not wired, ignored action") // 日志非用户可见，不进翻译
            return false
        }
        zgcEntryPanel.openPanel()
        return true
    }
}
