#include "HelpBotJNI.h"
#include "../../include/HBLogger.h"
#include <stdexcept>

namespace helpbot {
namespace platform {
namespace android {

static const char* TAG = "HelpBotAndroid";

static jobject getApplicationContext(JNIEnv* env) {
    if (!env) {
        return nullptr;
    }
    try {
        jclass activityThreadClass = JNIHelper::findClass(env, "android/app/ActivityThread");
        if (!activityThreadClass) {
            return nullptr;
        }
        jmethodID currentApplicationMethod = env->GetStaticMethodID(activityThreadClass,
                "currentApplication", "()Landroid/app/Application;");
        jobject app = env->CallStaticObjectMethod(activityThreadClass, currentApplicationMethod);
        JNIHelper::checkAndClearException(env);
        return app; // local ref
    } catch (...) {
        JNIHelper::checkAndClearException(env);
        return nullptr;
    }
}

static jobject buildJavaConfig(JNIEnv* env, const HelpBotConfig& config) {
    if (!env) {
        return nullptr;
    }

    jclass builderClass = JNIHelper::findClass(env, "com/helpbot/sdk/core/HelpBotConfig$Builder");
    if (!builderClass) {
        HBLogger::e(TAG, "buildJavaConfig: 找不到 HelpBotConfig$Builder");
        JNIHelper::checkAndClearException(env);
        return nullptr;
    }

    jmethodID builderInit = env->GetMethodID(builderClass, "<init>", "()V");
    jobject builder = env->NewObject(builderClass, builderInit);

    // channelId/domain 为必填
    jmethodID channelIdMethod = env->GetMethodID(builderClass, "channelId",
            "(Ljava/lang/String;)Lcom/helpbot/sdk/core/HelpBotConfig$Builder;");
    jstring jchannelId = JNIHelper::stringToJstring(env, config.getChannelId());
    builder = env->CallObjectMethod(builder, channelIdMethod, jchannelId);
    env->DeleteLocalRef(jchannelId);

    jmethodID domainMethod = env->GetMethodID(builderClass, "domain",
            "(Ljava/lang/String;)Lcom/helpbot/sdk/core/HelpBotConfig$Builder;");
    jstring jdomain = JNIHelper::stringToJstring(env, config.getDomain());
    builder = env->CallObjectMethod(builder, domainMethod, jdomain);
    env->DeleteLocalRef(jdomain);

    // fullPrivacyMode
    jmethodID fullPrivacyMethod = env->GetMethodID(builderClass, "fullPrivacyMode",
            "(Z)Lcom/helpbot/sdk/core/HelpBotConfig$Builder;");
    builder = env->CallObjectMethod(builder, fullPrivacyMethod, config.isFullPrivacyMode());

    // enableSseNotification
    jmethodID sseMethod = env->GetMethodID(builderClass, "enableSseNotification",
            "(Z)Lcom/helpbot/sdk/core/HelpBotConfig$Builder;");
    builder = env->CallObjectMethod(builder, sseMethod, config.isEnableSseNotification());

    // initTimeout
    jmethodID initTimeoutMethod = env->GetMethodID(builderClass, "initTimeout",
            "(I)Lcom/helpbot/sdk/core/HelpBotConfig$Builder;");
    builder = env->CallObjectMethod(builder, initTimeoutMethod, config.getInitTimeoutMs());

    // webViewLoadTimeout
    jmethodID webViewTimeoutMethod = env->GetMethodID(builderClass, "webViewLoadTimeout",
            "(I)Lcom/helpbot/sdk/core/HelpBotConfig$Builder;");
    builder = env->CallObjectMethod(builder, webViewTimeoutMethod, config.getWebViewLoadTimeoutMs());

    // useDevApi/companyId/userId/preGeneratedToken
    jmethodID useDevApiMethod = env->GetMethodID(builderClass, "useDevApi",
            "(Z)Lcom/helpbot/sdk/core/HelpBotConfig$Builder;");
    builder = env->CallObjectMethod(builder, useDevApiMethod, config.isUseDevApi());

    if (config.isUseDevApi()) {
        const std::string companyId = config.getCompanyId();
        const std::string userId = config.getUserId();

        if (!companyId.empty()) {
            jmethodID companyIdMethod = env->GetMethodID(builderClass, "companyId",
                    "(Ljava/lang/String;)Lcom/helpbot/sdk/core/HelpBotConfig$Builder;");
            jstring jcompanyId = JNIHelper::stringToJstring(env, companyId);
            builder = env->CallObjectMethod(builder, companyIdMethod, jcompanyId);
            env->DeleteLocalRef(jcompanyId);
        }
        if (!userId.empty()) {
            jmethodID userIdMethod = env->GetMethodID(builderClass, "userId",
                    "(Ljava/lang/String;)Lcom/helpbot/sdk/core/HelpBotConfig$Builder;");
            jstring juserId = JNIHelper::stringToJstring(env, userId);
            builder = env->CallObjectMethod(builder, userIdMethod, juserId);
            env->DeleteLocalRef(juserId);
        }
    }

    const std::string preToken = config.getPreGeneratedToken();
    if (!preToken.empty()) {
        jmethodID preTokenMethod = env->GetMethodID(builderClass, "preGeneratedToken",
                "(Ljava/lang/String;)Lcom/helpbot/sdk/core/HelpBotConfig$Builder;");
        jstring jpre = JNIHelper::stringToJstring(env, preToken);
        builder = env->CallObjectMethod(builder, preTokenMethod, jpre);
        env->DeleteLocalRef(jpre);
    }

    // customConfig（String -> Object）
    const auto customConfig = config.getCustomConfig();
    if (!customConfig.empty()) {
        jmethodID addCustomConfigMethod = env->GetMethodID(builderClass, "addCustomConfig",
                "(Ljava/lang/String;Ljava/lang/Object;)Lcom/helpbot/sdk/core/HelpBotConfig$Builder;");
        for (const auto& pair : customConfig) {
            jstring jkey = JNIHelper::stringToJstring(env, pair.first);
            jstring jvalue = JNIHelper::stringToJstring(env, pair.second);
            builder = env->CallObjectMethod(builder, addCustomConfigMethod, jkey, jvalue);
            env->DeleteLocalRef(jkey);
            env->DeleteLocalRef(jvalue);
        }
    }

    jmethodID buildMethod = env->GetMethodID(builderClass, "build",
            "()Lcom/helpbot/sdk/core/HelpBotConfig;");
    jobject jconfig = env->CallObjectMethod(builder, buildMethod);
    JNIHelper::checkAndClearException(env);

    env->DeleteLocalRef(builder);
    return jconfig; // local ref
}

static HelpBotResult<void> parseVoidResult(JNIEnv* env, jobject jresult) {
    if (!env || !jresult) {
        return HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "HelpBotResult 为空");
    }

