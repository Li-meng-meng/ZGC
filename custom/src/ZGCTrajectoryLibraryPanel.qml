/****************************************************************************
 * ZGC 新增：Plan View 轨迹库面板（非覆盖件，普通 qrc 资源）
 * 资源路径 qrc:/Custom/qml/ZGCTrajectoryLibraryPanel.qml（注册见 custom/CMakeLists.txt
 * custom_qml_panels）；由 PlanViewToolBar 覆盖件挂载为工具栏下方 Popup（parent =
 * Overlay.overlay 置顶，工具栏子项会被后绘的地图区盖住）。任务：ZFYZ-轨迹复飞-批2。
 *
 * 职责：
 *   - ListView 绑 zgcTrajectory.library：条目展示 name/created/pointCount/distance/
 *     durationS/maxRelAlt ＋ degraded/corrupted 徽标；空库与错误态；删除带确认。
 *   - 复飞链路（安全默认）：simplifyTrajectory 抽稀 → 预检确认对话框（批3 信息完备化：
 *     轨迹名/录制时间/航点数/总距离/最大相对高度/起飞点漂移；>50 点拒绝；degraded 与
 *     超阈值漂移为显著警示条，漂移只警示不阻断）→ 确认后 removeAll + setHomePosition
 *     (轨迹 home) + insertTakeoffItem + insertSimpleMissionItem×N（Relative 帧逐点相对
 *     高度）+ insertLandItem → sendToVehiclePreCheck → sendToVehicle 自动上传，并在
 *     发起上传时刻置位 zgcTrajectorySafety 复飞任务执行窗口（Fly 常驻急停可见性来源）。
 *     不自动起飞、不自动解锁——成功提示切 Fly 视图按原生流程起飞。
 *   - 覆盖件不享模块隐式导入，全部 import 显式声明。
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtPositioning

import QGroundControl
import QGroundControl.Controls

Popup {
    id: root

    width:  ScreenTools.defaultFontPixelWidth * 44
    height: ScreenTools.defaultFontPixelHeight * 28
    modal: false
    closePolicy: Popup.CloseOnEscape
    padding: ScreenTools.defaultFontPixelWidth

    /// 由 PlanViewToolBar 覆盖件注入（上游 PlanView.qml 实例化 PlanViewToolBar 时已传入，
    /// 经属性链取得，零上游修改）
    property var planMasterController

    readonly property var _mc:            planMasterController ? planMasterController.missionController : null
    readonly property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    readonly property int _maxReflyPoints: 50  ///< 与 ZGCTrajectory::kMaxSimplifiedPoints（抽稀输出上限）一致的双保险
    // ZGC: 起飞点漂移警示阈值（米，水平大圆距离）——消费电子 GNSS 同址观测噪声量级为
    // 开阔地 1.5~3 m、遮挡环境至多 ~10 m，30 m ≈ 最坏同址噪声的 3 倍（纯 GPS 抖动不误报），
    // 而真实换位起飞（场地内挪位）通常数十米起（必报）；只警示不阻断，最终确认仍由
    // 飞手在原生流程把握。— ZFYZ-轨迹复飞-批3
    readonly property real _homeDriftWarnMeters: 30

    property bool   _uploadPending: false
    property string _lastError: ""
    // ZGC: 预检确认弹窗与任务构建间的待执行数据（确认后消费，弹窗拒绝即悬空可覆盖）— ZFYZ-轨迹复飞-批3
    property var    _pendingPoints: null
    property var    _pendingHome: null

    QGCPalette { id: qgcPal }

    background: Rectangle {
        color: qgcPal.window
        border.color: qgcPal.groupBorder
        border.width: 1
        radius: ScreenTools.defaultBorderRadius
    }

    onOpened: root._lastError = ""

    //---- 格式化辅助 ----//

    function _formatDistance(meters) {
        if (meters >= 1000) {
            return (meters / 1000).toFixed(2) + qsTr(" km")
        }
        return meters.toFixed(0) + qsTr(" m")
    }

    function _formatDuration(seconds) {
        var total = Math.round(seconds)
        var h = Math.floor(total / 3600)
        var m = Math.floor((total % 3600) / 60)
        var s = total % 60
        function _pad(n) { return (n < 10 ? "0" : "") + n }
        if (h > 0) {
            return h + ":" + _pad(m) + ":" + _pad(s)
        }
        return m + ":" + _pad(s)
    }

    //---- 删除（带确认）----//

    function _confirmDelete(fileName, name) {
        QGroundControl.showMessageDialog(
                    root,
                    qsTr("删除轨迹"),
                    qsTr("确定删除轨迹「%1」？该操作不可恢复。").arg(name),
                    Dialog.Ok | Dialog.Cancel,
                    function() {
                        if (!zgcTrajectory.library.deleteTrajectory(fileName)) {
                            root._lastError = qsTr("删除失败：文件可能已被移除或被占用")
                        }
                    })
    }

    //---- 复飞：预检确认 → 构建 → 上传 ----//

    // ZGC: 当前起飞点取值——载具在连用载具 home（AMSL），否则回退地面站应用 home/
    // 最后已知位置；两者皆不可得返回 null（预检弹窗如实标注"跳过漂移比对"）。— ZFYZ-轨迹复飞-批3
    function _currentHomeInfo() {
        if (_activeVehicle && _activeVehicle.homePosition && _activeVehicle.homePosition.isValid) {
            return { coord: _activeVehicle.homePosition, source: qsTr("载具 home") }
        }
        var gcsHome = QGroundControl.qgcPositionManger.gcsPosition
        if (gcsHome && gcsHome.isValid) {
            return { coord: gcsHome, source: qsTr("地面站定位") }
        }
        return null
    }

    function _refly(fileName) {
        var trajectory = zgcTrajectory.library.loadTrajectory(fileName)
        if (!trajectory || trajectory.corrupted === true) {
            root._lastError = qsTr("加载轨迹失败：%1").arg(trajectory && trajectory.error ? trajectory.error : "")
            return
        }

        var points = zgcTrajectory.library.simplifyTrajectory(fileName)
        if (!points || points.length === 0) {
            // 失败原因经 errorOccurred 显示，此处兜底
            root._lastError = qsTr("抽稀失败：无可用航点")
            return
        }
        if (points.length > root._maxReflyPoints) {
            root._lastError = qsTr("抽稀后航点数 %1 超过上限 %2，拒绝复飞").arg(points.length).arg(root._maxReflyPoints)
            return
        }

        // 预检统计（基于抽稀后航点，QGeoCoordinate.distanceTo 逐段累加）
        var distance = 0
        var maxRelAlt = 0
        for (var i = 0; i < points.length; i++) {
            if (i > 0) {
                distance += QtPositioning.coordinate(points[i - 1].lat, points[i - 1].lon)
                                    .distanceTo(QtPositioning.coordinate(points[i].lat, points[i].lon))
            }
            maxRelAlt = Math.max(maxRelAlt, points[i].relAlt)
        }

        // ZGC: 起飞点漂移预检（只警示不阻断，最终确认仍在原生流程）——当前起飞点
        // （载具 home 优先，回退地面站定位）与轨迹记录时绑定的 home 水平距离比对。— ZFYZ-轨迹复飞-批3
        var currentHomeInfo = root._currentHomeInfo()
        var driftMeters = -1
        var driftExceeded = false
        if (currentHomeInfo) {
            driftMeters = currentHomeInfo.coord.distanceTo(
                        QtPositioning.coordinate(trajectory.home.lat, trajectory.home.lon))
            driftExceeded = driftMeters > root._homeDriftWarnMeters
        }

        root._pendingPoints = points
        root._pendingHome = trajectory.home
        var dialog = reflyConfirmDialogComponent.createObject(mainWindow.contentItem, {
            trajName:      trajectory.name || fileName,
            trajCreated:   trajectory.created ? Qt.formatDateTime(trajectory.created, "yyyy-MM-dd hh:mm:ss") : "",
            waypointCount: points.length,
            totalDistance: root._formatDistance(distance),
            maxRelAltitude: maxRelAlt.toFixed(1),
            driftSummary:  currentHomeInfo
                ? root._formatDistance(driftMeters) + qsTr("（当前起飞点＝") + currentHomeInfo.source + qsTr("）")
                : "",
            driftExceeded: driftExceeded,
            driftUnavailable: !currentHomeInfo,
            degraded:      trajectory.stats && trajectory.stats.degraded === true
        })
        if (!dialog) {
            root._lastError = qsTr("预检确认弹窗创建失败")
            return
        }
        dialog.open()
    }

    function _buildAndUpload(points, homeMap) {
        if (!root.planMasterController || !root._mc) {
            root._lastError = qsTr("任务控制器不可用")
            return
        }
        if (!QGroundControl.multiVehicleManager.activeVehicle) {
            root._lastError = qsTr("无活动载具，无法上传")
            return
        }

        var missionController = root._mc
        var homeCoordinate = QtPositioning.coordinate(homeMap.lat, homeMap.lon)

        //---- 任务构建：settings(0) + takeoff(1) + 航点(2..N+1) + 降落(N+2) ----//

        root.planMasterController.removeAll()
        // insertTakeoffItem 忽略坐标入参（起飞点取 plannedHomePosition），先固定 home
        missionController.setHomePosition(homeCoordinate)
        missionController.insertTakeoffItem(homeCoordinate, 1, false)
        for (var i = 0; i < points.length; i++) {
            var item = missionController.insertSimpleMissionItem(
                        QtPositioning.coordinate(points[i].lat, points[i].lon), i + 2, false)
            if (!item) {
                root._lastError = qsTr("航点插入失败（第 %1 点）").arg(i + 1)
                return
            }
            // 逐点锁定相对高度帧（轨迹 relAlt 为相对 home 的米数）
            item.altitudeFrame = QGroundControl.AltitudeFrameRelative
            item.altitude.rawValue = points[i].relAlt
        }
        var last = points[points.length - 1]
        missionController.insertLandItem(QtPositioning.coordinate(last.lat, last.lon), points.length + 2, false)

        //---- 上传（与上游 PlanView upload() 同路径）----//

        if (root.planMasterController.readyForSaveState() === VisualMissionItem.NotReadyForSaveData) {
            root._lastError = qsTr("任务数据不完整，无法上传")
            return
        }
        switch (missionController.sendToVehiclePreCheck()) {
        case MissionController.SendToVehiclePreCheckStateOk:
            root._uploadPending = true
            // ZGC: 发起上传即打开复飞任务执行窗口（Fly 视图常驻急停可见性来源）；
            // 此后链路任何环节失败窗口不回退，仅由载具上锁解除/活动载具消失关闭。— ZFYZ-轨迹复飞-批3
            zgcTrajectorySafety.beginReflyMissionWindow()
            root.planMasterController.sendToVehicle()
            break
        case MissionController.SendToVehiclePreCheckStateActiveMission:
            root._lastError = qsTr("载具正在执行任务，须先暂停才能上传")
            break
        case MissionController.SendToVehiclePreCheckStateFirwmareVehicleMismatch:
            QGroundControl.showMessageDialog(
                        root,
                        qsTr("固件/机型不匹配"),
                        qsTr("复飞任务与当前载具固件/机型不匹配，继续上传可能导致飞行异常。仍要上传吗？"),
                        Dialog.Ok | Dialog.Cancel,
                        function() {
                            root._uploadPending = true
                            zgcTrajectorySafety.beginReflyMissionWindow()  // ZGC: 同上，二次确认路径同刻置位 — ZFYZ-轨迹复飞-批3
                            root.planMasterController.sendToVehicle()
                        })
            break
        default:
            root._lastError = qsTr("无活动载具，无法上传")
            break
        }
    }

    //---- 上传结果反馈（sync 收尾 + dirtyForUpload 归零＝成功；仍脏＝失败）----//

    function _checkUploadFinished() {
        if (!root._uploadPending || !root.planMasterController || root.planMasterController.syncInProgress) {
            return
        }
        root._uploadPending = false
        if (!root.planMasterController.dirtyForUpload) {
            root._lastError = ""
            QGroundControl.showMessageDialog(
                        root,
                        qsTr("复飞任务已上传"),
                        qsTr("请切换到 Fly 视图，按原生流程起飞（本功能不自动起飞、不自动解锁）。"))
        } else {
            root._lastError = qsTr("任务上传失败，请检查链路后重试")
        }
    }

    Connections {
        target: root.planMasterController

        function onSyncInProgressChanged() {
            // Qt.callLater：等控制器收尾的 dirty 状态更新落地后再判定成败
            if (root.planMasterController && !root.planMasterController.syncInProgress && root._uploadPending) {
                Qt.callLater(root._checkUploadFinished)
            }
        }
    }

    // ZGC: 复飞预检确认弹窗（QGCPopupDialog 动态创建，先例 FlyViewAdditionalCustomActionsList
    // recordDialogComponent）——信息完备化：轨迹名/录制时间/航点数/总距离/最大相对高度/
    // 起飞点漂移， degraded 与超阈值漂移以显著警示条呈现（色值经 QGCPalette 色板名，
    // 零硬编码）。接受后消费 root._pendingPoints/_pendingHome 进入构建上传。— ZFYZ-轨迹复飞-批3
    Component {
        id: reflyConfirmDialogComponent

        QGCPopupDialog {
            property string trajName: ""
            property string trajCreated: ""
            property int    waypointCount: 0
            property string totalDistance: ""
            property string maxRelAltitude: ""
            property string driftSummary: ""
            property bool   driftExceeded: false
            property bool   driftUnavailable: false
            property bool   degraded: false

            title:   qsTr("复飞预检确认")
            buttons: Dialog.Ok | Dialog.Cancel

            onAccepted: root._buildAndUpload(root._pendingPoints, root._pendingHome)

            ColumnLayout {
                width: ScreenTools.defaultFontPixelWidth * 56
                spacing: ScreenTools.defaultFontPixelHeight * 0.4

                QGCLabel {
                    font.bold: true
                    font.pointSize: ScreenTools.mediumFontPointSize
                    text: trajName
                }

                QGCLabel {
                    visible: trajCreated !== ""
                    text: qsTr("录制时间：%1").arg(trajCreated)
                    color: qgcPal.colorGrey
                }

                QGCLabel { text: qsTr("航点数：%1").arg(waypointCount) }

                QGCLabel { text: qsTr("总距离：%1").arg(totalDistance) }

                QGCLabel { text: qsTr("最大相对高度：%1 m").arg(maxRelAltitude) }

                QGCLabel {
                    // ZGC: 未超阈值才显示"阈值内"行；超阈值由下方红色警示条承载，避免同屏矛盾 — ZFYZ-轨迹复飞-批3
                    visible: !driftUnavailable && !driftExceeded
                    wrapMode: QGCLabel.WordWrap
                    text: qsTr("起飞点漂移：%1，在阈值 %2 内")
                              .arg(driftSummary).arg(root._formatDistance(root._homeDriftWarnMeters))
                }

                QGCLabel {
                    visible: driftUnavailable
                    wrapMode: QGCLabel.WordWrap
                    color: qgcPal.warningText
                    text: qsTr("无法取得当前起飞点（无载具 home 且地面站无定位），本次已跳过漂移比对。")
                }

                // 起飞点漂移超阈值——显著警示条（红底，只警示不阻断）
                Rectangle {
                    Layout.fillWidth: true
                    visible: driftExceeded
                    radius: ScreenTools.defaultBorderRadius
                    color: qgcPal.colorRed
                    height: visible ? driftLabel.implicitHeight + ScreenTools.defaultFontPixelWidth * 2 : 0

                    QGCLabel {
                        id: driftLabel

                        anchors.margins: ScreenTools.defaultFontPixelWidth
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        wrapMode: QGCLabel.WordWrap
                        color: qgcPal.buttonHighlightText
                        font.bold: true
                        text: qsTr("起飞点漂移警告：当前起飞点距原轨迹起飞点 %1，超过阈值 %2。起飞爬升段将偏离原航迹，请核实起飞点是否安全，必要时重新录制轨迹。")
                                  .arg(driftSummary).arg(root._formatDistance(root._homeDriftWarnMeters))
                    }
                }

                // 采样间隙降级——显著警示条（黄底）
                Rectangle {
                    Layout.fillWidth: true
                    visible: degraded
                    radius: ScreenTools.defaultBorderRadius
                    color: qgcPal.colorYellow
                    height: visible ? degradedBarLabel.implicitHeight + ScreenTools.defaultFontPixelWidth * 2 : 0

                    QGCLabel {
                        id: degradedBarLabel

                        anchors.margins: ScreenTools.defaultFontPixelWidth
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        wrapMode: QGCLabel.WordWrap
                        color: qgcPal.alertText
                        font.bold: true
                        text: qsTr("警告：该轨迹存在采样间隙（降级），间隙段为未观测数据，复飞航迹可能与原航线不一致。")
                    }
                }

                QGCLabel {
                    Layout.fillWidth: true
                    wrapMode: QGCLabel.WordWrap
                    color: qgcPal.colorGrey
                    text: qsTr("起飞点取轨迹 home 位置，结束自动添加降落/RTL 项；确认后将覆盖 Plan 视图当前任务并自动上传。")
                }
            }
        }
    }

    //---- 内容 ----//

    contentItem: ColumnLayout {
        spacing: ScreenTools.defaultFontPixelHeight * 0.5

        RowLayout {
            Layout.fillWidth: true

            QGCLabel {
                Layout.fillWidth: true
                font.bold: true
                font.pointSize: ScreenTools.mediumFontPointSize  // ZGC: F 轮字阶 medium 级（1.15）——面板标题 — ZFYZ-轨迹复飞-批3
                text: qsTr("轨迹库")
            }

            QGCButton {
                text: qsTr("刷新")
                onClicked: zgcTrajectory.library.refresh()
            }

            QGCColoredImage {
                width: ScreenTools.defaultFontPixelHeight * 0.6
                height: width
                source: "/res/XDelete.svg"
                fillMode: Image.PreserveAspectFit
                color: qgcPal.text

                QGCMouseArea {
                    fillItem: parent
                    onClicked: root.close()
                }
            }
        }

        QGCListView {
            id: trajectoryList

            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: ScreenTools.defaultFontPixelHeight * 0.25
            model: zgcTrajectory.library

            delegate: Rectangle {
                width: trajectoryList.width
                height: delegateColumn.height + 2 * ScreenTools.defaultFontPixelHeight * 0.5
                color: qgcPal.windowShade
                radius: ScreenTools.defaultBorderRadius

                ColumnLayout {
                    id: delegateColumn

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.5
                    spacing: ScreenTools.defaultFontPixelHeight * 0.25

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth * 0.5

                        QGCLabel {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.bold: true
                            text: name
                        }

                        Rectangle {
                            visible: degraded
                            radius: ScreenTools.defaultBorderRadius
                            color: qgcPal.colorYellow
                            width: degradedLabel.width + ScreenTools.defaultFontPixelWidth
                            height: degradedLabel.height + ScreenTools.defaultFontPixelHeight * 0.4

                            QGCLabel {
                                id: degradedLabel
                                anchors.centerIn: parent
                                font.pointSize: ScreenTools.smallFontPointSize
                                text: qsTr("降级")
                            }
                        }

                        Rectangle {
                            visible: corrupted
                            radius: ScreenTools.defaultBorderRadius
                            color: qgcPal.colorRed
                            width: corruptedLabel.width + ScreenTools.defaultFontPixelWidth
                            height: corruptedLabel.height + ScreenTools.defaultFontPixelHeight * 0.4

                            QGCLabel {
                                id: corruptedLabel
                                anchors.centerIn: parent
                                font.pointSize: ScreenTools.smallFontPointSize
                                color: qgcPal.buttonHighlightText
                                text: qsTr("损坏")
                            }
                        }
                    }

                    QGCLabel {
                        text: created ? Qt.formatDateTime(created, "yyyy-MM-dd hh:mm:ss") : ""
                        color: qgcPal.colorGrey
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        wrapMode: QGCLabel.WordWrap
                        text: corrupted ? qsTr("文件损坏或版本不识别，仅供查看，不可复飞。")
                                        : qsTr("%1 点 · %2 · 时长 %3 · 最大相对高度 %4 m")
                                              .arg(pointCount)
                                              .arg(root._formatDistance(distance))
                                              .arg(root._formatDuration(durationS))
                                              .arg(maxRelAlt.toFixed(1))
                    }

                    RowLayout {
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCButton {
                            text: qsTr("复飞")
                            enabled: !corrupted && root._activeVehicle && !!root.planMasterController
                                     && !root.planMasterController.syncInProgress && !root._uploadPending
                            onClicked: root._refly(fileName)
                        }

                        QGCButton {
                            text: qsTr("删除")
                            onClicked: root._confirmDelete(fileName, name)
                        }
                    }
                }
            }
        }

        QGCLabel {
            Layout.fillWidth: true
            visible: zgcTrajectory.library.count === 0
            wrapMode: QGCLabel.WordWrap
            text: qsTr("轨迹库为空。到 Fly 视图 Actions → 轨迹录制 面板手动录制（或解锁自动录制）一段飞行轨迹，保存后即可在此复飞。")
        }

        QGCLabel {
            Layout.fillWidth: true
            visible: root._lastError !== ""
            wrapMode: QGCLabel.WordWrap
            color: qgcPal.warningText
            text: root._lastError
        }
    }

    // 轨迹库（保存/删除/加载/抽稀）失败原因 → 面板错误行
    Connections {
        target: zgcTrajectory.library

        function onErrorOccurred(message) {
            root._lastError = message
        }
    }
}
