/****************************************************************************
 * ZGC Trajectory Simplifier — 有界 DP 抽稀实现
 *
 * 3D Douglas-Peucker：经纬度按等距圆柱近似投影到局部米制平面（参考纬度取段起点，
 * 航迹尺度 km 级，失真可忽略），z 轴直接用 AMSL 海拔差；点到线段距离在 3D 中求取，
 * 水平绕飞与垂直起伏同时约束。gap 标记点为强制锚点并切分递归区间，保证 DP 不会
 * 用一条直线跨越采样间隙替代未观测的真实路径。
 ****************************************************************************/

#include "ZGCTrajectorySimplifier.h"

#include "QGCLoggingCategory.h"

#include <QtGlobal>

#include <algorithm>
#include <cmath>
#include <numbers>
#include <stack>
#include <utility>
#include <vector>

QGC_LOGGING_CATEGORY(ZGCTrajectoryLog, "Custom.ZGCTrajectory")

namespace {

    constexpr double kEarthRadiusMeters = 6371000.0;
    constexpr double kDegToRad = std::numbers::pi / 180.0;

    /// 局部米制平面坐标（等距圆柱近似，参考纬度 refLatRad 固定）。
    struct LocalVec3
    {
        double x = 0.0;  ///< 东向（米）
        double y = 0.0;  ///< 北向（米）
        double z = 0.0;  ///< AMSL 海拔（米）
    };

    LocalVec3 toLocal(const ZGCTrajectoryPoint &point, double refLatRad)
    {
        LocalVec3 vec;
        vec.x = point.lon * kDegToRad * std::cos(refLatRad) * kEarthRadiusMeters;
        vec.y = point.lat * kDegToRad * kEarthRadiusMeters;
        vec.z = point.amslAlt;
        return vec;
    }

    /// 点到 3D 线段 a–b 的距离（米，垂足被钳制在线段内）。
    double pointSegmentDistance3D(const LocalVec3 &p, const LocalVec3 &a, const LocalVec3 &b)
    {
        const double abx = b.x - a.x;
        const double aby = b.y - a.y;
        const double abz = b.z - a.z;
        const double apx = p.x - a.x;
        const double apy = p.y - a.y;
        const double apz = p.z - a.z;

        const double ab2 = abx * abx + aby * aby + abz * abz;
        if (ab2 <= 0.0) {
            return std::sqrt(apx * apx + apy * apy + apz * apz);
        }

        const double t = std::clamp((abx * apx + aby * apy + abz * apz) / ab2, 0.0, 1.0);
        const double dx = apx - t * abx;
        const double dy = apy - t * aby;
        const double dz = apz - t * abz;
        return std::sqrt(dx * dx + dy * dy + dz * dz);
    }

    /// 3D Douglas-Peucker。keep 数组含强制锚点（端点 + gap 点及其前驱）；递归区间
    /// 遇到内部锚点时先按锚点切分，避免跨间隙求垂距。
    QList<ZGCTrajectoryPoint> douglasPeucker(const QList<ZGCTrajectoryPoint> &points, double epsilon)
    {
        const int count = points.size();
        if (count <= 2) {
            return points;
        }

        std::vector<bool> keep(static_cast<size_t>(count), false);
        keep[0] = true;
        keep[static_cast<size_t>(count - 1)] = true;
        for (int i = 1; i < count; ++i) {
            if (points[i].gap) {
                keep[static_cast<size_t>(i)] = true;
                keep[static_cast<size_t>(i - 1)] = true;
            }
        }

        std::stack<std::pair<int, int>> ranges;
        ranges.emplace(0, count - 1);
        while (!ranges.empty()) {
            const auto [first, last] = ranges.top();
            ranges.pop();
            if (last - first < 2) {
                continue;
            }

            // 区间内部已有锚点（gap 切分产生的另一侧等）：按第一个锚点切分递归。
            int anchor = -1;
            for (int i = first + 1; i < last; ++i) {
                if (keep[static_cast<size_t>(i)]) {
                    anchor = i;
                    break;
                }
            }
            if (anchor != -1) {
                ranges.emplace(first, anchor);
                ranges.emplace(anchor, last);
                continue;
            }

            const double refLatRad = points[first].lat * kDegToRad;
            const LocalVec3 a = toLocal(points[first], refLatRad);
            const LocalVec3 b = toLocal(points[last], refLatRad);

            double maxDist = -1.0;
            int maxIndex = -1;
            for (int i = first + 1; i < last; ++i) {
                const double dist = pointSegmentDistance3D(toLocal(points[i], refLatRad), a, b);
                if (dist > maxDist) {
                    maxDist = dist;
                    maxIndex = i;
                }
            }

            if (maxIndex != -1 && maxDist > epsilon) {
                keep[static_cast<size_t>(maxIndex)] = true;
                ranges.emplace(first, maxIndex);
                ranges.emplace(maxIndex, last);
            }
        }

        QList<ZGCTrajectoryPoint> result;
        result.reserve(count);
        for (int i = 0; i < count; ++i) {
            if (keep[static_cast<size_t>(i)]) {
                result.append(points[i]);
            }
        }
        return result;
    }

