/****************************************************************************
 * ZGC Trajectory Safety Gate — 复飞任务执行窗口状态（无 UI）
 *
 * 轨迹一键复飞批 3。唯一职责：维护「复飞任务执行窗口」布尔状态，供 Fly 视图
 * 常驻急停按钮判定可见性（FlyViewCustomLayer 覆盖件消费）。
 *
 * 设计纪律（任务单 ZFYZ-轨迹复飞-批3）：
 *   - 急停可见性不依赖复飞链路自身健康：beginReflyMissionWindow() 在 sendToVehicle
 *     发起时刻置位，此后即使上传/构建链路任何环节失败，窗口（及急停按钮）仍然保持
 *     ——宁可多显示，不可漏显示；
 *   - 窗口关闭取保守外部事实：载具上锁解除（本次飞行结束）或活动载具消失（断链/
 *     移除）即自动清零，不依赖任何 QML 组件存活；
 *   - 本类不触碰飞控指令：急停动作本身由 Fly 侧经既有 GuidedActionsController
 *     原生动作完成，与本类无关。
 *
 * QML 暴露：实例经 CustomPlugin::createQmlApplicationEngine 以 context property
 * "zgcTrajectorySafety" 注入（与 "zgcTrajectory" 同法，先例 src/API/QGCCorePlugin.cc）。
 ****************************************************************************/

#pragma once

#include <QtCore/QObject>
#include <QtCore/QPointer>

class Vehicle;

class ZGCTrajectorySafetyGate : public QObject
{
    Q_OBJECT

    /// 复飞任务执行窗口：sendToVehicle 发起 → 载具上锁解除/活动载具消失。
    Q_PROPERTY(bool reflyMissionActive READ reflyMissionActive NOTIFY reflyMissionActiveChanged)

public:
    explicit ZGCTrajectorySafetyGate(QObject *parent = nullptr);

    bool reflyMissionActive() const { return _reflyMissionActive; }

    /// Q_INVOKABLE：复飞任务发起上传时刻调用（幂等）。置位后不因链路后续失败而回退，
    /// 仅由载具上锁解除/活动载具消失自动关闭。
    Q_INVOKABLE void beginReflyMissionWindow();

signals:
    void reflyMissionActiveChanged();

private slots:
    void _activeVehicleChanged(Vehicle *activeVehicle);
    void _vehicleArmedChanged(bool armed);

private:
    void _connectVehicleSignals(Vehicle *vehicle);
    void _disconnectVehicleSignals(Vehicle *vehicle);
    void _setReflyMissionActive(bool active);

    QPointer<Vehicle> _activeVehicle;    ///< 跟踪中的活动载具（armed 关闭源）
    bool _reflyMissionActive = false;
};
