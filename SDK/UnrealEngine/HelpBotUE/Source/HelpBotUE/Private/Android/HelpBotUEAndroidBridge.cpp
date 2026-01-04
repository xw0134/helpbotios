#include "Android/HelpBotUEAndroidBridge.h"

#if PLATFORM_ANDROID

#include "HelpBotUESubsystem.h"

#include "Async/Async.h"
#include "Android/AndroidApplication.h"
#include "Android/AndroidJavaEnv.h"
#include "Android/AndroidJNI.h"

namespace
{
    static const ANSICHAR* bridgeClassName = "com/helpbot/ue/HelpBotUEBridge";

    struct BridgeJniCache
    {
        bool isReady = false;
        jclass bridgeClass = nullptr;

        jmethodID installMethod = nullptr;
        jmethodID loginMethod = nullptr;
        jmethodID showConversationMethod = nullptr;
        jmethodID hideConversationMethod = nullptr;
        jmethodID logoutMethod = nullptr;
        jmethodID sendMessageMethod = nullptr;
        jmethodID enableSseMethod = nullptr;
        jmethodID getSdkVersionMethod = nullptr;

        // P0: 历史消息
        jmethodID getHistoryMessagesMethod = nullptr;
        jmethodID loadMoreMessagesMethod = nullptr;

        // P0: FAQ
        jmethodID showFAQsMethod = nullptr;
        jmethodID showFAQsSimpleMethod = nullptr;
        jmethodID showFAQSectionMethod = nullptr;
        jmethodID showFAQSectionSimpleMethod = nullptr;
        jmethodID showSingleFAQMethod = nullptr;
        jmethodID showSingleFAQSimpleMethod = nullptr;

        // P0: Meta
        jmethodID updateSDKMetaMethod = nullptr;
        jmethodID updateCustomMetaMethod = nullptr;
        jmethodID reportSystemInfoMethod = nullptr;

        // P0: 会话管理
        jmethodID closeSessionMethod = nullptr;
        jmethodID destroyMethod = nullptr;

        // P1: Issue 标签
        jmethodID addIssueTagsMethod = nullptr;
        jmethodID removeIssueTagsMethod = nullptr;

        // P1: SDK 信息
        jmethodID isInitializedMethod = nullptr;
        jmethodID isConversationVisibleMethod = nullptr;
        jmethodID isSseNotificationEnabledMethod = nullptr;
        jmethodID getWebSdkHealthSnapshotMethod = nullptr;
    };

    static BridgeJniCache cache;

