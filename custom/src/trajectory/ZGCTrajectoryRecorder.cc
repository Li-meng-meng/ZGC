/****************************************************************************
 * ZGC Trajectory Recorder — 实现
 *
 * 信号连接纪律：
 *   - armedChanged 挂在活动载具上（插件生命周期，活动载具切换时换绑）；
 *   - coordinateChanged 仅在录制期间挂到录制绑定载具，停止即断开；
 *   - 所有 vehicle 连接以 this 为接收上下文，载具销毁由 Qt 自动断连；
 *     另挂 destroyed 兜底：录制中载具析构 → 立即结束录制并保留数据。
 *   - home 海拔在录制开始时刻绑定（任务单锁定决策）；home 无效时在结束录制时
 *     以首采样点海拔兜底并告警，避免相对高度整体失真。
 ****************************************************************************/

#include "ZGCTrajectoryRecorder.h"

#include "MultiVehicleManager.h"
#include "Vehicle.h"
#include "trajectory/ZGCTrajectoryLibrary.h"

void ZGCTrajectoryRecorder::startRecording()
{
    Vehicle *const vehicle = MultiVehicleManager::instance()->activeVehicle();
    if (!vehicle) {
        qCWarning(ZGCTrajectoryLog) << "no active vehicle, ignored";
        return;
    }
    if (_recording) {
        qCWarning(ZGCTrajectoryLog) << "already recording, ignored";
        return;
    }
    _startWithVehicle(vehicle);
}

void ZGCTrajectoryRecorder::stopRecording()
{
    if (!_recording) {
        return;
    }
    _stopRecording();
}

void ZGCTrajectoryRecorder::discardUnsavedTrajectory()
{
    if (!_hasUnsaved) {
        return;
    }
    _points.clear();
    _setHasUnsaved(false);
    emit rawPointCountChanged();
    qCDebug(ZGCTrajectoryLog) << "unsaved trajectory discarded";
}

QVariantMap ZGCTrajectoryRecorder::unsavedTrajectory() const
{
    QVariantMap trajectory;
    trajectory["created"] = _created;
    trajectory["degraded"] = ZGCTrajectorySimplifier::hasDegradedGap(_points);

    QVariantMap home;
    home["lat"] = _homeCoordinate.latitude();
    home["lon"] = _homeCoordinate.longitude();
    home["amslAlt"] = _homeCoordinate.altitude();
    trajectory["home"] = home;

    QVariantMap vehicleInfo;
    vehicleInfo["id"] = _vehicleId;
    vehicleInfo["firmware"] = _vehicleFirmware;
    vehicleInfo["type"] = _vehicleType;
    trajectory["vehicle"] = vehicleInfo;

    QVariantList pointList;
    pointList.reserve(_points.size());
    for (const ZGCTrajectoryPoint &point : _points) {
        QVariantMap pointMap;
        pointMap["lat"] = point.lat;
        pointMap["lon"] = point.lon;
        pointMap["amslAlt"] = point.amslAlt;
        pointMap["tMs"] = point.tMs;
        pointMap["gap"] = point.gap;
        pointList.append(pointMap);
    }
    trajectory["points"] = pointList;

    return trajectory;
}

ZGCTrajectoryRecorder::ZGCTrajectoryRecorder(QObject *parent)
    : QObject(parent)
    , _library(new ZGCTrajectoryLibrary(this))
{
    MultiVehicleManager *const manager = MultiVehicleManager::instance();
    if (manager) {
        (void) connect(manager, &MultiVehicleManager::activeVehicleChanged,
                       this, &ZGCTrajectoryRecorder::_activeVehicleChanged);
        _activeVehicle = manager->activeVehicle();
        _connectVehicleSignals(_activeVehicle.data());
    } else {
        qCCritical(ZGCTrajectoryLog) << "MultiVehicleManager instance not available, auto record disabled";
    }
}

ZGCTrajectoryRecorder::~ZGCTrajectoryRecorder()
{
    _disconnectVehicleSignals(_activeVehicle.data());
    _disconnectVehicleSignals(_recordedVehicle.data());
}

void ZGCTrajectoryRecorder::_activeVehicleChanged(Vehicle *activeVehicle)
{
    Vehicle *const previous = _activeVehicle.data();
    if (previous == activeVehicle) {
        return;
    }

    _disconnectVehicleSignals(previous);
    _activeVehicle = activeVehicle;
    _connectVehicleSignals(activeVehicle);

    // 录制绑定在开始时刻的活动载具上；活动载具切换即结束录制（单轨迹单载具）。
    if (_recording && _recordedVehicle.data() != activeVehicle) {
        qCWarning(ZGCTrajectoryLog) << "active vehicle changed while recording, recording finished";
        _stopRecording();
    }
}

void ZGCTrajectoryRecorder::_connectVehicleSignals(Vehicle *vehicle)
{
    if (!vehicle) {
        return;
    }
    (void) connect(vehicle, &Vehicle::armedChanged,
                   this, &ZGCTrajectoryRecorder::_vehicleArmedChanged, Qt::UniqueConnection);
    (void) connect(vehicle, &QObject::destroyed,
                   this, &ZGCTrajectoryRecorder::_recordedVehicleDestroyed, Qt::UniqueConnection);
}

