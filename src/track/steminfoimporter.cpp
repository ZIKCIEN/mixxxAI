#include "track/steminfoimporter.h"

#include <QDataStream>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMimeDatabase>
#include <QString>
#include <QtEndian>
#include <QtGlobal>
#include <limits>

#include "util/logger.h"

namespace mixxx {

namespace {

const mixxx::Logger kLogger("StemInfoImporter");
constexpr int kSupportedStemVersion = 1;
const QStringList kStemMimes = {"audio/mp4", "audio/m4a", "audio/x-m4a", "video/mp4"};
// STEM file are usually detected by probing the specific stem atom contained in
// file, in case the file's MIME is one of the above. In case the MIME detection
// fails, we fallback to match the filename extension with "preferred" file
// extensions
const QStringList kStemPreferredFileExtensions = {".stem.mp4", ".stem.m4a"};
const QColor kStemDefaultColor[] = {
        QColor(0x00, 0x9E, 0x73),
        QColor(0xD5, 0x5E, 0x00),
        QColor(0xCC, 0x79, 0xA7),
        QColor(0x56, 0xB4, 0xE9),
};

struct MP4BoxHeader {
    quint32 size;
    char type[4];
};

constexpr uint32_t kAtomHeaderSize = sizeof(MP4BoxHeader);

bool readExact(QIODevice* reader, char* data, qint64 size) {
    qint64 bytesRead = 0;
    while (bytesRead < size) {
        const qint64 result = reader->read(data + bytesRead, size - bytesRead);
        if (result <= 0) {
            return false;
        }
        bytesRead += result;
    }
    return true;
}

bool readBoxHeader(QIODevice* reader, MP4BoxHeader* box, quint64* payloadSize,
        quint64 remainingSize) {
    quint32 size = 0;
    if (!readExact(reader, reinterpret_cast<char*>(&size), sizeof(size)) ||
            !readExact(reader, box->type, sizeof(box->type))) {
        return false;
    }
    size = qFromBigEndian(size);
    quint64 headerSize = kAtomHeaderSize;
    quint64 totalSize = size;
    if (size == 1) {
        if (remainingSize < kAtomHeaderSize + sizeof(quint64)) {
            return false;
        }
        quint64 extendedSize = 0;
        if (!readExact(reader, reinterpret_cast<char*>(&extendedSize), sizeof(extendedSize))) {
            return false;
        }
        totalSize = qFromBigEndian(extendedSize);
        headerSize += sizeof(extendedSize);
    } else if (size == 0) {
        totalSize = remainingSize;
    }
    if (totalSize < headerSize || totalSize > remainingSize) {
        return false;
    }
    *payloadSize = totalSize - headerSize;
    return true;
}

const QStringList kStemManifestAtomPath = {
        "moov",
        "udta",
        "stem",
};

/// @brief Seek the reader the atom requested.
/// @param reader The IODevice to search MP4 atom in
/// @param path The list of atom to traverse in the tree, from top to bottom.
/// Must be null terminated
/// @param boxSize The size of the box currently under the cursor to focus the
/// search in
/// @param pathIdx The level of the tree currently search (index of path)
/// @return the size of the box data if found, -1 otherwise
qint64 seekTillAtom(QIODevice* reader,
        const QStringList& path,
        qint64 boxSize = -1,
        qsizetype pathIdx = 0) {
    if (pathIdx == path.size()) {
        return static_cast<qint64>(boxSize);
    }
    if (boxSize < 0) {
        const qint64 fileSize = reader->size();
        const qint64 position = reader->pos();
        if (fileSize < 0 || position < 0 || position > fileSize) {
            return -1;
        }
        boxSize = fileSize - position;
    }
    quint64 remainingSize = static_cast<quint64>(boxSize);
    while (remainingSize >= kAtomHeaderSize) {
        MP4BoxHeader box{};
        quint64 payloadSize = 0;
        const qint64 headerStart = reader->pos();
        if (headerStart < 0 || !readBoxHeader(reader, &box, &payloadSize, remainingSize)) {
            return -1;
        }
        const quint64 headerSize = static_cast<quint64>(reader->pos() - headerStart);
        remainingSize -= headerSize + payloadSize;
        if (QString::fromUtf8(box.type, sizeof(box.type)) == path[pathIdx]) {
            return seekTillAtom(reader, path, payloadSize, pathIdx + 1);
        }
        if (payloadSize > static_cast<quint64>(std::numeric_limits<qint64>::max()) ||
                reader->skip(static_cast<qint64>(payloadSize)) !=
                        static_cast<qint64>(payloadSize)) {
            return -1;
        }
    }
    return -1;
}

} // anonymous namespace

// static
bool StemInfoImporter::hasStemAtom(const QString& filePath) {
    auto file = QFile(filePath);
    if (!file.open(QIODeviceBase::ReadOnly | QIODeviceBase::Unbuffered)) {
        kLogger.warning()
                << "Failed to open input file"
                << filePath;
        return false;
    }
    return seekTillAtom(&file, kStemManifestAtomPath) > 0;
}

// static
bool StemInfoImporter::maybeStemFile(
        const QString& fileName, QMimeType mimeType) {
    if (!mimeType.isValid() || mimeType.isDefault()) {
        // If no MIME type was previously detected for the file content, we read it now.
        mimeType = QMimeDatabase().mimeTypeForFile(
                fileName, QMimeDatabase::MatchContent);
    }
    if (!mimeType.isValid() || mimeType.isDefault()) {
        kLogger.debug() << "Unable to detect MIME type from content in file" << fileName;
        for (const QString& ext : kStemPreferredFileExtensions) {
            if (fileName.endsWith(ext)) {
                return true;
            }
        }
    }
    return kStemMimes.contains(mimeType.name());
}

QList<StemInfo> StemInfoImporter::importStemInfos(
        const QString& filePath) {
    // Fetch the STEM manifest which contain stream details
    auto file = QFile(filePath);
    if (!file.open(QIODeviceBase::ReadOnly | QIODeviceBase::Unbuffered)) {
        kLogger.warning()
                << "Failed to open input file"
                << filePath;
        return {};
    }

    const qint64 manifestSize = seekTillAtom(&file, kStemManifestAtomPath);
    constexpr qint64 kMaxManifestSize = 1024 * 1024;
    if (manifestSize <= 0 || manifestSize > kMaxManifestSize) {
        kLogger.debug()
                << "No stem manifest found in the file"
                << filePath;
        return {};
    }

    QByteArray manifest = file.read(manifestSize);
    if (manifest.size() != manifestSize) {
        kLogger.warning() << "Incomplete stem manifest in file" << filePath;
        return {};
    }
    // Though most MP4 atoms are usually not null-terminated, it looks like the
    // STEM sometime is, resulting in extra null character(s) preventing JSON
    // deserialization
    while (manifest.endsWith('\0')) {
        manifest.chop(1);
    }
    auto jsonData = QJsonDocument::fromJson(manifest);
    VERIFY_OR_DEBUG_ASSERT(jsonData.isObject()) {
        kLogger.warning()
                << "Failed to extract the manifest data"
                << filePath;
        return {};
    };

    auto json = jsonData.object();

    // Check the manifest version
    auto version = json.value("version").toInteger(-1);
    if (version <= 0) {
        kLogger.debug() << "Unexpected or missing version value in STEM manifest";
        return {};
    } else if (version > kSupportedStemVersion) {
        kLogger.warning() << "Unsupported stem version" << version << "but trying anyway";
    }

    // Extract stem metadata
    auto stems = json.value("stems");
    if (!stems.isArray()) {
        kLogger.debug() << "Unexpected or missing stems value in STEM manifest";
        return {};
    }
    const auto stemArray = stems.toArray();
    constexpr qsizetype kMaxStemCount = 4;
    if (stemArray.size() > kMaxStemCount) {
        kLogger.warning() << "Too many stems in STEM manifest" << filePath;
        return {};
    }
    QList<StemInfo> stemsList;
    stemsList.reserve(stemArray.size());
    int stemIdx = 0;
    for (const auto& stemRef : stemArray) {
        if (!stemRef.isObject()) {
            kLogger.debug() << "Unexpected or missing stems value in STEM manifest";
            return {};
        }
        auto stem = stemRef.toObject();
        auto color = QColor(stem.value("color").toString());
        auto name = stem.value("name").toString();
        if (!color.isValid()) {
            kLogger.debug() << "Unexpected or missing stem color in STEM manifest. Using default";
            color = kStemDefaultColor[stemIdx];
        }
        if (name.isEmpty()) {
            kLogger.debug() << "Unexpected or missing stem name in STEM manifest. Using default";
            name = QObject::tr("Stem #%1").arg(QString::number(stemIdx + 1));
        }
        stemsList.emplace_back(name, color);
        stemIdx++;
    }

    // Extract DSP information
    // TODO(XXX) DSP only contains a limiter and a compressor effect, which
    // Mixxx doesn't have yet. Parse and implement when supported
    auto masteringDsp = json.value("mastering_dsp").toObject();
    auto compressor = masteringDsp.value("compressor").toObject();
    auto limiter = masteringDsp.value("limiter").toObject();

    if (compressor.value("enabled").toBool() || limiter.value("enabled").toBool()) {
        kLogger.debug() << "The STEM manifest is requesting DSP effects but "
                           "this isn't supported by Mixxx yet.";
    }

    file.close();

    return stemsList;
}

} // namespace mixxx
