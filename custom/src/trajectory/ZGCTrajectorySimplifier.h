/****************************************************************************
 * ZGC Trajectory Data Layer — Simplifier (纯数据类型 + 纯静态算法)
 *
 * 轨迹一键复飞批 1（数据层）。本头文件是轨迹数据层的共通词汇表：
 *   - ZGCTrajectoryPoint       单个原始采样点（WGS84 + AMSL 海拔 + 相对时间戳）
 *   - ZGCTrajectory 常量区      全部阈值/上限集中于此（供录制器/轨迹库/QML 侧调参）
 *   - ZGCTrajectorySimplifier  命名空间内纯函数：有界 DP 抽稀 + 统计辅助
 *
 * 设计约束（任务单 ZFYZ-轨迹复飞-批1）：
 *   - 不用 Vehicle::trajectoryPoints（共线压缩丢点/无时间戳/收任务即清空），本模块
 *     自持采样数据，生命周期与任务管理器信号解耦。
 *   - 点内只存 AMSL 海拔；相对高度 = amslAlt − homeAmslAlt，在抽稀/统计时派生，
 *     home 海拔由录制器在录制开始时刻绑定。
 *   - 抽稀管线：<最小点间距预过滤> → <Douglas-Peucker(3D)> → <超上限则二分 ε 重跑>；
 *     起降段（相对高度低于剥离阈值的连续首尾点）先剥离。
 *   - 采样间隙标记（gap）为路径断点锚：DP 不允许跨越间隙用直线替代真实绕飞段。
 ****************************************************************************/

#pragma once

#include <QtCore/QDateTime>
#include <QtCore/QList>
#include <QtCore/QLoggingCategory>
#include <QtPositioning/QGeoCoordinate>

Q_DECLARE_LOGGING_CATEGORY(ZGCTrajectoryLog)

/*===========================================================================*/

/// 单个原始轨迹采样点。raw 双海拔约定：点只存 AMSL，home 海拔存文件头（派生 relAlt）。
struct ZGCTrajectoryPoint
{
    double lat = 0.0;       ///< WGS84 纬度（度）
    double lon = 0.0;       ///< WGS84 经度（度）
    double amslAlt = 0.0;   ///< AMSL 海拔（米）
    qint64 tMs = 0;         ///< 相对录制起点的时间戳（毫秒，首点为 0）
    bool gap = false;       ///< true: 与前一点之间采样间隙超过阈值（数据降级标记位）
};

/*===========================================================================*/
/// 阈值/上限常量区 —— 全部可调参数集中于此，改动前先读注释中的安全含义。
/// （任务单锁定值：50 点上限 / 2m 间距 / 5m 起降剥离 / 5s 降级间隙；默认 3 点下限）
/*===========================================================================*/

namespace ZGCTrajectory {

    /// 存储格式版本。加载时版本不识别的文件标记为 corrupted（列表可见，不静默丢弃）。
    inline constexpr int kFormatVersion = 1;

    /// 轨迹文件扩展名（不带点）：<savePath>/ZGCTrajectories/<name>.zgctraj
    inline constexpr const char *kFileExtension = "zgctraj";

    /// 最小点间距预过滤阈值（米，水平大圆距离）。小于该间距的点视为悬停抖动，
    /// 在 DP 之前丢弃以控制 DP 输入规模。调大会丢慢速精细机动，调小 DP 变慢。
    inline constexpr double kMinPointSpacingMeters = 2.0;

    /// 抽稀输出点数上限。二分 ε 重跑 DP 直到 ≤ 该值。上限直接决定复飞任务的航点数
    /// （飞控任务规模），调大前先确认飞控任务容量与批 2 任务构建兼容。
    inline constexpr int kMaxSimplifiedPoints = 50;

    /// 起降段剥离阈值（米，相对 home 海拔）。首尾连续低于该值的点视为地面滑跑/
    /// 起降过渡段剔除。必须大于 GPS 垂直噪声幅度（典型 ±3m），否则起飞前抖动混入任务。
    inline constexpr double kStripRelAltMeters = 5.0;

    /// 采样间隙降级阈值（毫秒）。相邻采样点时间差超过该值置 degraded（间隙处记
    /// gap 标记位），复飞构建方应视该段为"未观测"，不可用直线插值替代。
    inline constexpr qint64 kDegradedGapMs = 5000;

    /// 抽稀最小输入点数。少于该值的输入原样返回（DP 至少需要 3 点才有意义）。
    inline constexpr int kMinSimplifyPoints = 3;

    /// 二分 ε 的收敛精度（米）与最大迭代轮数。0.1m 精度对航点任务足够；
    /// 25 轮可覆盖任意对角线规模，防病态输入死循环。
    inline constexpr double kEpsilonBinarySearchStepMeters = 0.1;
    inline constexpr int kEpsilonBinarySearchMaxIterations = 25;

}  // namespace ZGCTrajectory

/*===========================================================================*/

/// 有界抽稀与统计辅助（纯静态函数，无状态，可在测试中独立调用）。
namespace ZGCTrajectorySimplifier {

    /// 有界 DP 抽稀管线：起降段剥离 → 最小点间距预过滤 → DP → 超上限二分 ε 重跑。
    /// @param rawPoints    原始采样序列（按时间升序）
    /// @param homeAmslAlt  home AMSL 海拔（米），用于派生相对高度
    /// @return 抽稀后点集；输入不足 kMinSimplifyPoints 时原样返回
    QList<ZGCTrajectoryPoint> simplify(const QList<ZGCTrajectoryPoint> &rawPoints, double homeAmslAlt);

    /// 两点水平大圆距离（米）。无效坐标返回 0。
    double horizontalDistanceMeters(const ZGCTrajectoryPoint &a, const ZGCTrajectoryPoint &b);

    /// 路径水平总长度（米），逐段累加。
    double pathDistanceMeters(const QList<ZGCTrajectoryPoint> &points);

    /// 最大相对高度（米，AMSL − homeAmslAlt）；空序列返回 0。
    double maxRelativeAltitudeMeters(const QList<ZGCTrajectoryPoint> &points, double homeAmslAlt);

    /// 序列中是否存在 gap 降级标记（首点 gap 无意义，忽略）。
    bool hasDegradedGap(const QList<ZGCTrajectoryPoint> &points);

    /// 总时长（秒，末点 tMs − 首点 tMs）；空/单点序列返回 0。
    double durationSeconds(const QList<ZGCTrajectoryPoint> &points);

}  // namespace ZGCTrajectorySimplifier