    try {
        jclass resultClass = env->GetObjectClass(jresult);
        jmethodID isSuccessMethod = env->GetMethodID(resultClass, "isSuccess", "()Z");
        const jboolean success = env->CallBooleanMethod(jresult, isSuccessMethod);
        if (JNIHelper::checkAndClearException(env)) {
            return HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "读取 HelpBotResult 异常");
        }
        if (success) {
            return HelpBotResult<void>::success();
        }

        // errorCode.getCode / errorMessage
        jmethodID getErrorCodeMethod = env->GetMethodID(resultClass, "getErrorCode",
                "()Lcom/helpbot/sdk/core/HelpBotErrorCode;");
        jobject jerrorCode = env->CallObjectMethod(jresult, getErrorCodeMethod);

        int codeInt = static_cast<int>(HelpBotErrorCode::UNKNOWN_ERROR);
        if (jerrorCode) {
            jclass errorCodeClass = env->GetObjectClass(jerrorCode);
            jmethodID getCodeMethod = env->GetMethodID(errorCodeClass, "getCode", "()I");
            codeInt = env->CallIntMethod(jerrorCode, getCodeMethod);
        }

        jmethodID getErrorMsgMethod = env->GetMethodID(resultClass, "getErrorMessage", "()Ljava/lang/String;");
        jstring jmsg = static_cast<jstring>(env->CallObjectMethod(jresult, getErrorMsgMethod));
        const std::string msg = JNIHelper::jstringToString(env, jmsg);
        if (jmsg) {
            env->DeleteLocalRef(jmsg);
        }
        if (jerrorCode) {
            env->DeleteLocalRef(jerrorCode);
        }

