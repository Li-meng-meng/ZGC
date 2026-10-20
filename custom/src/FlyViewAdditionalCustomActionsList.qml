/****************************************************************************
 * ZGC 覆盖层：Fly View「轨迹录制」入口 + 录制面板
 * 同路径覆盖上游空壳 qml/QGroundControl/FlyView/FlyViewAdditionalCustomActionsList.qml
 * （上游注释明示供 custom build 覆盖以追加自定义动作；经 CustomOverrideInterceptor 改写
 * 加载，注册见 custom/CMakeLists.txt custom_qml_overrides）。任务：ZFYZ-轨迹复飞-批2。
 *
 * 机制（零上游修改）：
 *   - 维持空壳契约（guidedController / anyActionAvailable / model），提供一个「轨迹录制」
 *     动作项（actionCode 10000，≥ GuidedActionsController.customActionStart）。Actions
 *     汉堡面板（FlyViewAdditionalActionsPanel）把 model 渲染为按钮，点击固定路由
 *     guidedController.confirmAction(actionCode)。
 *   - confirmAction 对未知 code 落 default → CustomGuidedActionsController 覆盖件钩子
 *     （原生确认条）→ 确认后 executeAction → customExecuteAction → 打开本文件面板。
 *   - 面板（QGCPopupDialog）：状态行（录制中/有未保存/空闲）＋手动开始/停止＋保存
 *     （名称默认 轨迹-YYYYMMDD-HHMMSS）/丢弃（带确认）＋ errorOccurred 错误行＋
 *     armed 自动录制被跳过的弹窗提示（批 1 遗留项#1 的 UI 侧）。
 *   - 本件实例创建于 ToolStripAction（C++ QObject）的 property var 之下，无可视父级，
 *     面板以 mainWindow.contentItem 为创建父级打开（QGCPopupDialog 自挂 Overlay.overlay，
 *     destroyOnClose 关闭即销毁）。
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    visible: false

    property var guidedController   ///< 上游注入：globals.guidedControllerFlyView

    property bool anyActionAvailable: {
        for (var i = 0; i < model.length; i++) {
            if (model[i].visible)
                return true
        }

        return false
    }

    // ZGC 动作码：GuidedActionsController.customActionStart（10000）起为 custom build 保留段；
    // 消费方为 CustomGuidedActionsController 覆盖件（两处需同步）— ZFYZ-轨迹复飞-批2
    readonly property int recordActionCode: 10000

    /// 录制状态行（录制中 / 有未保存 / 空闲），同时供确认条与面板复用
    readonly property string statusSummary: {
        if (zgcTrajectory.recording) {
            return qsTr("录制中：已记录 %1 个采样点").arg(zgcTrajectory.rawPointCount)
        }
        if (zgcTrajectory.hasUnsavedTrajectory) {
            return qsTr("已停止：有未保存轨迹（%1 点），请先保存或丢弃").arg(zgcTrajectory.rawPointCount)
        }
        return qsTr("空闲")
    }

    property string _lastMessage: ""
    property bool   _lastMessageIsError: false

    property var model: [
        {
            title:  qsTr("轨迹录制"),
            visible: true,
            action: recordActionCode
        }
    ]

    QGCPalette { id: qgcPal }

    //---- 面板打开入口（CustomGuidedActionsController 覆盖件经 zgcEntryPanel 调用）----//

    function openPanel() {
        _lastMessage = ""
        _lastMessageIsError = false
        // ZGC: 本件无可视父级（宿主为 ToolStripAction 的 property var），须以窗口内 Item
        // 为创建父级，QGCPopupDialog 才能解析 Overlay.overlay 并自挂窗口叠加层；
        // destroyOnClose 默认 true，关闭即销毁（等价 QGCPopupDialogFactory 路径）— ZFYZ-轨迹复飞-批2
        var dialog = recordDialogComponent.createObject(mainWindow.contentItem)
        if (!dialog) {
            console.warn("ZGC: failed to create recording panel dialog") // 日志非用户可见，不进翻译
            return
        }
        dialog.open()
    }

    //---- 内部逻辑 ----//

    function _showMessage(message, isError) {
        _lastMessage = message
        _lastMessageIsError = isError
    }

    function _defaultTrajectoryName() {
        var d = new Date()
        function _pad(n) { return (n < 10 ? "0" : "") + n }
        return qsTr("轨迹-") + d.getFullYear() + _pad(d.getMonth() + 1) + _pad(d.getDate())
                + "-" + _pad(d.getHours()) + _pad(d.getMinutes()) + _pad(d.getSeconds())
    }

    function _startRecording() {
        if (!QGroundControl.multiVehicleManager.activeVehicle) {
            _showMessage(qsTr("无活动载具，无法开始录制"), true)
            return
        }
        zgcTrajectory.startRecording()
        _showMessage(qsTr("录制已开始"), false)
    }

    function _saveUnsaved(name) {
        var trajectory = zgcTrajectory.unsavedTrajectory()
        var fileName = zgcTrajectory.library.saveTrajectory(name, trajectory)
        if (fileName === "") {
            // 具体原因经 errorOccurred 显示，此处兜底
            _showMessage(qsTr("保存失败"), true)
            return
        }
        // 已完整落盘，释放内存缓冲（数据无损），状态回到空闲
        zgcTrajectory.discardUnsavedTrajectory()
        _showMessage(qsTr("已保存：") + fileName, false)
    }

    function _discardUnsaved() {
        QGroundControl.showMessageDialog(
                    root,
                    qsTr("丢弃未保存轨迹"),
                    qsTr("确定丢弃内存中未保存的 %1 个采样点？该操作不可恢复。").arg(zgcTrajectory.rawPointCount),
                    Dialog.Ok | Dialog.Cancel,
                    function() {
                        zgcTrajectory.discardUnsavedTrajectory()
                        _showMessage(qsTr("未保存轨迹已丢弃"), false)
                    })
    }

    Component {
        id: recordDialogComponent

        QGCPopupDialog {
            title: qsTr("轨迹录制")
            buttons: Dialog.NoButton

            ColumnLayout {
                width: ScreenTools.defaultFontPixelWidth * 60
                spacing: ScreenTools.defaultFontPixelHeight * 0.5

                // 录制状态行（录制中 / 有未保存 / 空闲）
                QGCLabel {
                    Layout.fillWidth: true
                    font.bold: true
                    text: root.statusSummary
                }

                QGCLabel {
                    Layout.fillWidth: true
                    wrapMode: QGCLabel.WordWrap
                    text: qsTr("载具解锁后自动开始录制，上锁后自动停止；停止后数据保留在内存中，请及时保存或丢弃。")
                }

                QGCLabel {
                    Layout.fillWidth: true
                    visible: root._lastMessage !== ""
                    wrapMode: QGCLabel.WordWrap
                    text: root._lastMessage
                    color: root._lastMessageIsError ? qgcPal.warningText : qgcPal.colorGreen
                }

                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCButton {
                        text: qsTr("开始录制")
                        enabled: !zgcTrajectory.recording && !!QGroundControl.multiVehicleManager.activeVehicle
                        onClicked: root._startRecording()
                    }

                    QGCButton {
                        text: qsTr("停止录制")
                        enabled: zgcTrajectory.recording
                        onClicked: zgcTrajectory.stopRecording()
                    }
                }

                // 保存/丢弃区（仅有未保存数据时出现）
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: zgcTrajectory.hasUnsavedTrajectory
                    spacing: ScreenTools.defaultFontPixelHeight * 0.5

                    QGCLabel {
                        font.bold: true
                        text: qsTr("保存名称")
                    }

                    QGCTextField {
                        id: nameField

                        Layout.fillWidth: true
                        text: root._defaultTrajectoryName()
                    }

                    RowLayout {
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCButton {
                            text: qsTr("保存")
                            enabled: zgcTrajectory.hasUnsavedTrajectory && nameField.text.trim() !== ""
                            onClicked: root._saveUnsaved(nameField.text.trim())
                        }

                        QGCButton {
                            text: qsTr("丢弃")
                            enabled: zgcTrajectory.hasUnsavedTrajectory
                            onClicked: root._discardUnsaved()
                        }
                    }
                }
            }

            // 有未保存数据再次解锁时，armed 自动开始被跳过（录制器批 2 保守默认），弹窗引导
            Connections {
                target: zgcTrajectory

                function onAutoRecordStartSkipped() {
                    QGroundControl.showMessageDialog(
                                root,
                                qsTr("轨迹录制"),
                                qsTr("内存中存在未保存的轨迹，本次解锁自动录制已跳过。请通过 Actions → 轨迹录制 打开面板，先保存或丢弃该轨迹。"))
                }

                // 出现未保存数据时刷新默认保存名（按停止时刻生成）
                function onHasUnsavedTrajectoryChanged() {
                    if (zgcTrajectory.hasUnsavedTrajectory) {
                        nameField.text = root._defaultTrajectoryName()
                    }
                }
            }
        }
    }

    // 轨迹库保存/删除失败原因（zgcTrajectory.library.errorOccurred）→ 面板错误行
    Connections {
        target: zgcTrajectory.library

        function onErrorOccurred(message) {
            root._showMessage(message, true)
        }
    }
}
