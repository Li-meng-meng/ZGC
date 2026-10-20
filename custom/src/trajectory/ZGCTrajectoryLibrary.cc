/****************************************************************************
 * ZGC Trajectory Library — 实现
 *
 * JSON 说明：本格式为自有版本化 JSON（zgcTrajectoryVersion 头 + home/vehicle/stats
 * 结构化对象 + points 数组），直接用 QJsonDocument 读写并做逐字段严格类型校验。
 * 不复用 GeoJsonHelper（其仅为 GeoJSON/plan 的坐标数组约定服务，无对象级校验能力）；
 * 仓库内旧 JsonHelper 工具类已不存在（仅剩 GeoJsonHelper）。
 ****************************************************************************/

#include "ZGCTrajectoryLibrary.h"

#include "AppSettings.h"
#include "Fact.h"
#include "SettingsManager.h"
#include "trajectory/ZGCTrajectorySimplifier.h"

#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QJsonArray>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QJsonParseError>
#include <QtCore/QRegularExpression>
#include <QtCore/QSaveFile>

#include <algorithm>

namespace {

    //---- JSON 键名（格式 v1，改动须同步 kFormatVersion）----//

    const char *kKeyVersion = "zgcTrajectoryVersion";
    const char *kKeyName = "name";
    const char *kKeyCreated = "created";
    const char *kKeyHome = "home";
    const char *kKeyVehicle = "vehicle";
    const char *kKeyStats = "stats";
    const char *kKeyPoints = "points";

    const char *kKeyLat = "lat";
    const char *kKeyLon = "lon";
    const char *kKeyAmslAlt = "amslAlt";
    const char *kKeyTMs = "tMs";
    const char *kKeyGap = "gap";
    const char *kKeyId = "id";
    const char *kKeyFirmware = "firmware";
    const char *kKeyType = "type";
    const char *kKeyDistance = "distance";
    const char *kKeyDurationS = "durationS";
    const char *kKeyMaxRelAlt = "maxRelAlt";
    const char *kKeyDegraded = "degraded";

    //---- 严格类型读取：缺失或类型不符一律失败，由调用方标记 corrupted ----//

    bool jsonDouble(const QJsonObject &object, const char *key, double &out)
    {
        const QJsonValue value = object.value(QLatin1String(key));
        if (!value.isDouble()) {
            return false;
        }
        out = value.toDouble();
        return true;
    }

    bool jsonBool(const QJsonObject &object, const char *key, bool &out)
    {
        const QJsonValue value = object.value(QLatin1String(key));
        if (!value.isBool()) {
            return false;
        }
        out = value.toBool();
        return true;
    }

    bool jsonObject(const QJsonObject &object, const char *key, QJsonObject &out)
    {
        const QJsonValue value = object.value(QLatin1String(key));
        if (!value.isObject()) {
            return false;
        }
        out = value.toObject();
        return true;
    }

    /// points 数组 → 类型化点集。严格校验：每点必须为对象且 lat/lon/amslAlt 为数字
    /// （tMs 数字、gap 可选 bool），坐标须构成合法 QGeoCoordinate。
    bool parsePointsArray(const QJsonArray &array, QList<ZGCTrajectoryPoint> &points)
    {
        points.clear();
        points.reserve(array.size());
        for (const QJsonValue &value : array) {
            if (!value.isObject()) {
                return false;
            }
            const QJsonObject object = value.toObject();
            ZGCTrajectoryPoint point;
            if (!jsonDouble(object, kKeyLat, point.lat)
                || !jsonDouble(object, kKeyLon, point.lon)
                || !jsonDouble(object, kKeyAmslAlt, point.amslAlt)
                || !object.value(QLatin1String(kKeyTMs)).isDouble()) {
                return false;
            }
            point.tMs = static_cast<qint64>(object.value(QLatin1String(kKeyTMs)).toDouble());
            point.gap = object.value(QLatin1String(kKeyGap)).toBool(false);
            const QGeoCoordinate coordinate(point.lat, point.lon);
            if (!coordinate.isValid()) {
                return false;
            }
            points.append(point);
        }
        return true;
    }