        JNIHelper::checkAndClearException(env);
        return HelpBotResult<void>::failure(static_cast<HelpBotErrorCode>(codeInt),
                msg.empty() ? "操作失败" : msg);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
        return HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "解析 HelpBotResult 异常");
    }
}

// ==================== 对外（被 HelpBot.cpp 调用的 Android 实现） ====================

void install(const HelpBotConfig& config, HelpBotInitCallback* callback) {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        HBLogger::e(TAG, "install: 获取 JNIEnv 失败");
        if (callback) {
            callback->onInitFailure(HelpBotErrorCode::INTERNAL_ERROR, "JNI 环境初始化失败");
        }
        return;
    }

    try {
        jobject appContext = getApplicationContext(env);
        if (!appContext) {
            throw std::runtime_error("获取 Application Context 失败");
        }

        jobject jconfig = buildJavaConfig(env, config);
        if (!jconfig) {
            throw std::runtime_error("构建 HelpBotConfig 失败");
        }

        jclass bridgeClass = JNIHelper::findClass(env, "com/helpbot/sdk/cocos2d/HelpBotCocos2dBridge");
        if (!bridgeClass) {
            throw std::runtime_error("找不到 HelpBotCocos2dBridge（请按集成指南拷贝 Java Bridge）");
        }

        jmethodID installMethod = env->GetStaticMethodID(bridgeClass, "install",
                "(Landroid/content/Context;Lcom/helpbot/sdk/core/HelpBotConfig;J)V");
        env->CallStaticVoidMethod(bridgeClass, installMethod, appContext, jconfig,
                static_cast<jlong>(reinterpret_cast<intptr_t>(callback)));

        JNIHelper::checkAndClearException(env);
        env->DeleteLocalRef(appContext);
        env->DeleteLocalRef(jconfig);
    } catch (const std::exception& e) {
        HBLogger::e(TAG, std::string("install 异常: ") + e.what());
        if (callback) {
            callback->onInitFailure(HelpBotErrorCode::INTERNAL_ERROR, e.what());
        }
    }

    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
}

void login(const std::string& token,
           const std::map<std::string, std::string>* loginConfig,
           HelpBotCallback<void>* callback) {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        HBLogger::e(TAG, "login: 获取 JNIEnv 失败");
        if (callback) {
            callback->onFailure(HelpBotErrorCode::INTERNAL_ERROR, "JNI 环境初始化失败");
        }
        return;
    }

    try {
        jclass bridgeClass = JNIHelper::findClass(env, "com/helpbot/sdk/cocos2d/HelpBotCocos2dBridge");
        if (!bridgeClass) {
            throw std::runtime_error("找不到 HelpBotCocos2dBridge（请按集成指南拷贝 Java Bridge）");
        }
        jmethodID loginMethod = env->GetStaticMethodID(bridgeClass, "login",
                "(Ljava/lang/String;Ljava/util/Map;J)V");

        jstring jtoken = JNIHelper::stringToJstring(env, token);
        jobject jloginConfig = loginConfig ? JNIHelper::mapToJmap(env, *loginConfig) : nullptr;
        env->CallStaticVoidMethod(bridgeClass, loginMethod, jtoken, jloginConfig,
                static_cast<jlong>(reinterpret_cast<intptr_t>(callback)));

        env->DeleteLocalRef(jtoken);
        if (jloginConfig) {
            env->DeleteLocalRef(jloginConfig);
        }
        JNIHelper::checkAndClearException(env);
    } catch (const std::exception& e) {
        HBLogger::e(TAG, std::string("login 异常: ") + e.what());
        if (callback) {
            callback->onFailure(HelpBotErrorCode::INTERNAL_ERROR, e.what());
        }
    }

    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
}