    /// 首尾连续低于剥离阈值的点剔除。全程低于阈值时不剥离（防清空轨迹）。
    QList<ZGCTrajectoryPoint> stripTakeoffLanding(const QList<ZGCTrajectoryPoint> &points, double homeAmslAlt)
    {
        if (points.isEmpty()) {
            return points;
        }

        int firstAbove = -1;
        for (int i = 0; i < points.size(); ++i) {
            if (points[i].amslAlt - homeAmslAlt >= ZGCTrajectory::kStripRelAltMeters) {
                firstAbove = i;
                break;
            }
        }
        if (firstAbove < 0) {
            qCWarning(ZGCTrajectoryLog) << "entire trajectory below strip threshold, keeping all points"
                                        << "threshold(m):" << ZGCTrajectory::kStripRelAltMeters
                                        << "pointCount:" << points.size();
            return points;
        }

        int lastAbove = firstAbove;
        for (int i = points.size() - 1; i >= firstAbove; --i) {
            if (points[i].amslAlt - homeAmslAlt >= ZGCTrajectory::kStripRelAltMeters) {
                lastAbove = i;
                break;
            }
        }

        return points.mid(firstAbove, lastAbove - firstAbove + 1);
    }

    /// 最小点间距预过滤：小于阈值的水平位移（悬停抖动）丢弃；gap 点恒保留（锚点）。
    QList<ZGCTrajectoryPoint> minSpacingFilter(const QList<ZGCTrajectoryPoint> &points)
    {
        QList<ZGCTrajectoryPoint> filtered;
        filtered.reserve(points.size());
        for (const ZGCTrajectoryPoint &point : points) {
            if (filtered.isEmpty()
                || point.gap
                || ZGCTrajectorySimplifier::horizontalDistanceMeters(filtered.constLast(), point)
                       >= ZGCTrajectory::kMinPointSpacingMeters) {
                filtered.append(point);
            }
        }
        return filtered;
    }

    /// 点集包围盒 3D 对角线（局部米制），作为二分 ε 的上界。
    double boundingDiagonalMeters(const QList<ZGCTrajectoryPoint> &points)
    {
        if (points.isEmpty()) {
            return 0.0;
        }

        const double refLatRad = points.first().lat * kDegToRad;
        LocalVec3 minimum = toLocal(points.first(), refLatRad);
        LocalVec3 maximum = minimum;
        for (const ZGCTrajectoryPoint &point : points) {
            const LocalVec3 vec = toLocal(point, refLatRad);
            minimum.x = std::min(minimum.x, vec.x);
            minimum.y = std::min(minimum.y, vec.y);
            minimum.z = std::min(minimum.z, vec.z);
            maximum.x = std::max(maximum.x, vec.x);
            maximum.y = std::max(maximum.y, vec.y);
            maximum.z = std::max(maximum.z, vec.z);
        }

        const double dx = maximum.x - minimum.x;
        const double dy = maximum.y - minimum.y;
        const double dz = maximum.z - minimum.z;
        return std::sqrt(dx * dx + dy * dy + dz * dz);
    }

}  // namespace

