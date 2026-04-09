#include <jni.h>
#include <cmath>
#include <vector>
#include <algorithm>
#include <android/log.h>
#include <cstring>

#define TAG "NeuroAmpDSP"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)
#define M_PI 3.14159265358979323846f

const char* VERSION = "NeuroAmpDSP-1.0.1-RealDSP";

struct BiquadFilter {
    // Direct Form II (transposed)
    float b0, b1, b2, a1, a2;
    float z1 = 0, z2 = 0;

    BiquadFilter() : b0(1), b1(0), b2(0), a1(0), a2(0), z1(0), z2(0) {}

    float process(float x) {
        float out = b0 * x + z1;
        z1 = b1 * x - a1 * out + z2;
        z2 = b2 * x - a2 * out;
        return out;
    }

    void reset() {
        z1 = z2 = 0;
    }
};

struct LookaheadLimiter {
    std::vector<float> buffer;
    size_t pos = 0;
    float threshold = 1.0f;
    float attackMs = 0.5f;
    float releaseMs = 100.0f;
    float gain = 1.0f;
    float attack_samples = 24;
    float release_samples = 4800;
    int sampleRate = 48000;
    static const int LOOKAHEAD_SIZE = 2048;

    LookaheadLimiter() {
        buffer.resize(LOOKAHEAD_SIZE, 0);
    }

    void initialize(int sr) {
        sampleRate = sr;
        attack_samples = (attackMs * sr) / 1000.0f;
        release_samples = (releaseMs * sr) / 1000.0f;
        std::fill(buffer.begin(), buffer.end(), 0.0f);
        pos = 0;
        gain = 1.0f;
    }

    float process(float x) {
        buffer[pos] = x;
        
        // Find peak in lookahead window
        float peak = 0.0f;
        for (size_t i = 0; i < buffer.size(); ++i) {
            peak = std::max(peak, std::abs(buffer[i]));
        }

        // Compute gain reduction
        float targetGain = peak > threshold ? threshold / (peak + 1e-8f) : 1.0f;
        
        if (targetGain < gain) {
            gain += (targetGain - gain) / attack_samples;
        } else {
            gain += (targetGain - gain) / release_samples;
        }

        gain = std::max(0.0f, std::min(1.0f, gain));
        float output = buffer[pos] * gain;
        
        pos = (pos + 1) % buffer.size();
        return output;
    }
};

struct SpatialWidener {
    BiquadFilter midHpf, sideHpf;
    float width = 0.5f;

    void initialize() {
        // High-pass filter for spatial enhancement (~200Hz at 48kHz)
        midHpf.b0 = 0.9702f;
        midHpf.b1 = -1.9404f;
        midHpf.b2 = 0.9702f;
        midHpf.a1 = -1.9408f;
        midHpf.a2 = 0.9412f;

        sideHpf = midHpf;
    }

    float processMid(float x) {
        return midHpf.process(x);
    }

    float processSide(float x) {
        float side = sideHpf.process(x);
        return side * width;
    }
};

static int g_sampleRate = 48000;
static bool g_initialized = false;
static BiquadFilter g_eqFilters[5];
static LookaheadLimiter g_limiter;
static SpatialWidener g_widener;

void computeBiquadCoefficients(BiquadFilter& filter, float centerFreqHz, float gainDb, float Q, int sampleRate) {
    if (Q < 0.1f) Q = 0.1f;
    if (centerFreqHz < 20.0f) centerFreqHz = 20.0f;
    if (centerFreqHz > sampleRate * 0.45f) centerFreqHz = sampleRate * 0.45f;

    float A = std::pow(10.0f, gainDb / 40.0f);
    float w0 = 2.0f * M_PI * centerFreqHz / sampleRate;
    float sinW0 = std::sin(w0);
    float cosW0 = std::cos(w0);
    float alpha = sinW0 / (2.0f * Q);

    filter.b0 = A * ((A + 1) - (A - 1) * cosW0 + 2 * std::sqrt(A) * alpha);
    filter.b1 = 2 * A * ((A - 1) - (A + 1) * cosW0);
    filter.b2 = A * ((A + 1) - (A - 1) * cosW0 - 2 * std::sqrt(A) * alpha);
    filter.a1 = -2 * ((A - 1) + (A + 1) * cosW0);
    filter.a2 = (A + 1) + (A - 1) * cosW0 - 2 * std::sqrt(A) * alpha;

    float a0 = (A + 1) + (A - 1) * cosW0 + 2 * std::sqrt(A) * alpha;
    if (std::abs(a0) > 1e-8f) {
        filter.b0 /= a0;
        filter.b1 /= a0;
        filter.b2 /= a0;
        filter.a1 /= a0;
        filter.a2 /= a0;
    }
}