bool isInitialized() {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return false;
    }
    bool ok = false;
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/helpbot/sdk/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, "isInitialized", "()Z");
        ok = env->CallStaticBooleanMethod(helpBotClass, method);
        JNIHelper::checkAndClearException(env);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
        ok = false;
    }
    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
    return ok;
}

std::string getSDKVersion() {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return "unknown";
    }
    std::string version = "unknown";
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/helpbot/sdk/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, "getSDKVersion", "()Ljava/lang/String;");
        jstring jversion = static_cast<jstring>(env->CallStaticObjectMethod(helpBotClass, method));
        version = JNIHelper::jstringToString(env, jversion);
        if (jversion) {
            env->DeleteLocalRef(jversion);
        }
        JNIHelper::checkAndClearException(env);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
        version = "unknown";
    }
    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
    return version;
}

HelpBotResult<void> logout() {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "JNI 环境初始化失败");
    }

    HelpBotResult<void> out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "logout 失败");
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/helpbot/sdk/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, "logout",
                "()Lcom/helpbot/sdk/core/HelpBotResult;");
        jobject jresult = env->CallStaticObjectMethod(helpBotClass, method);
        out = parseVoidResult(env, jresult);
        if (jresult) {
            env->DeleteLocalRef(jresult);
        }
    } catch (...) {
        JNIHelper::checkAndClearException(env);
        out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "logout 异常");
    }

    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
    return out;
}

HelpBotResult<void> showConversation(const std::map<std::string, std::string>* configMap) {
    // Android 侧 showConversation(context, configMap) 当前与 showConversation(context) 行为一致
    (void)configMap;
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "JNI 环境初始化失败");
    }

    HelpBotResult<void> out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "showConversation 失败");
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/helpbot/sdk/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, "showConversation",
                "(Landroid/content/Context;)Lcom/helpbot/sdk/core/HelpBotResult;");
        jobject ctx = getApplicationContext(env);
        jobject jresult = env->CallStaticObjectMethod(helpBotClass, method, ctx);
        out = parseVoidResult(env, jresult);
        if (ctx) {
            env->DeleteLocalRef(ctx);
        }
        if (jresult) {
            env->DeleteLocalRef(jresult);
        }
    } catch (...) {
        JNIHelper::checkAndClearException(env);
        out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "showConversation 异常");
    }

    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
    return out;
}

HelpBotResult<void> showConversation() {
    return showConversation(nullptr);
}

HelpBotResult<void> hideConversation() {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "JNI 环境初始化失败");
    }

    HelpBotResult<void> out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "hideConversation 失败");
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/helpbot/sdk/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, "hideConversation",
                "()Lcom/helpbot/sdk/core/HelpBotResult;");
        jobject jresult = env->CallStaticObjectMethod(helpBotClass, method);
        out = parseVoidResult(env, jresult);
        if (jresult) {
            env->DeleteLocalRef(jresult);
        }
    } catch (...) {
        JNIHelper::checkAndClearException(env);
        out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "hideConversation 异常");
    }

    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
    return out;
}

bool isConversationVisible() {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return false;
    }
    bool visible = false;
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/helpbot/sdk/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, "isConversationVisible", "()Z");
        visible = env->CallStaticBooleanMethod(helpBotClass, method);
        JNIHelper::checkAndClearException(env);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
        visible = false;
    }
    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
    return visible;
}

