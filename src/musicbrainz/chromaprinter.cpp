#include "musicbrainz/chromaprinter.h"

#include <chromaprint.h>

#include <QtDebug>
#include <limits>
#include <vector>

#include "moc_chromaprinter.cpp"
#include "sources/audiosourcestereoproxy.h"
#include "sources/soundsourceproxy.h"
#include "track/track.h"
#include "util/performancetimer.h"
#include "util/sample.h"

namespace
{

// Type declarations of *fprint and *encoded pointers need to account for Chromaprint API version
// (void* -> uint32_t*) and (void* -> char*) changed in versions v1.4.0 or later -- alyptik 12/2016
#if (CHROMAPRINT_VERSION_MINOR > 3) || (CHROMAPRINT_VERSION_MAJOR > 1)
    typedef uint32_t* uint32_p;
    typedef char* char_p;
#else
    typedef void* uint32_p;
    typedef void* char_p;
#endif

// this is worth 2min of audio
// AcoustID only stores a fingerprint for the first two minutes of a song
// on their server so we need only a fingerprint of the first two minutes
// --kain88 July 2012
    constexpr SINT kFingerprintDuration = 120; // in seconds

QString calcFingerprint(
        mixxx::AudioSourceStereoProxy& audioSourceProxy,
        mixxx::IndexRange fingerprintRange) {
    PerformanceTimer timerReadingFile;
    timerReadingFile.start();

    mixxx::SampleBuffer sampleBuffer(math_max(
            fingerprintRange.length(),
            audioSourceProxy.getSignalInfo().frames2samples(fingerprintRange.length())));
    const auto readableSampleFrames =
            audioSourceProxy.readSampleFrames(
                    mixxx::WritableSampleFrames(
                            fingerprintRange,
                            mixxx::SampleBuffer::WritableSlice(sampleBuffer)));
    if (fingerprintRange != readableSampleFrames.frameIndexRange()) {
        qWarning() << "Failed to read sample data for fingerprint";
        return QString();
    }

    std::vector<SAMPLE> fingerprintSamples(
            audioSourceProxy.getSignalInfo().frames2samples(
                    readableSampleFrames.frameLength()));
    if (fingerprintSamples.empty() ||
            fingerprintSamples.size() > static_cast<std::size_t>(
                                               std::numeric_limits<int>::max())) {
        qWarning() << "Audio sample data is empty or too large for fingerprinting";
        return QString();
    }

    // Convert floating-point to integer
    SampleUtil::convertFloat32ToS16(
            fingerprintSamples.data(),
            sampleBuffer.data(),
            static_cast<SINT>(fingerprintSamples.size()));

    qDebug() << "reading file took" << timerReadingFile.elapsed().debugMillisWithUnit();

    ChromaprintContext* ctx = chromaprint_new(CHROMAPRINT_ALGORITHM_DEFAULT);
    if (!ctx) {
        qWarning() << "Failed to allocate Chromaprint context";
        return QString();
    }
    if (!chromaprint_start(
            ctx,
            audioSourceProxy.getSignalInfo().getSampleRate(),
            audioSourceProxy.getSignalInfo().getChannelCount())) {
        qWarning() << "Failed to start Chromaprint context";
        chromaprint_free(ctx);
        return QString();
    }

    PerformanceTimer timerGeneratingFingerprint;
    timerGeneratingFingerprint.start();
    const int success = chromaprint_feed(
            ctx,
            fingerprintSamples.data(),
            static_cast<int>(fingerprintSamples.size()));
    if (!success || !chromaprint_finish(ctx)) {
        qWarning() << "Failed to generate fingerprint from sample data";
        chromaprint_free(ctx);
        return QString();
    }

    uint32_p fprint = nullptr;
    int size = 0;
    int ret = chromaprint_get_raw_fingerprint(ctx, &fprint, &size);
    QByteArray fingerprint;
    char_p encoded = nullptr;
    if (ret == 1 && fprint && size > 0) {
        int encoded_size = 0;
        if (chromaprint_encode_fingerprint(fprint, size,
                    CHROMAPRINT_ALGORITHM_DEFAULT,
                    &encoded,
                    &encoded_size, 1) && encoded && encoded_size > 0) {
            fingerprint.append(reinterpret_cast<char*>(encoded), encoded_size);
        }
    } else {
        qWarning() << "Failed to retrieve raw audio fingerprint";
    }
    if (fprint) {
        chromaprint_dealloc(fprint);
    }
    if (encoded) {
        chromaprint_dealloc(encoded);
    }
    chromaprint_free(ctx);

    qDebug() << "generating fingerprint took"
             << timerGeneratingFingerprint.elapsed().debugMillisWithUnit();

    return fingerprint;
}

} // anonymous namespace

ChromaPrinter::ChromaPrinter(QObject* parent)
             : QObject(parent) {
}

QString ChromaPrinter::getFingerprint(TrackPointer pTrack) {
    if (!pTrack) {
        qWarning() << "Cannot fingerprint an invalid track";
        return QString();
    }
    mixxx::AudioSource::OpenParams config;
    // always stereo / 2 channels (see below)
    config.setChannelCount(mixxx::audio::ChannelCount(2));
    auto pAudioSource = SoundSourceProxy(pTrack).openAudioSource(config);
    if (!pAudioSource) {
        qDebug()
                << "Failed to open file for fingerprinting"
                << pTrack->getLocation();
        return QString();
    }

    const auto fingerprintRange = intersect(
            pAudioSource->frameIndexRange(),
            mixxx::IndexRange::forward(
                    pAudioSource->frameIndexMin(),
                    kFingerprintDuration * pAudioSource->getSignalInfo().getSampleRate()));
    mixxx::AudioSourceStereoProxy audioSourceProxy(
            pAudioSource,
            fingerprintRange.length());

    return calcFingerprint(audioSourceProxy, fingerprintRange);
}