extern "C" {
    JNIEXPORT jstring JNICALL Java_com_neuroamp_app_MainActivity_nativeDspVersion(JNIEnv* env, jobject) {
        return env->NewStringUTF(VERSION);
    }

    JNIEXPORT jboolean JNICALL Java_com_neuroamp_app_dsp_DspProcessor_initializeDspEngine(
        JNIEnv* env, jobject, jint sampleRate) {
        
        g_sampleRate = sampleRate;
        g_initialized = true;

        // Initialize EQ filters (default flat response)
        float eqCenters[] = {60, 250, 1000, 4000, 12000};
        for (int i = 0; i < 5; ++i) {
            computeBiquadCoefficients(g_eqFilters[i], eqCenters[i], 0.0f, 1.0f, sampleRate);
        }

        g_limiter.initialize(sampleRate);
        g_widener.initialize();

        LOGI("DSP engine initialized at %d Hz with real processing", sampleRate);
        return JNI_TRUE;
    }

    JNIEXPORT jboolean JNICALL Java_com_neuroamp_app_dsp_DspProcessor_releaseDspEngine(
        JNIEnv* env, jobject) {
        
        g_initialized = false;
        for (int i = 0; i < 5; ++i) {
            g_eqFilters[i].reset();
        }
        LOGI("DSP engine released");
        return JNI_TRUE;
    }

    JNIEXPORT jboolean JNICALL Java_com_neuroamp_app_dsp_DspProcessor_processAudioFrame(
        JNIEnv* env, jobject, jfloatArray inputArray, jfloatArray outputArray, jbyteArray configArray) {
        
        if (!g_initialized) {
            return JNI_FALSE;
        }

        jsize frameCount = env->GetArrayLength(inputArray);
        jfloat* inputSamples = env->GetFloatArrayElements(inputArray, nullptr);
        jfloat* outputSamples = env->GetFloatArrayElements(outputArray, nullptr);

        jbyte* configBytes = env->GetByteArrayElements(configArray, nullptr);
        jsize configLen = env->GetArrayLength(configArray);

        // Parse config struct (must match DspProcessor.serializeConfig)
        bool convolverEnabled = false;
        float bassBoostDb = 0.0f;
        float spatialWidth = 0.25f;
        float peakLimiterDb = -1.0f;
        int numEqBands = 0;

        char* cfgPtr = (char*)configBytes;
        if (configLen > 0) {
            int version = cfgPtr[0];
            if (version == 1 && configLen >= 14) {
                convolverEnabled = (cfgPtr[1] != 0);
                memcpy(&bassBoostDb, cfgPtr + 2, sizeof(float));
                memcpy(&spatialWidth, cfgPtr + 6, sizeof(float));
                memcpy(&peakLimiterDb, cfgPtr + 10, sizeof(float));
                numEqBands = std::min((int)cfgPtr[14], 5);
            }
        }

        g_widener.width = std::max(0.0f, std::min(1.0f, spatialWidth));
        g_limiter.threshold = std::pow(10.0f, peakLimiterDb / 20.0f);

        // Update EQ gains from config
        float eqCenters[] = {60, 250, 1000, 4000, 12000};
        for (int i = 0; i < numEqBands && i < 5; ++i) {
            int offset = 15 + i * 12;
            if (offset + 12 <= configLen) {
                double freqHz;
                float gainDb, q;
                memcpy(&freqHz, cfgPtr + offset, sizeof(double));
                memcpy(&gainDb, cfgPtr + offset + 8, sizeof(float));
                memcpy(&q, cfgPtr + offset + 10, sizeof(float));
                computeBiquadCoefficients(g_eqFilters[i], (float)freqHz, gainDb, q, g_sampleRate);
            }
        }

        // DSP processing chain
        for (jsize i = 0; i < frameCount; ++i) {
            float sample = inputSamples[i];

            // Stage 1: EQ filtering (5-band parametric)
            for (int j = 0; j < 5; ++j) {
                sample = g_eqFilters[j].process(sample);
            }

            // Stage 2: Bass boost (shelving filter approximation via gain)
            if (bassBoostDb > 0.01f) {
                float boost = std::pow(10.0f, bassBoostDb / 20.0f);
                sample *= boost;
            }

            // Stage 3: Spatial widening (M/S stereo simulation on mono)
            sample = g_widener.processMid(sample);
            sample += g_widener.processSide(sample);
            sample *= 0.5f; // Normalize post-widening

            // Stage 4: Lookahead limiting
            sample = g_limiter.process(sample);

            // Soft clipping for safety (tanh saturation)
            if (std::abs(sample) > 1.0f) {
                sample = std::tanh(sample);
            }

            outputSamples[i] = sample;
        }

        env->ReleaseFloatArrayElements(inputArray, inputSamples, JNI_ABORT);
        env->ReleaseFloatArrayElements(outputArray, outputSamples, 0);
        env->ReleaseByteArrayElements(configArray, configBytes, JNI_ABORT);

        return JNI_TRUE;
    }
}