    QList<ZGCTrajectoryPoint> pointsFromVariants(const QVariantList &pointVariants, bool &valid)
    {
        QList<ZGCTrajectoryPoint> points;
        points.reserve(pointVariants.size());
        valid = true;
        for (const QVariant &variant : pointVariants) {
            const QVariantMap map = variant.toMap();
            ZGCTrajectoryPoint point;
            point.lat = map.value(QLatin1String(kKeyLat)).toDouble();
            point.lon = map.value(QLatin1String(kKeyLon)).toDouble();
            point.amslAlt = map.value(QLatin1String(kKeyAmslAlt)).toDouble();
            point.tMs = map.value(QLatin1String(kKeyTMs)).toLongLong();
            point.gap = map.value(QLatin1String(kKeyGap)).toBool();
            if (!QGeoCoordinate(point.lat, point.lon).isValid()) {
                valid = false;
                return points;
            }
            points.append(point);
        }
        return points;
    }

    QVariantList pointsToVariants(const QList<ZGCTrajectoryPoint> &points)
    {
        QVariantList list;
        list.reserve(points.size());
        for (const ZGCTrajectoryPoint &point : points) {
            QVariantMap map;
            map.insert(QLatin1String(kKeyLat), point.lat);
            map.insert(QLatin1String(kKeyLon), point.lon);
            map.insert(QLatin1String(kKeyAmslAlt), point.amslAlt);
            map.insert(QLatin1String(kKeyTMs), point.tMs);
            map.insert(QLatin1String(kKeyGap), point.gap);
            list.append(map);
        }
        return list;
    }

    /// 文件名安全化：替换文件系统非法字符，去 Windows 尾部点/空格，空名回退时间戳名。
    QString sanitizeName(const QString &raw)
    {
        static const QRegularExpression forbidden(QStringLiteral(R"([\\/:*?"<>|])"));
        QString name = raw;
        name.replace(forbidden, QStringLiteral("_"));
        name = name.trimmed();
        while (name.endsWith(QLatin1Char('.')) || name.endsWith(QLatin1Char(' '))) {
            name.chop(1);
        }
        if (name.isEmpty()) {
            name = QStringLiteral("trajectory-%1")
                       .arg(QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyyMMdd-HHmmss")));
        }
        return name;
    }

    /// 读文件并解析 JSON 根对象。失败时 error 返回原因。
    bool readJsonRoot(const QString &filePath, QJsonObject &root, QString &error)
    {
        QFile file(filePath);
        if (!file.open(QIODevice::ReadOnly)) {
            error = QStringLiteral("file open failed: %1").arg(file.errorString());
            return false;
        }
        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            error = QStringLiteral("json parse failed: %1").arg(parseError.errorString());
            return false;
        }
        root = document.object();
        return true;
    }

}  // namespace

/*===========================================================================*/

ZGCTrajectoryLibrary::ZGCTrajectoryLibrary(QObject *parent)
    : QAbstractListModel(parent)
{
    _scanDirectory();
}

int ZGCTrajectoryLibrary::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }
    return _entries.size();
}

QVariant ZGCTrajectoryLibrary::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= _entries.size()) {
        return QVariant();
    }
    const Entry &entry = _entries[index.row()];
    switch (role) {
    case NameRole:
        return entry.name;
    case FileNameRole:
        return entry.fileName;
    case CreatedRole:
        return entry.created;
    case PointCountRole:
        return entry.pointCount;
    case DistanceRole:
        return entry.distance;
    case DurationRole:
        return entry.durationS;
    case MaxRelAltRole:
        return entry.maxRelAlt;
    case DegradedRole:
        return entry.degraded;
    case CorruptedRole:
        return entry.corrupted;
    case VersionRole:
        return entry.version;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> ZGCTrajectoryLibrary::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[NameRole] = "name";
    roles[FileNameRole] = "fileName";
    roles[CreatedRole] = "created";
    roles[PointCountRole] = "pointCount";
    roles[DistanceRole] = "distance";
    roles[DurationRole] = "durationS";
    roles[MaxRelAltRole] = "maxRelAlt";
    roles[DegradedRole] = "degraded";
    roles[CorruptedRole] = "corrupted";
    roles[VersionRole] = "version";
    return roles;
}