HelpBotResult<void> showFAQs(const std::map<std::string, std::string>* configMap) {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "JNI 环境初始化失败");
    }

    HelpBotResult<void> out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "showFAQs 失败");
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/helpbot/sdk/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, "showFAQs",
                "(Landroid/content/Context;Ljava/util/Map;)Lcom/helpbot/sdk/core/HelpBotResult;");
        jobject ctx = getApplicationContext(env);
        std::map<std::string, std::string> empty;
        jobject jmap = JNIHelper::mapToJmap(env, configMap ? *configMap : empty);
        jobject jresult = env->CallStaticObjectMethod(helpBotClass, method, ctx, jmap);
        out = parseVoidResult(env, jresult);
        if (ctx) env->DeleteLocalRef(ctx);
        if (jmap) env->DeleteLocalRef(jmap);
        if (jresult) env->DeleteLocalRef(jresult);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
        out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "showFAQs 异常");
    }

    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
    return out;
}

HelpBotResult<void> showFAQs() {
    return showFAQs(nullptr);
}

HelpBotResult<void> showFAQSection(const std::string& sectionId, const std::map<std::string, std::string>* configMap) {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "JNI 环境初始化失败");
    }

    HelpBotResult<void> out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "showFAQSection 失败");
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/helpbot/sdk/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, "showFAQSection",
                "(Landroid/content/Context;Ljava/lang/String;Ljava/util/Map;)Lcom/helpbot/sdk/core/HelpBotResult;");
        jobject ctx = getApplicationContext(env);
        jstring jsection = JNIHelper::stringToJstring(env, sectionId);
        std::map<std::string, std::string> empty;
        jobject jmap = JNIHelper::mapToJmap(env, configMap ? *configMap : empty);
        jobject jresult = env->CallStaticObjectMethod(helpBotClass, method, ctx, jsection, jmap);
        out = parseVoidResult(env, jresult);
        if (ctx) env->DeleteLocalRef(ctx);
        env->DeleteLocalRef(jsection);
        if (jmap) env->DeleteLocalRef(jmap);
        if (jresult) env->DeleteLocalRef(jresult);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
        out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "showFAQSection 异常");
    }

    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
    return out;
}

HelpBotResult<void> showFAQSection(const std::string& sectionId) {
    return showFAQSection(sectionId, nullptr);
}

HelpBotResult<void> showSingleFAQ(const std::string& questionId, const std::map<std::string, std::string>* configMap) {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "JNI 环境初始化失败");
    }

    HelpBotResult<void> out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "showSingleFAQ 失败");
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/helpbot/sdk/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, "showSingleFAQ",
                "(Landroid/content/Context;Ljava/lang/String;Ljava/util/Map;)Lcom/helpbot/sdk/core/HelpBotResult;");
        jobject ctx = getApplicationContext(env);
        jstring jq = JNIHelper::stringToJstring(env, questionId);
        std::map<std::string, std::string> empty;
        jobject jmap = JNIHelper::mapToJmap(env, configMap ? *configMap : empty);
        jobject jresult = env->CallStaticObjectMethod(helpBotClass, method, ctx, jq, jmap);
        out = parseVoidResult(env, jresult);
        if (ctx) env->DeleteLocalRef(ctx);
        env->DeleteLocalRef(jq);
        if (jmap) env->DeleteLocalRef(jmap);
        if (jresult) env->DeleteLocalRef(jresult);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
        out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "showSingleFAQ 异常");
    }

    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
    return out;
}

HelpBotResult<void> showSingleFAQ(const std::string& questionId) {
    return showSingleFAQ(questionId, nullptr);
}

