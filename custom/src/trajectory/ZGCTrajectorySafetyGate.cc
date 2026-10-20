/****************************************************************************
 * ZGC Trajectory Safety Gate — 实现
 *
 * 信号连接纪律与录制器同构（ZGCTrajectoryRecorder.cc）：
 *   - armedChanged 挂活动载具，活动载具切换时换绑，Qt::UniqueConnection 防重；
 *   - 所有 vehicle 连接以 this 为接收上下文，载具销毁由 Qt 自动断连；
 *   - 活动载具消失（断链/移除）视同飞行结束，窗口立即关闭。
 ****************************************************************************/

#include "ZGCTrajectorySafetyGate.h"

#include "MultiVehicleManager.h"
#include "Vehicle.h"
#include "trajectory/ZGCTrajectorySimplifier.h"  // ZGCTrajectoryLog

ZGCTrajectorySafetyGate::ZGCTrajectorySafetyGate(QObject *parent)
    : QObject(parent)
{
    MultiVehicleManager *const manager = MultiVehicleManager::instance();
    if (manager) {
        (void) connect(manager, &MultiVehicleManager::activeVehicleChanged,
                       this, &ZGCTrajectorySafetyGate::_activeVehicleChanged);
        _activeVehicle = manager->activeVehicle();
        _connectVehicleSignals(_activeVehicle.data());
    } else {
        qCCritical(ZGCTrajectoryLog) << "MultiVehicleManager instance not available, safety gate blind to vehicle removal";
    }
}

void ZGCTrajectorySafetyGate::beginReflyMissionWindow()
{
    if (_reflyMissionActive) {
        return;
    }
    qCInfo(ZGCTrajectoryLog) << "refly mission window opened (emergency stop armed)";
    _setReflyMissionActive(true);
}

void ZGCTrajectorySafetyGate::_activeVehicleChanged(Vehicle *activeVehicle)
{
    Vehicle *const previous = _activeVehicle.data();
    if (previous == activeVehicle) {
        return;
    }

    _disconnectVehicleSignals(previous);
    _activeVehicle = activeVehicle;
    _connectVehicleSignals(activeVehicle);

    // 活动载具消失（断链/移除）：无法再执行任何引导动作，窗口关闭（宁可少显示，
    // 此时急停已无对象；重新上传任务会再次置位）。
    if (_reflyMissionActive && !activeVehicle) {
        qCWarning(ZGCTrajectoryLog) << "active vehicle gone, refly mission window closed";
        _setReflyMissionActive(false);
    }
}

void ZGCTrajectorySafetyGate::_connectVehicleSignals(Vehicle *vehicle)
{
    if (!vehicle) {
        return;
    }
    (void) connect(vehicle, &Vehicle::armedChanged,
                   this, &ZGCTrajectorySafetyGate::_vehicleArmedChanged, Qt::UniqueConnection);
}

void ZGCTrajectorySafetyGate::_disconnectVehicleSignals(Vehicle *vehicle)
{
    if (!vehicle) {
        return;
    }
    (void) disconnect(vehicle, &Vehicle::armedChanged, this, &ZGCTrajectorySafetyGate::_vehicleArmedChanged);
}

void ZGCTrajectorySafetyGate::_vehicleArmedChanged(bool armed)
{
    auto *const vehicle = qobject_cast<Vehicle *>(sender());
    if (!vehicle || vehicle != _activeVehicle.data()) {
        return;
    }

    if (!armed && _reflyMissionActive) {
        // 上锁解除＝本次飞行结束，任务执行窗口关闭。
        qCInfo(ZGCTrajectoryLog) << "vehicle disarmed, refly mission window closed";
        _setReflyMissionActive(false);
    }
}

void ZGCTrajectorySafetyGate::_setReflyMissionActive(bool active)
{
    if (_reflyMissionActive == active) {
        return;
    }
    _reflyMissionActive = active;
    emit reflyMissionActiveChanged();
}