QString ZGCTrajectoryLibrary::saveTrajectory(const QString &name, const QVariantMap &trajectory)
{
    const QString directory = _directory();
    if (directory.isEmpty()) {
        const QString message = QStringLiteral("save path not configured");
        qCWarning(ZGCTrajectoryLog) << message;
        emit errorOccurred(message);
        return QString();
    }

    const QVariantList pointVariants = trajectory.value(QLatin1String(kKeyPoints)).toList();
    if (pointVariants.isEmpty()) {
        const QString message = QStringLiteral("trajectory has no points");
        qCWarning(ZGCTrajectoryLog) << message;
        emit errorOccurred(message);
        return QString();
    }
    bool pointsValid = false;
    const QList<ZGCTrajectoryPoint> points = pointsFromVariants(pointVariants, pointsValid);
    if (!pointsValid) {
        const QString message = QStringLiteral("invalid coordinate in points");
        qCWarning(ZGCTrajectoryLog) << message;
        emit errorOccurred(message);
        return QString();
    }

    // home：入参无效时以首采样点兜底（录制器已保证有效，此处防 QML 侧构造的入参）。
    const QVariantMap homeMap = trajectory.value(QLatin1String(kKeyHome)).toMap();
    QGeoCoordinate home(homeMap.value(QLatin1String(kKeyLat)).toDouble(),
                        homeMap.value(QLatin1String(kKeyLon)).toDouble(),
                        homeMap.value(QLatin1String(kKeyAmslAlt)).toDouble());
    if (!home.isValid()) {
        home = QGeoCoordinate(points.constFirst().lat, points.constFirst().lon, points.constFirst().amslAlt);
        qCWarning(ZGCTrajectoryLog) << "home invalid in input, fallback to first sample";
    }

    // created：QDateTime（录制器路径）或 ISO 字符串（外部构造路径），均无效则取当前时刻。
    QDateTime created = trajectory.value(QLatin1String(kKeyCreated)).toDateTime();
    if (!created.isValid()) {
        created = QDateTime::currentDateTimeUtc();
    }

    const QVariantMap vehicleMap = trajectory.value(QLatin1String(kKeyVehicle)).toMap();

    Entry entry;
    entry.name = sanitizeName(name);
    entry.created = created;
    entry.version = ZGCTrajectory::kFormatVersion;
    entry.pointCount = points.size();
    entry.distance = ZGCTrajectorySimplifier::pathDistanceMeters(points);
    entry.durationS = ZGCTrajectorySimplifier::durationSeconds(points);
    entry.maxRelAlt = ZGCTrajectorySimplifier::maxRelativeAltitudeMeters(points, home.altitude());
    entry.degraded = ZGCTrajectorySimplifier::hasDegradedGap(points);

    //---- 组装 JSON（格式 v1）----//

    QJsonObject homeObject;
    homeObject.insert(QLatin1String(kKeyLat), home.latitude());
    homeObject.insert(QLatin1String(kKeyLon), home.longitude());
    homeObject.insert(QLatin1String(kKeyAmslAlt), home.altitude());

    QJsonObject vehicleObject;
    const QVariant idVariant = vehicleMap.value(QLatin1String(kKeyId));
    vehicleObject.insert(QLatin1String(kKeyId), idVariant.isValid() ? idVariant.toInt() : -1);
    vehicleObject.insert(QLatin1String(kKeyFirmware), vehicleMap.value(QLatin1String(kKeyFirmware)).toString());
    vehicleObject.insert(QLatin1String(kKeyType), vehicleMap.value(QLatin1String(kKeyType)).toString());

    QJsonObject statsObject;
    statsObject.insert(QLatin1String(kKeyDistance), entry.distance);
    statsObject.insert(QLatin1String(kKeyDurationS), entry.durationS);
    statsObject.insert(QLatin1String(kKeyMaxRelAlt), entry.maxRelAlt);
    statsObject.insert(QLatin1String(kKeyDegraded), entry.degraded);

    QJsonArray pointsArray;
    for (const ZGCTrajectoryPoint &point : points) {
        QJsonObject pointObject;
        pointObject.insert(QLatin1String(kKeyLat), point.lat);
        pointObject.insert(QLatin1String(kKeyLon), point.lon);
        pointObject.insert(QLatin1String(kKeyAmslAlt), point.amslAlt);
        pointObject.insert(QLatin1String(kKeyTMs), point.tMs);
        pointObject.insert(QLatin1String(kKeyGap), point.gap);
        pointsArray.append(pointObject);
    }

    QJsonObject root;
    root.insert(QLatin1String(kKeyVersion), ZGCTrajectory::kFormatVersion);
    root.insert(QLatin1String(kKeyName), entry.name);
    root.insert(QLatin1String(kKeyCreated), created.toString(Qt::ISODateWithMs));
    root.insert(QLatin1String(kKeyHome), homeObject);
    root.insert(QLatin1String(kKeyVehicle), vehicleObject);
    root.insert(QLatin1String(kKeyStats), statsObject);
    root.insert(QLatin1String(kKeyPoints), pointsArray);

    //---- 原子写：QSaveFile 临时文件 + commit 原子 rename；目录不存在自动创建 ----//

    if (!QDir().mkpath(directory)) {
        const QString message = QStringLiteral("trajectory save create directory failed: %1").arg(directory);
        qCWarning(ZGCTrajectoryLog) << message;
        emit errorOccurred(message);
        return QString();
    }

    const QString filePath = _uniqueFilePath(entry.name);
    QSaveFile file(filePath);
    if (!file.open(QIODevice::WriteOnly)) {
        const QString message = QStringLiteral("trajectory save open failed: %1").arg(file.errorString());
        qCWarning(ZGCTrajectoryLog) << message;
        emit errorOccurred(message);
        return QString();
    }
    const QByteArray json = QJsonDocument(root).toJson(QJsonDocument::Indented);
    if (file.write(json) != json.size()) {
        const QString message = QStringLiteral("trajectory save write failed: %1").arg(file.errorString());
        qCWarning(ZGCTrajectoryLog) << message;
        emit errorOccurred(message);
        return QString();
    }
    if (!file.commit()) {
        const QString message = QStringLiteral("trajectory save commit failed: %1").arg(file.errorString());
        qCWarning(ZGCTrajectoryLog) << message;
        emit errorOccurred(message);
        return QString();
    }

    entry.fileName = QFileInfo(filePath).fileName();
    _insertEntry(entry);
    qCInfo(ZGCTrajectoryLog) << "trajectory saved"
                             << "fileName:" << entry.fileName
                             << "pointCount:" << entry.pointCount
                             << "distance(m):" << entry.distance;
    return entry.fileName;
}