static HelpBotResult<void> callMapVoidApi(const char* methodName, const std::map<std::string, std::string>& map) {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "JNI 环境初始化失败");
    }

    HelpBotResult<void> out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, std::string(methodName) + " 失败");
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/helpbot/sdk/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, methodName,
                "(Ljava/util/Map;)Lcom/helpbot/sdk/core/HelpBotResult;");
        jobject jmap = JNIHelper::mapToJmap(env, map);
        jobject jresult = env->CallStaticObjectMethod(helpBotClass, method, jmap);
        out = parseVoidResult(env, jresult);
        if (jmap) env->DeleteLocalRef(jmap);
        if (jresult) env->DeleteLocalRef(jresult);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
        out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, std::string(methodName) + " 异常");
    }

    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
    return out;
}

HelpBotResult<void> updateSDKMeta(const std::map<std::string, std::string>& sdkMeta) {
    return callMapVoidApi("updateSDKMeta", sdkMeta);
}

HelpBotResult<void> updateCustomMeta(const std::map<std::string, std::string>& customMeta) {
    return callMapVoidApi("updateCustomMeta", customMeta);
}

static HelpBotResult<void> callStringListVoidApi(const char* methodName, const std::vector<std::string>& vec) {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "JNI 环境初始化失败");
    }

    HelpBotResult<void> out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, std::string(methodName) + " 失败");
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/helpbot/sdk/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, methodName,
                "(Ljava/util/ArrayList;)Lcom/helpbot/sdk/core/HelpBotResult;");
        jobject jlist = JNIHelper::vectorToJlist(env, vec);
        jobject jresult = env->CallStaticObjectMethod(helpBotClass, method, jlist);
        out = parseVoidResult(env, jresult);
        if (jlist) env->DeleteLocalRef(jlist);
        if (jresult) env->DeleteLocalRef(jresult);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
        out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, std::string(methodName) + " 异常");
    }

    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
    return out;
}

HelpBotResult<void> addIssueTags(const std::vector<std::string>& tags) {
    return callStringListVoidApi("addIssueTags", tags);
}

HelpBotResult<void> removeIssueTags(const std::vector<std::string>& tags) {
    return callStringListVoidApi("removeIssueTags", tags);
}

HelpBotResult<void> reportSystemInfoToServer() {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "JNI 环境初始化失败");
    }

    HelpBotResult<void> out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "reportSystemInfoToServer 失败");
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/helpbot/sdk/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, "reportSystemInfoToServer",
                "()Lcom/helpbot/sdk/core/HelpBotResult;");
        jobject jresult = env->CallStaticObjectMethod(helpBotClass, method);
        out = parseVoidResult(env, jresult);
        if (jresult) env->DeleteLocalRef(jresult);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
        out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "reportSystemInfoToServer 异常");
    }

    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
    return out;
}

void sendMessageAsync(const std::string& message, HelpBotCallback<std::string>* callback) {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        if (callback) {
            callback->onFailure(HelpBotErrorCode::INTERNAL_ERROR, "JNI 环境初始化失败");
        }
        return;
    }

    try {
        jclass bridgeClass = JNIHelper::findClass(env, "com/helpbot/sdk/cocos2d/HelpBotCocos2dBridge");
        if (!bridgeClass) {
            throw std::runtime_error("找不到 HelpBotCocos2dBridge（请按集成指南拷贝 Java Bridge）");
        }
        jmethodID method = env->GetStaticMethodID(bridgeClass, "sendMessageAsync",
                "(Ljava/lang/String;J)V");
        jstring jmsg = JNIHelper::stringToJstring(env, message);
        env->CallStaticVoidMethod(bridgeClass, method, jmsg,
                static_cast<jlong>(reinterpret_cast<intptr_t>(callback)));
        env->DeleteLocalRef(jmsg);
        JNIHelper::checkAndClearException(env);
    } catch (const std::exception& e) {
        if (callback) {
            callback->onFailure(HelpBotErrorCode::INTERNAL_ERROR, e.what());
        }
    }

    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
}

