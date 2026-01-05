#include <jni.h>
#include <android/log.h>
#include "HelpBot.h"

#define LOG_TAG "HelpBotCocos2dDemo"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)

extern "C" {

JNIEXPORT jstring JNICALL
Java_com_helpbot_cocos2d_demo_AppActivity_getSDKVersion(JNIEnv* env, jobject /* this */) {
    std::string version = helpbot::HelpBot::getSDKVersion();
    LOGD("HelpBot SDK Version: %s", version.c_str());
    return env->NewStringUTF(version.c_str());
}

JNIEXPORT jboolean JNICALL
Java_com_helpbot_cocos2d_demo_AppActivity_isSDKInitialized(JNIEnv* env, jobject /* this */) {
    bool initialized = helpbot::HelpBot::isInitialized();
    LOGD("HelpBot SDK Initialized: %d", initialized);
    return initialized ? JNI_TRUE : JNI_FALSE;
}

} // extern "C"