bool ZGCTrajectoryLibrary::deleteTrajectory(const QString &fileName)
{
    const QString directory = _directory();
    if (directory.isEmpty()) {
        return false;
    }

    // 仅取 basename，防路径穿越。
    const QString safeName = QFileInfo(fileName).fileName();
    const QString filePath = QDir(directory).filePath(safeName);

    int row = -1;
    for (int i = 0; i < _entries.size(); ++i) {
        if (_entries[i].fileName == safeName) {
            row = i;
            break;
        }
    }

    if (!QFile::exists(filePath)) {
        if (row != -1) {
            // 列表与磁盘不一致（文件被外部删除）：同步列表。
            beginRemoveRows(QModelIndex(), row, row);
            _entries.removeAt(row);
            endRemoveRows();
            emit countChanged();
        }
        return false;
    }

    if (!QFile::remove(filePath)) {
        const QString message = QStringLiteral("trajectory delete remove failed: %1").arg(safeName);
        qCWarning(ZGCTrajectoryLog) << message;
        emit errorOccurred(message);
        return false;
    }

    if (row != -1) {
        beginRemoveRows(QModelIndex(), row, row);
        _entries.removeAt(row);
        endRemoveRows();
        emit countChanged();
    }
    qCInfo(ZGCTrajectoryLog) << "trajectory deleted:" << safeName;
    return true;
}