void ZGCTrajectoryRecorder::_disconnectVehicleSignals(Vehicle *vehicle)
{
    if (!vehicle) {
        return;
    }
    (void) disconnect(vehicle, &Vehicle::armedChanged, this, &ZGCTrajectoryRecorder::_vehicleArmedChanged);
    (void) disconnect(vehicle, &QObject::destroyed, this, &ZGCTrajectoryRecorder::_recordedVehicleDestroyed);
}

void ZGCTrajectoryRecorder::_vehicleArmedChanged(bool armed)
{
    auto *const vehicle = qobject_cast<Vehicle *>(sender());
    if (!vehicle) {
        return;
    }

    if (armed && !_recording) {
        // ZGC: 批 2 保守默认——存在未保存轨迹时跳过自动开始并通知 UI（原行为为覆盖留痕，
        // 有丢数据风险）；用户从 UI 手动 startRecording 不受影响。— ZFYZ-轨迹复飞-批2
        if (_hasUnsaved) {
            qCWarning(ZGCTrajectoryLog) << "auto record start skipped, unsaved trajectory pending"
                                        << "pointCount:" << _points.size();
            emit autoRecordStartSkipped();
        } else {
            _startWithVehicle(vehicle);
        }
    } else if (!armed && _recording && vehicle == _recordedVehicle.data()) {
        // disarm 自动停止；停止 ≠ 保存，数据留内存待用户决定。
        qCDebug(ZGCTrajectoryLog) << "vehicle disarmed, recording finished"
                                  << "pointCount:" << _points.size();
        _stopRecording();
    }
}

void ZGCTrajectoryRecorder::_recordedVehicleDestroyed()
{
    // destroyed 发射期间不可再解引用载具；录制立即收尾，纯内存操作。
    if (_recording) {
        qCWarning(ZGCTrajectoryLog) << "recorded vehicle destroyed, recording finished";
        _stopRecording();
    }
}

void ZGCTrajectoryRecorder::_startWithVehicle(Vehicle *vehicle)
{
    if (!vehicle) {
        return;
    }

    _points.clear();
    _recording = true;
    _setHasUnsaved(false);
    _recordedVehicle = vehicle;
    _homeCoordinate = vehicle->homePosition();
    _created = QDateTime::currentDateTimeUtc();
    _startEpochMs = QDateTime::currentMSecsSinceEpoch();
    _vehicleId = vehicle->id();
    _vehicleFirmware = vehicle->firmwareTypeString();
    _vehicleType = vehicle->vehicleTypeString();

    (void) connect(vehicle, &Vehicle::coordinateChanged,
                   this, &ZGCTrajectoryRecorder::_vehicleCoordinateChanged, Qt::UniqueConnection);

    if (!_homeCoordinate.isValid()) {
        qCWarning(ZGCTrajectoryLog) << "recording started without valid home position, altitude fallback pending";
    }

    emit recordingChanged();
    emit rawPointCountChanged();
    qCInfo(ZGCTrajectoryLog) << "recording started"
                             << "vehicleId:" << _vehicleId
                             << "homeValid:" << _homeCoordinate.isValid();
}

void ZGCTrajectoryRecorder::_stopRecording()
{
    if (!_recording) {
        return;
    }
    _finishRecording();
}

void ZGCTrajectoryRecorder::_finishRecording()
{
    Vehicle *const vehicle = _recordedVehicle.data();
    if (vehicle) {
        (void) disconnect(vehicle, &Vehicle::coordinateChanged, this, &ZGCTrajectoryRecorder::_vehicleCoordinateChanged);
    }

    _recording = false;
    _recordedVehicle.clear();

    if (!_homeCoordinate.isValid() && !_points.isEmpty()) {
        _homeCoordinate = QGeoCoordinate(_points.constFirst().lat, _points.constFirst().lon, _points.constFirst().amslAlt);
        qCWarning(ZGCTrajectoryLog) << "home position invalid, fallback to first sample altitude"
                                    << "amslAlt:" << _homeCoordinate.altitude();
    }

    emit recordingChanged();
    if (!_points.isEmpty()) {
        _setHasUnsaved(true);
    }
}

void ZGCTrajectoryRecorder::_vehicleCoordinateChanged(const QGeoCoordinate &coordinate)
{
    if (!_recording) {
        return;
    }

    ZGCTrajectoryPoint point;
    point.lat = coordinate.latitude();
    point.lon = coordinate.longitude();
    point.amslAlt = coordinate.altitude();
    point.tMs = QDateTime::currentMSecsSinceEpoch() - _startEpochMs;
    if (!_points.isEmpty() && (point.tMs - _points.constLast().tMs) > ZGCTrajectory::kDegradedGapMs) {
        // 采样间隙降级：间隙处记标记位，后续抽稀以该点为路径断点锚。
        point.gap = true;
        qCWarning(ZGCTrajectoryLog) << "sampling gap detected, trajectory marked degraded"
                                    << "gapMs:" << point.tMs - _points.constLast().tMs;
    }
    _points.append(point);
    emit rawPointCountChanged();
}

void ZGCTrajectoryRecorder::_setHasUnsaved(bool hasUnsaved)
{
    if (_hasUnsaved != hasUnsaved) {
        _hasUnsaved = hasUnsaved;
        emit hasUnsavedTrajectoryChanged();
    }
}