void getHistoryMessagesAsync(HelpBotCallback<std::string>* callback) {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        if (callback) {
            callback->onFailure(HelpBotErrorCode::INTERNAL_ERROR, "JNI 环境初始化失败");
        }
        return;
    }

    try {
        jclass bridgeClass = JNIHelper::findClass(env, "com/helpbot/sdk/cocos2d/HelpBotCocos2dBridge");
        if (!bridgeClass) {
            throw std::runtime_error("找不到 HelpBotCocos2dBridge（请按集成指南拷贝 Java Bridge）");
        }
        jmethodID method = env->GetStaticMethodID(bridgeClass, "getHistoryMessagesAsync",
                "(J)V");
        env->CallStaticVoidMethod(bridgeClass, method,
                static_cast<jlong>(reinterpret_cast<intptr_t>(callback)));
        JNIHelper::checkAndClearException(env);
    } catch (const std::exception& e) {
        if (callback) {
            callback->onFailure(HelpBotErrorCode::INTERNAL_ERROR, e.what());
        }
    }

    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
}

void loadMoreMessagesAsync(int limit, int offset, HelpBotCallback<std::string>* callback) {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        if (callback) {
            callback->onFailure(HelpBotErrorCode::INTERNAL_ERROR, "JNI 环境初始化失败");
        }
        return;
    }

    try {
        jclass bridgeClass = JNIHelper::findClass(env, "com/helpbot/sdk/cocos2d/HelpBotCocos2dBridge");
        if (!bridgeClass) {
            throw std::runtime_error("找不到 HelpBotCocos2dBridge（请按集成指南拷贝 Java Bridge）");
        }
        jmethodID method = env->GetStaticMethodID(bridgeClass, "loadMoreMessagesAsync",
                "(IIJ)V");
        env->CallStaticVoidMethod(bridgeClass, method, static_cast<jint>(limit), static_cast<jint>(offset),
                static_cast<jlong>(reinterpret_cast<intptr_t>(callback)));
        JNIHelper::checkAndClearException(env);
    } catch (const std::exception& e) {
        if (callback) {
            callback->onFailure(HelpBotErrorCode::INTERNAL_ERROR, e.what());
        }
    }

    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
}

void setHelpBotEventsListener(HelpBotEventsListener* listener) {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return;
    }
    try {
        jclass bridgeClass = JNIHelper::findClass(env, "com/helpbot/sdk/cocos2d/HelpBotCocos2dBridge");
        if (!bridgeClass) {
            throw std::runtime_error("找不到 HelpBotCocos2dBridge（请按集成指南拷贝 Java Bridge）");
        }
        jmethodID method = env->GetStaticMethodID(bridgeClass, "setEventsListener", "(J)V");
        env->CallStaticVoidMethod(bridgeClass, method,
                static_cast<jlong>(reinterpret_cast<intptr_t>(listener)));
        JNIHelper::checkAndClearException(env);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
    }
    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
}

void removeHelpBotEventsListener() {
    setHelpBotEventsListener(nullptr);
}

void enableSseNotification(bool enable) {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return;
    }
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/helpbot/sdk/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, "enableSseNotification", "(Z)V");
        env->CallStaticVoidMethod(helpBotClass, method, static_cast<jboolean>(enable));
        JNIHelper::checkAndClearException(env);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
    }
    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
}

bool isSseNotificationEnabled() {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return false;
    }
    bool enabled = false;
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/helpbot/sdk/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, "isSseNotificationEnabled", "()Z");
        enabled = env->CallStaticBooleanMethod(helpBotClass, method);
        JNIHelper::checkAndClearException(env);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
        enabled = false;
    }
    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
    return enabled;
}

void setNotificationSmallIconResId(int resId) {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return;
    }
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/helpbot/sdk/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, "setNotificationSmallIconResId", "(I)V");
        env->CallStaticVoidMethod(helpBotClass, method, static_cast<jint>(resId));
        JNIHelper::checkAndClearException(env);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
    }
    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
}