QVariantMap ZGCTrajectoryLibrary::loadTrajectory(const QString &fileName) const
{
    const QString directory = _directory();
    const QString safeName = QFileInfo(fileName).fileName();
    const QString filePath = directory.isEmpty() ? QString() : QDir(directory).filePath(safeName);

    QVariantMap result;
    result.insert(QLatin1String("fileName"), safeName);

    QJsonObject root;
    QString error;
    if (filePath.isEmpty() || !readJsonRoot(filePath, root, error)) {
        result.insert(QLatin1String("corrupted"), true);
        result.insert(QLatin1String("error"), error);
        return result;
    }

    double version = 0.0;
    if (!jsonDouble(root, kKeyVersion, version) || qRound(version) != ZGCTrajectory::kFormatVersion) {
        result.insert(QLatin1String("corrupted"), true);
        result.insert(QLatin1String("error"),
                      QStringLiteral("unsupported format version: %1").arg(version));
        return result;
    }

    QJsonObject homeObject;
    QJsonObject statsObject;
    if (!jsonObject(root, kKeyHome, homeObject) || !jsonObject(root, kKeyStats, statsObject)) {
        result.insert(QLatin1String("corrupted"), true);
        result.insert(QLatin1String("error"), QStringLiteral("missing home or stats object"));
        return result;
    }

    double lat = 0.0;
    double lon = 0.0;
    double amslAlt = 0.0;
    if (!jsonDouble(homeObject, kKeyLat, lat)
        || !jsonDouble(homeObject, kKeyLon, lon)
        || !jsonDouble(homeObject, kKeyAmslAlt, amslAlt)) {
        result.insert(QLatin1String("corrupted"), true);
        result.insert(QLatin1String("error"), QStringLiteral("invalid home object"));
        return result;
    }

    const QJsonArray pointsArray = root.value(QLatin1String(kKeyPoints)).toArray();
    QList<ZGCTrajectoryPoint> points;
    if (!parsePointsArray(pointsArray, points) || points.isEmpty()) {
        result.insert(QLatin1String("corrupted"), true);
        result.insert(QLatin1String("error"), QStringLiteral("invalid points array"));
        return result;
    }

    result.insert(QLatin1String(kKeyVersion), qRound(version));
    result.insert(QLatin1String(kKeyName), root.value(QLatin1String(kKeyName)).toString(safeName));
    result.insert(QLatin1String(kKeyCreated),
                  QDateTime::fromString(root.value(QLatin1String(kKeyCreated)).toString(), Qt::ISODateWithMs));

    QVariantMap homeMap;
    homeMap.insert(QLatin1String(kKeyLat), lat);
    homeMap.insert(QLatin1String(kKeyLon), lon);
    homeMap.insert(QLatin1String(kKeyAmslAlt), amslAlt);
    result.insert(QLatin1String(kKeyHome), homeMap);

    result.insert(QLatin1String(kKeyVehicle), root.value(QLatin1String(kKeyVehicle)).toObject().toVariantMap());
    result.insert(QLatin1String(kKeyStats), statsObject.toVariantMap());
    result.insert(QLatin1String(kKeyPoints), pointsToVariants(points));
    result.insert(QLatin1String("corrupted"), false);
    return result;
}

void ZGCTrajectoryLibrary::refresh()
{
    beginResetModel();
    _scanDirectory();
    endResetModel();
    emit countChanged();
}

QString ZGCTrajectoryLibrary::_directory() const
{
    const SettingsManager *const settingsManager = SettingsManager::instance();
    if (!settingsManager || !settingsManager->appSettings()) {
        return QString();
    }
    const QString rootPath = settingsManager->appSettings()->savePath()->rawValue().toString();
    if (rootPath.isEmpty()) {
        return QString();
    }
    return QDir(rootPath).filePath(QStringLiteral("ZGCTrajectories"));
}

void ZGCTrajectoryLibrary::_scanDirectory()
{
    _entries.clear();

    const QString directory = _directory();
    if (directory.isEmpty()) {
        qCWarning(ZGCTrajectoryLog) << "scan: save path not configured, trajectory library empty";
        return;
    }
    const QDir dir(directory);
    if (!dir.exists()) {
        // 扫描不创建目录（避免未用功能时污染 savePath）；保存时才自动创建。
        return;
    }

    const QFileInfoList files = dir.entryInfoList(
        QStringList() << QStringLiteral("*.") + QLatin1String(ZGCTrajectory::kFileExtension),
        QDir::Files, QDir::Name);
    for (const QFileInfo &fileInfo : files) {
        _entries.append(_loadEntryFromFile(fileInfo.absoluteFilePath()));
    }

    // corrupted 靠后，created 新的在前。
    std::sort(_entries.begin(), _entries.end(), [](const Entry &a, const Entry &b) {
        if (a.corrupted != b.corrupted) {
            return !a.corrupted;
        }
        return a.created > b.created;
    });

    qCDebug(ZGCTrajectoryLog) << "scan: trajectories found:" << _entries.size();
}

