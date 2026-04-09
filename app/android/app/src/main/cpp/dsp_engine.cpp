#include <jni.h>
#include <vector>
#include <cmath>
#include <algorithm>

// Simple DSP processing state
static std::vector<float> g_eqState(512, 0.0f);
static int g_sampleRate = 48000;
static bool g_initialized = false;

// Basic PEQ (Parametric EQ) filter implementation
struct BiquadFilter {
    float b0, b1, b2, a1, a2;
    float z1, z2;

    BiquadFilter() : b0(1), b1(0), b2(0), a1(0), a2(0), z1(0), z2(0) {}

    float process(float sample) {
        float out = sample * b0 + z1;
        z1 = sample * b1 + z2 - a1 * out;
        z2 = sample * b2 - a2 * out;
        return out;
    }
};

static BiquadFilter g_eqFilters[5];

extern "C" {

extern "C" JNIEXPORT jstring JNICALL
Java_com_neuroamp_app_MainActivity_nativeDspVersion(JNIEnv* env, jobject /* this */) {
    return env->NewStringUTF("NeuroAmpDSP-1.0.0-JNI");
}

JNIEXPORT jboolean JNICALL
Java_com_neuroamp_app_dsp_DspProcessor_initializeDspEngine(JNIEnv* env, jclass clazz, jint sampleRate) {
    g_sampleRate = sampleRate;
    g_eqState.assign(512, 0.0f);
    g_initialized = true;
    return JNI_TRUE;
}

JNIEXPORT jboolean JNICALL
Java_com_neuroamp_app_dsp_DspProcessor_releaseDspEngine(JNIEnv* env, jclass clazz) {
    g_initialized = false;
    g_eqState.clear();
    return JNI_TRUE;
}

JNIEXPORT jboolean JNICALL
Java_com_neuroamp_app_dsp_DspProcessor_processAudioFrame(
    JNIEnv* env, jclass clazz, jfloatArray inputSamples, jfloatArray outputSamples, jbyteArray config) {
    
    if (!g_initialized) {
        return JNI_FALSE;
    }

    jint inputLen = env->GetArrayLength(inputSamples);
    jfloat* input = env->GetFloatArrayElements(inputSamples, nullptr);
    jfloat* output = env->GetFloatArrayElements(outputSamples, nullptr);

    // Parse config (simplified)
    jbyte* configBytes = env->GetByteArrayElements(config, nullptr);
    jint configLen = env->GetArrayLength(config);

    bool convolverEnabled = configLen > 1 && configBytes[1] != 0;
    float bassBoostDb = 0.0f;
    float spatialWidth = 0.25f;
    float peakLimiter = -1.0f;

    if (configLen > 5) {
        // Parse floating point values from config (simplified)
        // In production, use proper serialization library
    }

    // Simple processing: apply peak limiter
    float limiterThreshold = std::pow(10.0f, peakLimiter / 20.0f);

    for (int i = 0; i < inputLen; i++) {
        float sample = input[i];

        // Peak limiting
        if (sample > limiterThreshold) {
            sample = limiterThreshold;
        } else if (sample < -limiterThreshold) {
            sample = -limiterThreshold;
        }

        output[i] = sample;
    }

    env->ReleaseFloatArrayElements(inputSamples, input, JNI_ABORT);
    env->ReleaseFloatArrayElements(outputSamples, output, 0);
    env->ReleaseByteArrayElements(config, configBytes, JNI_ABORT);

    return JNI_TRUE;
}

} // extern "C"