    static bool ensureCache(JNIEnv* env)
    {
        if (cache.isReady)
        {
            return true;
        }

        if (env == nullptr)
        {
            return false;
        }

        jclass localClass = FAndroidApplication::FindJavaClass(bridgeClassName);
        if (localClass == nullptr)
        {
            return false;
        }
        cache.bridgeClass = static_cast<jclass>(env->NewGlobalRef(localClass));
        env->DeleteLocalRef(localClass);

        if (cache.bridgeClass == nullptr)
        {
            return false;
        }

        cache.installMethod = env->GetStaticMethodID(cache.bridgeClass, "install",
            "(Landroid/app/Activity;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");
        cache.loginMethod = env->GetStaticMethodID(cache.bridgeClass, "login",
            "(Ljava/lang/String;Ljava/lang/String;)V");
        cache.showConversationMethod = env->GetStaticMethodID(cache.bridgeClass, "showConversation",
            "(Landroid/app/Activity;)V");
        cache.hideConversationMethod = env->GetStaticMethodID(cache.bridgeClass, "hideConversation", "()V");
        cache.logoutMethod = env->GetStaticMethodID(cache.bridgeClass, "logout", "()V");
        cache.sendMessageMethod = env->GetStaticMethodID(cache.bridgeClass, "sendMessage",
            "(Ljava/lang/String;)V");
        cache.enableSseMethod = env->GetStaticMethodID(cache.bridgeClass, "enableSseNotification", "(Z)V");
        cache.getSdkVersionMethod = env->GetStaticMethodID(cache.bridgeClass, "getSdkVersion", "()Ljava/lang/String;");

        // P0: 历史消息
        cache.getHistoryMessagesMethod = env->GetStaticMethodID(cache.bridgeClass, "getHistoryMessages", "()V");
        cache.loadMoreMessagesMethod = env->GetStaticMethodID(cache.bridgeClass, "loadMoreMessages", "(II)V");

        // P0: FAQ
        cache.showFAQsMethod = env->GetStaticMethodID(cache.bridgeClass, "showFAQs", "(Landroid/app/Activity;Ljava/lang/String;)V");
        cache.showFAQsSimpleMethod = env->GetStaticMethodID(cache.bridgeClass, "showFAQsSimple", "(Landroid/app/Activity;)V");
        cache.showFAQSectionMethod = env->GetStaticMethodID(cache.bridgeClass, "showFAQSection", "(Landroid/app/Activity;Ljava/lang/String;Ljava/lang/String;)V");
        cache.showFAQSectionSimpleMethod = env->GetStaticMethodID(cache.bridgeClass, "showFAQSectionSimple", "(Landroid/app/Activity;Ljava/lang/String;)V");
        cache.showSingleFAQMethod = env->GetStaticMethodID(cache.bridgeClass, "showSingleFAQ", "(Landroid/app/Activity;Ljava/lang/String;Ljava/lang/String;)V");
        cache.showSingleFAQSimpleMethod = env->GetStaticMethodID(cache.bridgeClass, "showSingleFAQSimple", "(Landroid/app/Activity;Ljava/lang/String;)V");

        // P0: Meta
        cache.updateSDKMetaMethod = env->GetStaticMethodID(cache.bridgeClass, "updateSDKMeta", "(Ljava/lang/String;)V");
        cache.updateCustomMetaMethod = env->GetStaticMethodID(cache.bridgeClass, "updateCustomMeta", "(Ljava/lang/String;)V");
        cache.reportSystemInfoMethod = env->GetStaticMethodID(cache.bridgeClass, "reportSystemInfoToServer", "()V");

        // P0: 会话管理
        cache.closeSessionMethod = env->GetStaticMethodID(cache.bridgeClass, "closeSession", "()V");
        cache.destroyMethod = env->GetStaticMethodID(cache.bridgeClass, "destroy", "()V");

        // P1: Issue 标签
        cache.addIssueTagsMethod = env->GetStaticMethodID(cache.bridgeClass, "addIssueTags", "(Ljava/lang/String;)V");
        cache.removeIssueTagsMethod = env->GetStaticMethodID(cache.bridgeClass, "removeIssueTags", "(Ljava/lang/String;)V");

        // P1: SDK 信息
        cache.isInitializedMethod = env->GetStaticMethodID(cache.bridgeClass, "isInitialized", "()Z");
        cache.isConversationVisibleMethod = env->GetStaticMethodID(cache.bridgeClass, "isConversationVisible", "()Z");
        cache.isSseNotificationEnabledMethod = env->GetStaticMethodID(cache.bridgeClass, "isSseNotificationEnabled", "()Z");
        cache.getWebSdkHealthSnapshotMethod = env->GetStaticMethodID(cache.bridgeClass, "getWebSdkHealthSnapshot", "()Ljava/lang/String;");

        cache.isReady = (cache.installMethod && cache.loginMethod && cache.showConversationMethod
            && cache.hideConversationMethod && cache.logoutMethod && cache.sendMessageMethod
            && cache.enableSseMethod && cache.getSdkVersionMethod
            && cache.getHistoryMessagesMethod && cache.loadMoreMessagesMethod
            && cache.showFAQsMethod && cache.showFAQsSimpleMethod
            && cache.showFAQSectionMethod && cache.showFAQSectionSimpleMethod
            && cache.showSingleFAQMethod && cache.showSingleFAQSimpleMethod
            && cache.updateSDKMetaMethod && cache.updateCustomMetaMethod && cache.reportSystemInfoMethod
            && cache.closeSessionMethod && cache.destroyMethod
            && cache.addIssueTagsMethod && cache.removeIssueTagsMethod
            && cache.isInitializedMethod && cache.isConversationVisibleMethod
            && cache.isSseNotificationEnabledMethod && cache.getWebSdkHealthSnapshotMethod);

        return cache.isReady;
    }

    static jobject getGameActivityThis(JNIEnv* env)
    {
        if (env == nullptr)
        {
            return nullptr;
        }
        return FAndroidApplication::GetGameActivityThis();
    }