/*===========================================================================*/

namespace ZGCTrajectorySimplifier {

    QList<ZGCTrajectoryPoint> simplify(const QList<ZGCTrajectoryPoint> &rawPoints, double homeAmslAlt)
    {
        if (rawPoints.size() < ZGCTrajectory::kMinSimplifyPoints) {
            return rawPoints;
        }

        const QList<ZGCTrajectoryPoint> stripped = stripTakeoffLanding(rawPoints, homeAmslAlt);
        const QList<ZGCTrajectoryPoint> filtered = minSpacingFilter(stripped);
        if (filtered.size() < ZGCTrajectory::kMinSimplifyPoints) {
            return filtered;
        }

        QList<ZGCTrajectoryPoint> result = douglasPeucker(filtered, 0.0);
        if (result.size() <= ZGCTrajectory::kMaxSimplifiedPoints) {
            return result;
        }

        // 超上限：二分最小可行 ε（ε 增大 → 保留点减少）。上界取包围盒对角线，
        // 该 ε 下 DP 只留端点与 gap 锚，必然 ≤ 上限；收敛后取 ≤ 上限的最小 ε 结果。
        const double diagonal = boundingDiagonalMeters(filtered);
        double lo = 0.0;
        double hi = diagonal;
        QList<ZGCTrajectoryPoint> best = douglasPeucker(filtered, hi);
        for (int iteration = 0;
             iteration < ZGCTrajectory::kEpsilonBinarySearchMaxIterations
             && (hi - lo) > ZGCTrajectory::kEpsilonBinarySearchStepMeters;
             ++iteration) {
            const double mid = lo + (hi - lo) / 2.0;
            const QList<ZGCTrajectoryPoint> candidate = douglasPeucker(filtered, mid);
            if (candidate.size() <= ZGCTrajectory::kMaxSimplifiedPoints) {
                hi = mid;
                best = candidate;
            } else {
                lo = mid;
            }
        }

        qCDebug(ZGCTrajectoryLog) << "bounded DP applied"
                                  << "raw:" << rawPoints.size()
                                  << "filtered:" << filtered.size()
                                  << "result:" << best.size()
                                  << "epsilon(m):" << hi
                                  << "homeAmslAlt(m):" << homeAmslAlt;
        return best;
    }

    double horizontalDistanceMeters(const ZGCTrajectoryPoint &a, const ZGCTrajectoryPoint &b)
    {
        const QGeoCoordinate coordinateA(a.lat, a.lon);
        const QGeoCoordinate coordinateB(b.lat, b.lon);
        if (!coordinateA.isValid() || !coordinateB.isValid()) {
            return 0.0;
        }
        return coordinateA.distanceTo(coordinateB);
    }

    double pathDistanceMeters(const QList<ZGCTrajectoryPoint> &points)
    {
        double total = 0.0;
        for (int i = 1; i < points.size(); ++i) {
            total += horizontalDistanceMeters(points[i - 1], points[i]);
        }
        return total;
    }

    double maxRelativeAltitudeMeters(const QList<ZGCTrajectoryPoint> &points, double homeAmslAlt)
    {
        double maxRelAlt = 0.0;
        for (const ZGCTrajectoryPoint &point : points) {
            maxRelAlt = std::max(maxRelAlt, point.amslAlt - homeAmslAlt);
        }
        return maxRelAlt;
    }

    bool hasDegradedGap(const QList<ZGCTrajectoryPoint> &points)
    {
        for (int i = 1; i < points.size(); ++i) {
            if (points[i].gap) {
                return true;
            }
        }
        return false;
    }

    double durationSeconds(const QList<ZGCTrajectoryPoint> &points)
    {
        if (points.size() < 2) {
            return 0.0;
        }
        return static_cast<double>(points.constLast().tMs - points.constFirst().tMs) / 1000.0;
    }

}  // namespace ZGCTrajectorySimplifier