void setNotificationChannelId(const std::string& channelId) {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return;
    }
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/helpbot/sdk/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, "setNotificationChannelId", "(Ljava/lang/String;)V");
        jstring jcid = JNIHelper::stringToJstring(env, channelId);
        env->CallStaticVoidMethod(helpBotClass, method, jcid);
        env->DeleteLocalRef(jcid);
        JNIHelper::checkAndClearException(env);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
    }
    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
}

HelpBotResult<void> closeSession() {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "JNI 环境初始化失败");
    }

    HelpBotResult<void> out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "closeSession 失败");
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/example/HelpBot/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, "closeSession",
                "()Lcom/example/HelpBot/core/HelpBotResult;");
        jobject jresult = env->CallStaticObjectMethod(helpBotClass, method);
        out = parseVoidResult(env, jresult);
        if (jresult) {
            env->DeleteLocalRef(jresult);
        }
    } catch (...) {
        JNIHelper::checkAndClearException(env);
        out = HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "closeSession 异常");
    }

    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
    return out;
}

std::string getWebSdkHealthSnapshotJson() {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return "{}";
    }
    std::string out = "{}";
    try {
        jclass bridgeClass = JNIHelper::findClass(env, "com/example/HelpBot/cocos2d/HelpBotCocos2dBridge");
        if (!bridgeClass) {
            throw std::runtime_error("找不到 HelpBotCocos2dBridge（请按集成指南拷贝 Java Bridge）");
        }
        jmethodID method = env->GetStaticMethodID(bridgeClass, "getWebSdkHealthSnapshotJson", "()Ljava/lang/String;");
        jstring json = static_cast<jstring>(env->CallStaticObjectMethod(bridgeClass, method));
        out = JNIHelper::jstringToString(env, json);
        if (json) env->DeleteLocalRef(json);
        JNIHelper::checkAndClearException(env);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
        out = "{}";
    }
    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
    return out;
}

void markLoginConfirmedFromWeb() {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return;
    }
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/example/HelpBot/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, "markLoginConfirmedFromWeb", "()V");
        env->CallStaticVoidMethod(helpBotClass, method);
        JNIHelper::checkAndClearException(env);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
    }
    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
}

std::string getPendingLoginToken() {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return "";
    }
    std::string out;
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/example/HelpBot/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, "getPendingLoginToken", "()Ljava/lang/String;");
        jstring token = static_cast<jstring>(env->CallStaticObjectMethod(helpBotClass, method));
        out = JNIHelper::jstringToString(env, token);
        if (token) env->DeleteLocalRef(token);
        JNIHelper::checkAndClearException(env);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
        out = "";
    }
    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
    return out;
}

std::string consumePendingLoginToken() {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return "";
    }
    std::string out;
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/example/HelpBot/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, "consumePendingLoginToken", "()Ljava/lang/String;");
        jstring token = static_cast<jstring>(env->CallStaticObjectMethod(helpBotClass, method));
        out = JNIHelper::jstringToString(env, token);
        if (token) env->DeleteLocalRef(token);
        JNIHelper::checkAndClearException(env);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
        out = "";
    }
    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
    return out;
}

void destroy() {
    bool didAttach = false;
    JNIEnv* env = JNIHelper::getEnv(&didAttach);
    if (!env) {
        return;
    }
    try {
        jclass helpBotClass = JNIHelper::findClass(env, "com/example/HelpBot/HelpBot");
        jmethodID method = env->GetStaticMethodID(helpBotClass, "destroy", "()V");
        env->CallStaticVoidMethod(helpBotClass, method);
        JNIHelper::checkAndClearException(env);
    } catch (...) {
        JNIHelper::checkAndClearException(env);
    }
    JNIHelper::detachCurrentThreadIfNeeded(didAttach);
}

} // namespace android
} // namespace platform

} // namespace helpbot
