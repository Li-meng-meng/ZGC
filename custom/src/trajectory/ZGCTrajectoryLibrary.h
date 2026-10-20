/****************************************************************************
 * ZGC Trajectory Library — 轨迹库存储（数据层，无 UI）
 *
 * 轨迹一键复飞批 1。管理 <QGC savePath>/ZGCTrajectories/ 下的自有版本化 JSON
 * 轨迹文件（扩展名 .zgctraj），作为 QAbstractListModel 供批 2 面板直接绑定
 * （name/created/pointCount/distance/durationS/maxRelAlt/degraded/corrupted）。
 *
 * 存储纪律：
 *   - 原子写：QSaveFile（临时文件 + commit 原子 rename），失败不留半截文件；
 *   - 加载时损坏 / 版本不识别的文件：列表中标记 corrupted 可见，不静默丢弃；
 *   - 同名文件自动加序号（name.zgctraj → name-2.zgctraj → ...）；
 *   - 保存目录不存在时自动创建。
 *
 * 与批 2 的接口约定：loadTrajectory(fileName) 返回与 ZGCTrajectoryRecorder::
 * unsavedTrajectory() 同构的 QVariantMap（header + points 原始采样），复飞任务
 * 用原生 insert API 实时构建，不落 .plan 文件格式。
 ****************************************************************************/

#pragma once

#include <QtCore/QAbstractListModel>
#include <QtCore/QDateTime>
#include <QtCore/QHash>
#include <QtCore/QList>
#include <QtCore/QString>
#include <QtCore/QVariantMap>

class ZGCTrajectoryLibrary : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    explicit ZGCTrajectoryLibrary(QObject *parent = nullptr);

    // QAbstractListModel overrides
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    enum Roles
    {
        NameRole = Qt::UserRole + 1,
        FileNameRole,
        CreatedRole,
        PointCountRole,
        DistanceRole,
        DurationRole,
        MaxRelAltRole,
        DegradedRole,
        CorruptedRole,
        VersionRole,
    };

    int count() const { return _entries.size(); }

    /// 保存一条原始轨迹（入参结构与 ZGCTrajectoryRecorder::unsavedTrajectory() 同构；
    /// name 由调用方提供）。同名自动加序号。成功返回落盘文件名，失败返回空串。
    Q_INVOKABLE QString saveTrajectory(const QString &name, const QVariantMap &trajectory);
    /// 删除轨迹文件（fileName 为列表中的 fileName 角色）。
    Q_INVOKABLE bool deleteTrajectory(const QString &fileName);
    /// 完整加载轨迹（批 2 复飞任务构建用）。损坏/缺失时返回带 corrupted=true 与
    /// error 说明的 map，不抛异常不弹窗（错误经 errorOccurred 信号供 UI 展示）。
    Q_INVOKABLE QVariantMap loadTrajectory(const QString &fileName) const;
    // ZGC: 批 2 QML 桥——加载轨迹并做有界 DP 抽稀（抽稀器为 C++ 纯命名空间，QML 调不到，
    // 故经本桥转发）。成功返回 [{lat, lon, relAlt}, ...]（relAlt = amslAlt − homeAmslAlt，米，
    // 已剥离起降段）；损坏/失败返回空表并 emit errorOccurred 供 UI 展示。— ZFYZ-轨迹复飞-批2
    Q_INVOKABLE QVariantList simplifyTrajectory(const QString &fileName);
    /// 重新扫描存储目录（外部改动文件后同步列表用）。
    Q_INVOKABLE void refresh();

signals:
    void countChanged();
    void errorOccurred(const QString &message);

private:
    struct Entry
    {
        QString fileName;      ///< 含扩展名的文件名（非全路径）
        QString name;          ///< 用户可见名称
        QDateTime created;
        int pointCount = 0;
        double distance = 0.0;    ///< 米（水平路径长）
        double durationS = 0.0;   ///< 秒
        double maxRelAlt = 0.0;   ///< 米（相对 home）
        bool degraded = false;    ///< 存在采样间隙降级
        bool corrupted = false;   ///< 损坏或版本不识别（保留列表可见）
        int version = 0;          ///< 文件头格式版本（不识别时照实记录）
    };

    QString _directory() const;                       ///< <savePath>/ZGCTrajectories（可能为空：savePath 未配置）
    void _scanDirectory();
    void _insertEntry(const Entry &entry);            ///< 按排序规则插入（corrupted 靠后，created 新的在前）
    QString _uniqueFilePath(const QString &baseName) const;
    Entry _loadEntryFromFile(const QString &filePath) const;

    QList<Entry> _entries;
};
