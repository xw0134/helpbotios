#include "HelpBotJNI.h"
#include "../../include/HBLogger.h"
#include <cstring>
#include <string>

namespace helpbot {
namespace platform {
namespace android {

// 静态成员初始化
JavaVM* JNIHelper::s_javaVM = nullptr;
std::mutex JNIHelper::s_mutex;

jobject JNIHelper::s_classLoader = nullptr;
jmethodID JNIHelper::s_loadClassMethod = nullptr;

// ==================== JNIHelper 实现 ====================

void JNIHelper::init(JavaVM* vm) {
    std::lock_guard<std::mutex> lock(s_mutex);
    s_javaVM = vm;
    HBLogger::i("JNIHelper", "JNI 环境初始化完成");
}

JNIEnv* JNIHelper::getEnv() {
    return getEnv(nullptr);
}

JNIEnv* JNIHelper::getEnv(bool* didAttach) {
    if (didAttach) {
        *didAttach = false;
    }
    if (!s_javaVM) {
        HBLogger::e("JNIHelper", "JavaVM 未初始化");
        return nullptr;
    }

    JNIEnv* env = nullptr;
    const int status = s_javaVM->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
    if (status == JNI_OK) {
        return env;
    }

    if (status == JNI_EDETACHED) {
        // 当前线程未 attach,需要 attach
        int attachStatus = s_javaVM->AttachCurrentThread(&env, nullptr);
        if (attachStatus != JNI_OK) {
            HBLogger::e("JNIHelper", "AttachCurrentThread 失败");
            return nullptr;
        }
        if (didAttach) {
            *didAttach = true;
        }
        return env;
    }

    HBLogger::e("JNIHelper", "GetEnv 失败");
    return nullptr;
}

void JNIHelper::detachCurrentThreadIfNeeded(bool didAttach) {
    if (!didAttach) {
        return;
    }
    if (!s_javaVM) {
        return;
    }
    s_javaVM->DetachCurrentThread();
}

JavaVM* JNIHelper::getJavaVM() {
    return s_javaVM;
}

void JNIHelper::initClassLoader(JNIEnv* env, jobject classLoader) {
    if (!env || !classLoader) {
        HBLogger::w("JNIHelper", "initClassLoader: 参数为空");
        return;
    }
    std::lock_guard<std::mutex> lock(s_mutex);

    try {
        if (s_classLoader) {
            env->DeleteGlobalRef(s_classLoader);
            s_classLoader = nullptr;
        }

        s_classLoader = env->NewGlobalRef(classLoader);
        jclass classLoaderCls = env->FindClass("java/lang/ClassLoader");
        s_loadClassMethod = env->GetMethodID(classLoaderCls, "loadClass", "(Ljava/lang/String;)Ljava/lang/Class;");
        checkAndClearException(env);
        HBLogger::i("JNIHelper", "initClassLoader: 已缓存 App ClassLoader");
    } catch (...) {
        HBLogger::e("JNIHelper", "initClassLoader 异常");
        checkAndClearException(env);
    }
}

jclass JNIHelper::findClass(JNIEnv* env, const char* className) {
    if (!env || !className) {
        return nullptr;
    }

    // 优先使用 App ClassLoader
    if (s_classLoader && s_loadClassMethod) {
        try {
            std::string name(className);
            // 兼容 "com/example/A" 与 "com.example.A"
            for (size_t i = 0; i < name.size(); i++) {
                if (name[i] == '/') {
                    name[i] = '.';
                }
            }

            jstring jname = env->NewStringUTF(name.c_str());
            jobject clazzObj = env->CallObjectMethod(s_classLoader, s_loadClassMethod, jname);
            env->DeleteLocalRef(jname);
            if (checkAndClearException(env) || !clazzObj) {
                // fallback
            } else {
                return static_cast<jclass>(clazzObj); // local ref
            }
        } catch (...) {
            HBLogger::e("JNIHelper", "findClass(ClassLoader) 异常");
            checkAndClearException(env);
        }
    }

    // fallback：JNI FindClass 需要 slash name
    std::string slashName(className);
    for (size_t i = 0; i < slashName.size(); i++) {
        if (slashName[i] == '.') {
            slashName[i] = '/';
        }
    }
    return env->FindClass(slashName.c_str());
}

std::string JNIHelper::jstringToString(JNIEnv* env, jstring jstr) {
    if (!env || !jstr) {
        return "";
    }

    const char* chars = env->GetStringUTFChars(jstr, nullptr);
    if (!chars) {
        return "";
    }

    std::string result(chars);
    env->ReleaseStringUTFChars(jstr, chars);
    return result;
}

jstring JNIHelper::stringToJstring(JNIEnv* env, const std::string& str) {
    if (!env) {
        return nullptr;
    }
    return env->NewStringUTF(str.c_str());
}

std::map<std::string, std::string> JNIHelper::jmapToMap(JNIEnv* env, jobject jmap) {
    std::map<std::string, std::string> result;
    
    if (!env || !jmap) {
        return result;
    }

    try {
        // 获取 Map 类和方法
        jclass mapClass = env->FindClass("java/util/Map");
        jclass setClass = env->FindClass("java/util/Set");
        jclass iteratorClass = env->FindClass("java/util/Iterator");
        jclass entryClass = env->FindClass("java/util/Map$Entry");

        jmethodID entrySetMethod = env->GetMethodID(mapClass, "entrySet", "()Ljava/util/Set;");
        jmethodID iteratorMethod = env->GetMethodID(setClass, "iterator", "()Ljava/util/Iterator;");
        jmethodID hasNextMethod = env->GetMethodID(iteratorClass, "hasNext", "()Z");
        jmethodID nextMethod = env->GetMethodID(iteratorClass, "next", "()Ljava/lang/Object;");
        jmethodID getKeyMethod = env->GetMethodID(entryClass, "getKey", "()Ljava/lang/Object;");
        jmethodID getValueMethod = env->GetMethodID(entryClass, "getValue", "()Ljava/lang/Object;");

        // 遍历 Map
        jobject entrySet = env->CallObjectMethod(jmap, entrySetMethod);
        jobject iterator = env->CallObjectMethod(entrySet, iteratorMethod);

        while (env->CallBooleanMethod(iterator, hasNextMethod)) {
            jobject entry = env->CallObjectMethod(iterator, nextMethod);
            jstring jkey = static_cast<jstring>(env->CallObjectMethod(entry, getKeyMethod));
            jstring jvalue = static_cast<jstring>(env->CallObjectMethod(entry, getValueMethod));

            std::string key = jstringToString(env, jkey);
            std::string value = jstringToString(env, jvalue);
            result[key] = value;

            env->DeleteLocalRef(entry);
            env->DeleteLocalRef(jkey);
            env->DeleteLocalRef(jvalue);
        }

        env->DeleteLocalRef(entrySet);
        env->DeleteLocalRef(iterator);
    } catch (...) {
        HBLogger::e("JNIHelper", "jmapToMap 转换异常");
        checkAndClearException(env);
    }

    return result;
}

jobject JNIHelper::mapToJmap(JNIEnv* env, const std::map<std::string, std::string>& map) {
    if (!env) {
        return nullptr;
    }

    try {
        // 创建 HashMap
        jclass hashMapClass = env->FindClass("java/util/HashMap");
        jmethodID initMethod = env->GetMethodID(hashMapClass, "<init>", "()V");
        jmethodID putMethod = env->GetMethodID(hashMapClass, "put", 
            "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");

        jobject jmap = env->NewObject(hashMapClass, initMethod);

        // 添加元素
        for (const auto& pair : map) {
            jstring jkey = stringToJstring(env, pair.first);
            jstring jvalue = stringToJstring(env, pair.second);
            env->CallObjectMethod(jmap, putMethod, jkey, jvalue);
            env->DeleteLocalRef(jkey);
            env->DeleteLocalRef(jvalue);
        }

        return jmap;
    } catch (...) {
        HBLogger::e("JNIHelper", "mapToJmap 转换异常");
        checkAndClearException(env);
        return nullptr;
    }
}

std::vector<std::string> JNIHelper::jlistToVector(JNIEnv* env, jobject jlist) {
    std::vector<std::string> result;
    
    if (!env || !jlist) {
        return result;
    }

    try {
        jclass listClass = env->FindClass("java/util/List");
        jmethodID sizeMethod = env->GetMethodID(listClass, "size", "()I");
        jmethodID getMethod = env->GetMethodID(listClass, "get", "(I)Ljava/lang/Object;");

        jint size = env->CallIntMethod(jlist, sizeMethod);
        
        for (jint i = 0; i < size; i++) {
            jstring jstr = static_cast<jstring>(env->CallObjectMethod(jlist, getMethod, i));
            result.push_back(jstringToString(env, jstr));
            env->DeleteLocalRef(jstr);
        }
    } catch (...) {
        HBLogger::e("JNIHelper", "jlistToVector 转换异常");
        checkAndClearException(env);
    }

    return result;
}

jobject JNIHelper::vectorToJlist(JNIEnv* env, const std::vector<std::string>& vec) {
    if (!env) {
        return nullptr;
    }

    try {
        jclass arrayListClass = env->FindClass("java/util/ArrayList");
        jmethodID initMethod = env->GetMethodID(arrayListClass, "<init>", "()V");
        jmethodID addMethod = env->GetMethodID(arrayListClass, "add", "(Ljava/lang/Object;)Z");

        jobject jlist = env->NewObject(arrayListClass, initMethod);

        for (const auto& str : vec) {
            jstring jstr = stringToJstring(env, str);
            env->CallBooleanMethod(jlist, addMethod, jstr);
            env->DeleteLocalRef(jstr);
        }

        return jlist;
    } catch (...) {
        HBLogger::e("JNIHelper", "vectorToJlist 转换异常");
        checkAndClearException(env);
        return nullptr;
    }
}

bool JNIHelper::checkAndClearException(JNIEnv* env) {
    if (!env) {
        return false;
    }

    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        return true;
    }
    