    static void safeNotifyUnsupported()
    {
        if (UHelpBotUESubsystem* subsystem = UHelpBotUESubsystem::GetActive())
        {
            subsystem->DispatchEventOnGameThread(TEXT("HB_ANDROID_BRIDGE_NOT_READY"), TEXT("{}"));
        }
    }

    static FString jstringToFString(JNIEnv* env, jstring str)
    {
        if (env == nullptr || str == nullptr)
        {
            return FString();
        }
        const char* utfChars = env->GetStringUTFChars(str, nullptr);
        FString out(UTF8_TO_TCHAR(utfChars));
        env->ReleaseStringUTFChars(str, utfChars);
        return out;
    }
}

void HelpBotUEAndroidBridge::Install(const FString& channelId, const FString& domain, const FString& configJson)
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }

    jobject activity = getGameActivityThis(env);
    if (activity == nullptr)
    {
        safeNotifyUnsupported();
        return;
    }

    jstring jChannelId = env->NewStringUTF(TCHAR_TO_UTF8(*channelId));
    jstring jDomain = env->NewStringUTF(TCHAR_TO_UTF8(*domain));
    jstring jConfig = env->NewStringUTF(TCHAR_TO_UTF8(*configJson));

    env->CallStaticVoidMethod(cache.bridgeClass, cache.installMethod, activity, jChannelId, jDomain, jConfig);

    env->DeleteLocalRef(jChannelId);
    env->DeleteLocalRef(jDomain);
    env->DeleteLocalRef(jConfig);
}

void HelpBotUEAndroidBridge::Login(const FString& token, const FString& loginConfigJson)
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }

    jstring jToken = env->NewStringUTF(TCHAR_TO_UTF8(*token));
    jstring jConfig = env->NewStringUTF(TCHAR_TO_UTF8(*loginConfigJson));
    env->CallStaticVoidMethod(cache.bridgeClass, cache.loginMethod, jToken, jConfig);
    env->DeleteLocalRef(jToken);
    env->DeleteLocalRef(jConfig);
}

void HelpBotUEAndroidBridge::ShowConversation()
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }

    jobject activity = getGameActivityThis(env);
    if (activity == nullptr)
    {
        safeNotifyUnsupported();
        return;
    }

    env->CallStaticVoidMethod(cache.bridgeClass, cache.showConversationMethod, activity);
}

void HelpBotUEAndroidBridge::HideConversation()
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }
    env->CallStaticVoidMethod(cache.bridgeClass, cache.hideConversationMethod);
}

void HelpBotUEAndroidBridge::Logout()
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }
    env->CallStaticVoidMethod(cache.bridgeClass, cache.logoutMethod);
}

void HelpBotUEAndroidBridge::SendMessage(const FString& message)
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }

    jstring jMessage = env->NewStringUTF(TCHAR_TO_UTF8(*message));
    env->CallStaticVoidMethod(cache.bridgeClass, cache.sendMessageMethod, jMessage);
    env->DeleteLocalRef(jMessage);
}

void HelpBotUEAndroidBridge::EnableSseNotification(const bool enable)
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }
    env->CallStaticVoidMethod(cache.bridgeClass, cache.enableSseMethod, (jboolean)enable);
}

FString HelpBotUEAndroidBridge::GetSdkVersion()
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        return FString();
    }

    jstring jVersion = static_cast<jstring>(env->CallStaticObjectMethod(cache.bridgeClass, cache.getSdkVersionMethod));
    const FString out = jstringToFString(env, jVersion);
    if (jVersion != nullptr)
    {
        env->DeleteLocalRef(jVersion);
    }
    return out;
}

// ==================== P0: 历史消息功能 ====================

void HelpBotUEAndroidBridge::GetHistoryMessages()
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }
    env->CallStaticVoidMethod(cache.bridgeClass, cache.getHistoryMessagesMethod);
}

void HelpBotUEAndroidBridge::LoadMoreMessages(int32 limit, int32 offset)
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }
    env->CallStaticVoidMethod(cache.bridgeClass, cache.loadMoreMessagesMethod, (jint)limit, (jint)offset);
}

// ==================== P0: FAQ 功能 ====================

