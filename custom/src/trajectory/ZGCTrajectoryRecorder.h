/****************************************************************************
 * ZGC Trajectory Recorder — 轨迹录制器（数据层，无 UI）
 *
 * 轨迹一键复飞批 1。订阅 MultiVehicleManager 活动载具的 coordinateChanged 记录
 * {lat, lon, amslAlt, tMs} 原始采样；armed 自动开始 / disarm 自动停止（停止 ≠ 保存，
 * 数据留内存待用户决定）；另提供手动 start/stop Q_INVOKABLE（批 2 UI 与调试用）。
 *
 * 生命周期纪律：与 Vehicle 任务管理器信号解耦（不碰 Vehicle::trajectoryPoints）；
 * 录制绑定到开始时刻的活动载具，活动载具切换或录制中载具销毁即自动停止，
 * QPointer 防护悬空。
 *
 * QML 暴露：本类实例经 CustomPlugin::createQmlApplicationEngine 以单一 context
 * property "zgcTrajectory" 注入；轨迹库经 library 属性访问（zgcTrajectory.library）。
 ****************************************************************************/

#pragma once

#include <QtCore/QDateTime>
#include <QtCore/QList>
#include <QtCore/QObject>
#include <QtCore/QPointer>
#include <QtCore/QString>
#include <QtCore/QVariantMap>
#include <QtPositioning/QGeoCoordinate>

#include "trajectory/ZGCTrajectorySimplifier.h"

class Vehicle;
class ZGCTrajectoryLibrary;

class ZGCTrajectoryRecorder : public QObject
{
    Q_OBJECT

public:
    explicit ZGCTrajectoryRecorder(QObject *parent = nullptr);
    ~ZGCTrajectoryRecorder() override;

    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(int rawPointCount READ rawPointCount NOTIFY rawPointCountChanged)
    Q_PROPERTY(bool hasUnsavedTrajectory READ hasUnsavedTrajectory NOTIFY hasUnsavedTrajectoryChanged)
    Q_PROPERTY(ZGCTrajectoryLibrary *library READ library CONSTANT)

    /// 正在录制中（绑定开始时刻的活动载具）。
    bool recording() const { return _recording; }
    /// 当前缓冲区内的原始采样点数（录制中实时增长；停止后保持待保存）。
    int rawPointCount() const { return _points.size(); }
    /// 录制已停止且内存中留有待用户决定（保存/丢弃）的轨迹数据。
    bool hasUnsavedTrajectory() const { return _hasUnsaved; }
    ZGCTrajectoryLibrary *library() const { return _library; }

    /// Q_INVOKABLE 手动开始（批 2 UI / 调试）：绑定当前活动载具；无活动载具时告警并忽略。
    /// 若存在未保存轨迹将被覆盖（qCWarning 留痕；批 2 UI 应先引导用户确认）。
    Q_INVOKABLE void startRecording();
    /// Q_INVOKABLE 手动停止：数据留内存，不落盘。
    Q_INVOKABLE void stopRecording();
    /// Q_INVOKABLE 丢弃未保存的轨迹数据（用户明确放弃时调用）。
    Q_INVOKABLE void discardUnsavedTrajectory();
    /// Q_INVOKABLE 未保存轨迹的快照（QVariantMap，COW 拷贝，不动内存），供轨迹库保存。
    /// 结构：{ created, home{lat,lon,amslAlt}, vehicle{id,firmware,type}, degraded, points[{lat,lon,amslAlt,tMs,gap}] }
    Q_INVOKABLE QVariantMap unsavedTrajectory() const;

signals:
    void recordingChanged();
    void rawPointCountChanged();
    void hasUnsavedTrajectoryChanged();

private slots:
    void _activeVehicleChanged(Vehicle *activeVehicle);
    void _vehicleCoordinateChanged(const QGeoCoordinate &coordinate);
    void _vehicleArmedChanged(bool armed);
    void _recordedVehicleDestroyed();

private:
    void _startWithVehicle(Vehicle *vehicle);
    void _stopRecording();
    void _connectVehicleSignals(Vehicle *vehicle);
    void _disconnectVehicleSignals(Vehicle *vehicle);
    void _finishRecording();
    void _setHasUnsaved(bool hasUnsaved);

    //---- 成员 ----//

    ZGCTrajectoryLibrary *_library = nullptr;

    QPointer<Vehicle> _activeVehicle;      ///< 跟踪中的活动载具（armed 触发源）
    QPointer<Vehicle> _recordedVehicle;    ///< 录制绑定的载具（坐标采样源）

    QList<ZGCTrajectoryPoint> _points;     ///< 原始采样缓冲（录制中增长，停止后待保存）
    QGeoCoordinate _homeCoordinate;        ///< 录制开始时刻绑定的 home（AMSL）
    QDateTime _created;                    ///< 录制开始时刻（ISO8601 落盘用）
    qint64 _startEpochMs = 0;              ///< tMs 时间基准（录制开始的 epoch 毫秒）
    QString _vehicleFirmware;              ///< 录制开始时刻的载具信息（文件头用）
    QString _vehicleType;
    int _vehicleId = -1;

    bool _recording = false;
    bool _hasUnsaved = false;
};