    return false;
}

} // namespace android
} // namespace platform
} // namespace helpbot

// ==================== JNI 入口函数 ====================

extern "C" {

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* reserved) {
    helpbot::platform::android::JNIHelper::init(vm);
    return JNI_VERSION_1_6;
}

JNIEXPORT void JNICALL JNI_OnUnload(JavaVM* vm, void* reserved) {
    // 清理资源
}

} // extern "C"

// ==================== Cocos2d Java Bridge -> Native 回调 ====================

static helpbot::HelpBotAuthenticationFailureReason parseAuthFailureReason(const std::string& reason) {
    if (reason == "TOKEN_EXPIRED") {
        return helpbot::HelpBotAuthenticationFailureReason::TOKEN_EXPIRED;
    }
    if (reason == "TOKEN_INVALID") {
        return helpbot::HelpBotAuthenticationFailureReason::TOKEN_INVALID;
    }
    if (reason == "NETWORK_ERROR") {
        return helpbot::HelpBotAuthenticationFailureReason::NETWORK_ERROR;
    }
    if (reason == "SERVER_ERROR") {
        return helpbot::HelpBotAuthenticationFailureReason::SERVER_ERROR;
    }
    return helpbot::HelpBotAuthenticationFailureReason::UNKNOWN;
}

extern "C" {

JNIEXPORT void JNICALL
Java_com_example_HelpBot_cocos2d_HelpBotCocos2dBridge_nativeInitClassLoader(
        JNIEnv* env, jclass /*clazz*/, jobject classLoader) {
    helpbot::platform::android::JNIHelper::initClassLoader(env, classLoader);
}

JNIEXPORT void JNICALL
Java_com_example_HelpBot_cocos2d_HelpBotCocos2dBridge_nativeOnInitStart(
        JNIEnv* /*env*/, jclass /*clazz*/, jlong callbackPtr) {
    auto* callback = reinterpret_cast<helpbot::HelpBotInitCallback*>(callbackPtr);
    if (!callback) {
        return;
    }
    try {
        callback->onInitStart();
    } catch (...) {
        helpbot::HBLogger::e("HelpBotCocos2dBridge", "nativeOnInitStart 异常");
    }
}

JNIEXPORT void JNICALL
Java_com_example_HelpBot_cocos2d_HelpBotCocos2dBridge_nativeOnInitProgress(
        JNIEnv* env, jclass /*clazz*/, jlong callbackPtr, jint progress, jstring message) {
    auto* callback = reinterpret_cast<helpbot::HelpBotInitCallback*>(callbackPtr);
    if (!callback) {
        return;
    }
    try {
        const std::string msg = helpbot::platform::android::JNIHelper::jstringToString(env, message);
        callback->onInitProgress(static_cast<int>(progress), msg);
    } catch (...) {
        helpbot::HBLogger::e("HelpBotCocos2dBridge", "nativeOnInitProgress 异常");
    }
}

JNIEXPORT void JNICALL
Java_com_example_HelpBot_cocos2d_HelpBotCocos2dBridge_nativeOnInitSuccess(
        JNIEnv* /*env*/, jclass /*clazz*/, jlong callbackPtr) {
    auto* callback = reinterpret_cast<helpbot::HelpBotInitCallback*>(callbackPtr);
    if (!callback) {
        return;
    }
    try {
        callback->onInitSuccess();
    } catch (...) {
        helpbot::HBLogger::e("HelpBotCocos2dBridge", "nativeOnInitSuccess 异常");
    }
}

JNIEXPORT void JNICALL
Java_com_example_HelpBot_cocos2d_HelpBotCocos2dBridge_nativeOnInitFailure(
        JNIEnv* env, jclass /*clazz*/, jlong callbackPtr, jint errorCode, jstring errorMessage) {
    auto* callback = reinterpret_cast<helpbot::HelpBotInitCallback*>(callbackPtr);
    if (!callback) {
        return;
    }
    try {
        const std::string msg = helpbot::platform::android::JNIHelper::jstringToString(env, errorMessage);
        callback->onInitFailure(static_cast<helpbot::HelpBotErrorCode>(static_cast<int>(errorCode)), msg);
    } catch (...) {
        helpbot::HBLogger::e("HelpBotCocos2dBridge", "nativeOnInitFailure 异常");
    }
}

JNIEXPORT void JNICALL
Java_com_example_HelpBot_cocos2d_HelpBotCocos2dBridge_nativeOnVoidCallbackSuccess(
        JNIEnv* /*env*/, jclass /*clazz*/, jlong callbackPtr) {
    auto* callback = reinterpret_cast<helpbot::HelpBotCallback<void>*>(callbackPtr);
    if (!callback) {
        return;
    }
    try {
        callback->onSuccess();
    } catch (...) {
        helpbot::HBLogger::e("HelpBotCocos2dBridge", "nativeOnVoidCallbackSuccess 异常");
    }
}

JNIEXPORT void JNICALL
Java_com_example_HelpBot_cocos2d_HelpBotCocos2dBridge_nativeOnVoidCallbackFailure(
        JNIEnv* env, jclass /*clazz*/, jlong callbackPtr, jint errorCode, jstring errorMessage) {
    auto* callback = reinterpret_cast<helpbot::HelpBotCallback<void>*>(callbackPtr);
    if (!callback) {
        return;
    }
    try {
        const std::string msg = helpbot::platform::android::JNIHelper::jstringToString(env, errorMessage);
        callback->onFailure(static_cast<helpbot::HelpBotErrorCode>(static_cast<int>(errorCode)), msg);
    } catch (...) {
        helpbot::HBLogger::e("HelpBotCocos2dBridge", "nativeOnVoidCallbackFailure 异常");
    }
}

JNIEXPORT void JNICALL
Java_com_example_HelpBot_cocos2d_HelpBotCocos2dBridge_nativeOnJsonCallbackSuccess(
        JNIEnv* env, jclass /*clazz*/, jlong callbackPtr, jstring jsonResult) {
    auto* callback = reinterpret_cast<helpbot::HelpBotCallback<std::string>*>(callbackPtr);
    if (!callback) {
        return;
    }
    try {
        const std::string json = helpbot::platform::android::JNIHelper::jstringToString(env, jsonResult);
        callback->onSuccess(json);
    } catch (...) {
        helpbot::HBLogger::e("HelpBotCocos2dBridge", "nativeOnJsonCallbackSuccess 异常");
    }
}

JNIEXPORT void JNICALL
Java_com_example_HelpBot_cocos2d_HelpBotCocos2dBridge_nativeOnJsonCallbackFailure(
        JNIEnv* env, jclass /*clazz*/, jlong callbackPtr, jint errorCode, jstring errorMessage) {
    auto* callback = reinterpret_cast<helpbot::HelpBotCallback<std::string>*>(callbackPtr);
    if (!callback) {
        return;
    }
    try {
        const std::string msg = helpbot::platform::android::JNIHelper::jstringToString(env, errorMessage);
        callback->onFailure(static_cast<helpbot::HelpBotErrorCode>(static_cast<int>(errorCode)), msg);
    } catch (...) {
        helpbot::HBLogger::e("HelpBotCocos2dBridge", "nativeOnJsonCallbackFailure 异常");
    }
}

JNIEXPORT void JNICALL
Java_com_example_HelpBot_cocos2d_HelpBotCocos2dBridge_nativeOnEventOccurred(
        JNIEnv* env, jclass /*clazz*/, jlong listenerPtr, jstring eventName, jobject dataMap) {
    auto* listener = reinterpret_cast<helpbot::HelpBotEventsListener*>(listenerPtr);
    if (!listener) {
        return;
    }
    try {
        const std::string name = helpbot::platform::android::JNIHelper::jstringToString(env, eventName);
        const std::map<std::string, std::string> map = helpbot::platform::android::JNIHelper::jmapToMap(env, dataMap);
        helpbot::EventData data;
        for (const auto& kv : map) {
            data[kv.first] = helpbot::EventValue(kv.second);
        }
        listener->onEventOccurred(name, data);
    } catch (...) {
        helpbot::HBLogger::e("HelpBotCocos2dBridge", "nativeOnEventOccurred 异常");
    }
}

JNIEXPORT void JNICALL
Java_com_example_HelpBot_cocos2d_HelpBotCocos2dBridge_nativeOnAuthFailure(
        JNIEnv* env, jclass /*clazz*/, jlong listenerPtr, jstring reason) {
    auto* listener = reinterpret_cast<helpbot::HelpBotEventsListener*>(listenerPtr);
    if (!listener) {
        return;
    }
    try {
        const std::string r = helpbot::platform::android::JNIHelper::jstringToString(env, reason);
        listener->onUserAuthenticationFailure(parseAuthFailureReason(r));
    } catch (...) {
        helpbot::HBLogger::e("HelpBotCocos2dBridge", "nativeOnAuthFailure 异常");
    }
}

} // extern "C"