void HelpBotUEAndroidBridge::ShowFAQs(const FString& configJson)
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }

    jobject activity = getGameActivityThis(env);
    if (activity == nullptr)
    {
        safeNotifyUnsupported();
        return;
    }

    jstring jConfig = env->NewStringUTF(TCHAR_TO_UTF8(*configJson));
    env->CallStaticVoidMethod(cache.bridgeClass, cache.showFAQsMethod, activity, jConfig);
    env->DeleteLocalRef(jConfig);
}

void HelpBotUEAndroidBridge::ShowFAQsSimple()
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }

    jobject activity = getGameActivityThis(env);
    if (activity == nullptr)
    {
        safeNotifyUnsupported();
        return;
    }

    env->CallStaticVoidMethod(cache.bridgeClass, cache.showFAQsSimpleMethod, activity);
}

void HelpBotUEAndroidBridge::ShowFAQSection(const FString& sectionPublishId, const FString& configJson)
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }

    jobject activity = getGameActivityThis(env);
    if (activity == nullptr)
    {
        safeNotifyUnsupported();
        return;
    }

    jstring jSectionId = env->NewStringUTF(TCHAR_TO_UTF8(*sectionPublishId));
    jstring jConfig = env->NewStringUTF(TCHAR_TO_UTF8(*configJson));
    env->CallStaticVoidMethod(cache.bridgeClass, cache.showFAQSectionMethod, activity, jSectionId, jConfig);
    env->DeleteLocalRef(jSectionId);
    env->DeleteLocalRef(jConfig);
}

void HelpBotUEAndroidBridge::ShowFAQSectionSimple(const FString& sectionPublishId)
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }

    jobject activity = getGameActivityThis(env);
    if (activity == nullptr)
    {
        safeNotifyUnsupported();
        return;
    }

    jstring jSectionId = env->NewStringUTF(TCHAR_TO_UTF8(*sectionPublishId));
    env->CallStaticVoidMethod(cache.bridgeClass, cache.showFAQSectionSimpleMethod, activity, jSectionId);
    env->DeleteLocalRef(jSectionId);
}

void HelpBotUEAndroidBridge::ShowSingleFAQ(const FString& questionPublishId, const FString& configJson)
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }

    jobject activity = getGameActivityThis(env);
    if (activity == nullptr)
    {
        safeNotifyUnsupported();
        return;
    }

    jstring jQuestionId = env->NewStringUTF(TCHAR_TO_UTF8(*questionPublishId));
    jstring jConfig = env->NewStringUTF(TCHAR_TO_UTF8(*configJson));
    env->CallStaticVoidMethod(cache.bridgeClass, cache.showSingleFAQMethod, activity, jQuestionId, jConfig);
    env->DeleteLocalRef(jQuestionId);
    env->DeleteLocalRef(jConfig);
}

void HelpBotUEAndroidBridge::ShowSingleFAQSimple(const FString& questionPublishId)
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }

    jobject activity = getGameActivityThis(env);
    if (activity == nullptr)
    {
        safeNotifyUnsupported();
        return;
    }

    jstring jQuestionId = env->NewStringUTF(TCHAR_TO_UTF8(*questionPublishId));
    env->CallStaticVoidMethod(cache.bridgeClass, cache.showSingleFAQSimpleMethod, activity, jQuestionId);
    env->DeleteLocalRef(jQuestionId);
}

// ==================== P0: Meta 数据更新 ====================

void HelpBotUEAndroidBridge::UpdateSDKMeta(const FString& metaJson)
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }

    jstring jMeta = env->NewStringUTF(TCHAR_TO_UTF8(*metaJson));
    env->CallStaticVoidMethod(cache.bridgeClass, cache.updateSDKMetaMethod, jMeta);
    env->DeleteLocalRef(jMeta);
}

void HelpBotUEAndroidBridge::UpdateCustomMeta(const FString& customMetaJson)
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }

    jstring jMeta = env->NewStringUTF(TCHAR_TO_UTF8(*customMetaJson));
    env->CallStaticVoidMethod(cache.bridgeClass, cache.updateCustomMetaMethod, jMeta);
    env->DeleteLocalRef(jMeta);
}

void HelpBotUEAndroidBridge::ReportSystemInfoToServer()
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }
    env->CallStaticVoidMethod(cache.bridgeClass, cache.reportSystemInfoMethod);
}

// ==================== P0: 会话管理 ====================

void HelpBotUEAndroidBridge::CloseSession()
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }
    env->CallStaticVoidMethod(cache.bridgeClass, cache.closeSessionMethod);
}