void ZGCTrajectoryLibrary::_insertEntry(const Entry &entry)
{
    int row = 0;
    while (row < _entries.size()) {
        const Entry &existing = _entries[row];
        const bool existingFirst = (existing.corrupted != entry.corrupted)
                                       ? !existing.corrupted
                                       : existing.created > entry.created;
        if (!existingFirst) {
            break;
        }
        ++row;
    }
    beginInsertRows(QModelIndex(), row, row);
    _entries.insert(row, entry);
    endInsertRows();
    emit countChanged();
}

QString ZGCTrajectoryLibrary::_uniqueFilePath(const QString &baseName) const
{
    const QDir directory(_directory());
    const QString extension = QLatin1String(ZGCTrajectory::kFileExtension);

    QString candidate = directory.filePath(baseName + QStringLiteral(".") + extension);
    int suffix = 2;
    while (QFileInfo::exists(candidate)) {
        // 同名自动加序号：name.zgctraj → name-2.zgctraj → ...
        candidate = directory.filePath(QStringLiteral("%1-%2.%3").arg(baseName).arg(suffix).arg(extension));
        ++suffix;
    }
    return candidate;
}

ZGCTrajectoryLibrary::Entry ZGCTrajectoryLibrary::_loadEntryFromFile(const QString &filePath) const
{
    Entry entry;
    const QFileInfo fileInfo(filePath);
    entry.fileName = fileInfo.fileName();
    entry.name = fileInfo.completeBaseName();

    QJsonObject root;
    QString error;
    if (!readJsonRoot(filePath, root, error)) {
        entry.corrupted = true;
        qCWarning(ZGCTrajectoryLog) << "corrupted trajectory file (unreadable):" << entry.fileName << error;
        return entry;
    }

    double version = 0.0;
    if (!jsonDouble(root, kKeyVersion, version)) {
        entry.corrupted = true;
        qCWarning(ZGCTrajectoryLog) << "corrupted trajectory file (no version):" << entry.fileName;
        return entry;
    }
    entry.version = qRound(version);
    if (entry.version != ZGCTrajectory::kFormatVersion) {
        // 版本不识别：标记可见不静默丢弃；名字等尽力而为字段不再强校验。
        entry.corrupted = true;
        qCWarning(ZGCTrajectoryLog) << "trajectory file version not supported, marked corrupted"
                                    << "fileName:" << entry.fileName
                                    << "version:" << entry.version;
        return entry;
    }

    QJsonObject homeObject;
    QJsonObject statsObject;
    double lat = 0.0;
    double lon = 0.0;
    double amslAlt = 0.0;
    if (!jsonObject(root, kKeyHome, homeObject)
        || !jsonDouble(homeObject, kKeyLat, lat)
        || !jsonDouble(homeObject, kKeyLon, lon)
        || !jsonDouble(homeObject, kKeyAmslAlt, amslAlt)
        || !jsonObject(root, kKeyStats, statsObject)
        || !jsonDouble(statsObject, kKeyDistance, entry.distance)
        || !jsonDouble(statsObject, kKeyDurationS, entry.durationS)
        || !jsonDouble(statsObject, kKeyMaxRelAlt, entry.maxRelAlt)
        || !jsonBool(statsObject, kKeyDegraded, entry.degraded)) {
        entry.corrupted = true;
        qCWarning(ZGCTrajectoryLog) << "corrupted trajectory file (bad header/stats):" << entry.fileName;
        return entry;
    }

    const QJsonArray pointsArray = root.value(QLatin1String(kKeyPoints)).toArray();
    QList<ZGCTrajectoryPoint> points;
    if (!parsePointsArray(pointsArray, points) || points.isEmpty()) {
        entry.corrupted = true;
        qCWarning(ZGCTrajectoryLog) << "corrupted trajectory file (bad points):" << entry.fileName;
        return entry;
    }

    entry.pointCount = points.size();
    entry.created = QDateTime::fromString(root.value(QLatin1String(kKeyCreated)).toString(), Qt::ISODateWithMs);
    if (entry.name.isEmpty()) {
        entry.name = entry.fileName;
    }
    return entry;
}
