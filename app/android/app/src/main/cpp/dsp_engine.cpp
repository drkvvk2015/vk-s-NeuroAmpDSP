#include <jni.h>

extern "C" JNIEXPORT jstring JNICALL
Java_com_neuroamp_app_MainActivity_nativeDspVersion(JNIEnv* env, jobject /* this */) {
    return env->NewStringUTF("NeuroAmpDSP-0.1.0");
}