void HelpBotUEAndroidBridge::Destroy()
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }
    env->CallStaticVoidMethod(cache.bridgeClass, cache.destroyMethod);
}

// ==================== P1: Issue 标签管理 ====================

void HelpBotUEAndroidBridge::AddIssueTags(const TArray<FString>& tags)
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }

    // 将 TArray<FString> 转换为 JSON 数组字符串
    FString jsonArray = TEXT("[");
    for (int32 i = 0; i < tags.Num(); ++i)
    {
        if (i > 0)
        {
            jsonArray += TEXT(",");
        }
        // 简单的 JSON 字符串转义（替换双引号和反斜杠）
        FString escaped = tags[i].Replace(TEXT("\\"), TEXT("\\\\")).Replace(TEXT("\""), TEXT("\\\""));
        jsonArray += TEXT("\"") + escaped + TEXT("\"");
    }
    jsonArray += TEXT("]");

    jstring jTags = env->NewStringUTF(TCHAR_TO_UTF8(*jsonArray));
    env->CallStaticVoidMethod(cache.bridgeClass, cache.addIssueTagsMethod, jTags);
    env->DeleteLocalRef(jTags);
}

void HelpBotUEAndroidBridge::RemoveIssueTags(const TArray<FString>& tags)
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        safeNotifyUnsupported();
        return;
    }

    // 将 TArray<FString> 转换为 JSON 数组字符串
    FString jsonArray = TEXT("[");
    for (int32 i = 0; i < tags.Num(); ++i)
    {
        if (i > 0)
        {
            jsonArray += TEXT(",");
        }
        FString escaped = tags[i].Replace(TEXT("\\"), TEXT("\\\\")).Replace(TEXT("\""), TEXT("\\\""));
        jsonArray += TEXT("\"") + escaped + TEXT("\"");
    }
    jsonArray += TEXT("]");

    jstring jTags = env->NewStringUTF(TCHAR_TO_UTF8(*jsonArray));
    env->CallStaticVoidMethod(cache.bridgeClass, cache.removeIssueTagsMethod, jTags);
    env->DeleteLocalRef(jTags);
}

// ==================== P1: SDK 信息查询 ====================

bool HelpBotUEAndroidBridge::IsInitialized()
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        return false;
    }
    return (bool)env->CallStaticBooleanMethod(cache.bridgeClass, cache.isInitializedMethod);
}

bool HelpBotUEAndroidBridge::IsConversationVisible()
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        return false;
    }
    return (bool)env->CallStaticBooleanMethod(cache.bridgeClass, cache.isConversationVisibleMethod);
}

bool HelpBotUEAndroidBridge::IsSseNotificationEnabled()
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        return false;
    }
    return (bool)env->CallStaticBooleanMethod(cache.bridgeClass, cache.isSseNotificationEnabledMethod);
}

FString HelpBotUEAndroidBridge::GetWebSdkHealthSnapshot()
{
    JNIEnv* env = FAndroidApplication::GetJavaEnv();
    if (!ensureCache(env))
    {
        return TEXT("{}");
    }

    jstring jSnapshot = static_cast<jstring>(env->CallStaticObjectMethod(cache.bridgeClass, cache.getWebSdkHealthSnapshotMethod));
    const FString out = jstringToFString(env, jSnapshot);
    if (jSnapshot != nullptr)
    {
        env->DeleteLocalRef(jSnapshot);
    }
    return out;
}

// ===========================
// Java -> C++ 事件回调（JNI）
// ===========================

extern "C"
{
    JNIEXPORT void JNICALL Java_com_helpbot_ue_HelpBotUEBridge_nativeOnEvent(JNIEnv* env, jclass /*clazz*/,
        jstring eventName, jstring payloadJson)
    {
        const FString eventNameStr = jstringToFString(env, eventName);
        const FString payloadStr = jstringToFString(env, payloadJson);

        AsyncTask(ENamedThreads::GameThread, [eventNameStr, payloadStr]()
        {
            if (UHelpBotUESubsystem* subsystem = UHelpBotUESubsystem::GetActive())
            {
                subsystem->OnHelpBotEvent.Broadcast(eventNameStr, payloadStr);
            }
        });
    }
}

#endif // PLATFORM_ANDROID


