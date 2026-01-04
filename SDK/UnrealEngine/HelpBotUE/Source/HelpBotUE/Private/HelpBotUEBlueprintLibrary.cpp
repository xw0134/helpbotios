#include "HelpBotUEBlueprintLibrary.h"

#include "HelpBotUESubsystem.h"

#if PLATFORM_ANDROID
#include "Android/HelpBotUEAndroidBridge.h"
#endif

void UHelpBotUEBlueprintLibrary::Install(const FString& channelId, const FString& domain, const FString& configJson)
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::Install(channelId, domain, configJson);
#else
    if (UHelpBotUESubsystem* subsystem = UHelpBotUESubsystem::GetActive())
    {
        subsystem->DispatchEventOnGameThread(TEXT("HB_UNSUPPORTED_PLATFORM"), TEXT("{\"platform\":\"non-android\"}"));
    }
#endif
}

void UHelpBotUEBlueprintLibrary::Login(const FString& token, const FString& loginConfigJson)
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::Login(token, loginConfigJson);
#else
    if (UHelpBotUESubsystem* subsystem = UHelpBotUESubsystem::GetActive())
    {
        subsystem->DispatchEventOnGameThread(TEXT("HB_UNSUPPORTED_PLATFORM"), TEXT("{\"platform\":\"non-android\"}"));
    }
#endif
}

void UHelpBotUEBlueprintLibrary::ShowConversation()
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::ShowConversation();
#endif
}

void UHelpBotUEBlueprintLibrary::HideConversation()
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::HideConversation();
#endif
}

void UHelpBotUEBlueprintLibrary::Logout()
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::Logout();
#endif
}

void UHelpBotUEBlueprintLibrary::SendMessage(const FString& message)
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::SendMessage(message);
#endif
}

void UHelpBotUEBlueprintLibrary::EnableSseNotification(const bool enable)
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::EnableSseNotification(enable);
#endif
}

FString UHelpBotUEBlueprintLibrary::GetSdkVersion()
{
#if PLATFORM_ANDROID
    return HelpBotUEAndroidBridge::GetSdkVersion();
#else
    return TEXT("");
#endif
}

bool UHelpBotUEBlueprintLibrary::IsSupported()
{
#if PLATFORM_ANDROID
    return true;
#else
    return false;
#endif
}

// ==================== P0: 历史消息功能 ====================

void UHelpBotUEBlueprintLibrary::GetHistoryMessages()
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::GetHistoryMessages();
#endif
}

void UHelpBotUEBlueprintLibrary::LoadMoreMessages(int32 limit, int32 offset)
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::LoadMoreMessages(limit, offset);
#endif
}

// ==================== P0: FAQ 功能 ====================

void UHelpBotUEBlueprintLibrary::ShowFAQs(const FString& configJson)
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::ShowFAQs(configJson);
#endif
}

void UHelpBotUEBlueprintLibrary::ShowFAQsSimple()
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::ShowFAQsSimple();
#endif
}

void UHelpBotUEBlueprintLibrary::ShowFAQSection(const FString& sectionPublishId, const FString& configJson)
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::ShowFAQSection(sectionPublishId, configJson);
#endif
}

void UHelpBotUEBlueprintLibrary::ShowFAQSectionSimple(const FString& sectionPublishId)
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::ShowFAQSectionSimple(sectionPublishId);
#endif
}

void UHelpBotUEBlueprintLibrary::ShowSingleFAQ(const FString& questionPublishId, const FString& configJson)
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::ShowSingleFAQ(questionPublishId, configJson);
#endif
}

void UHelpBotUEBlueprintLibrary::ShowSingleFAQSimple(const FString& questionPublishId)
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::ShowSingleFAQSimple(questionPublishId);
#endif
}

// ==================== P0: Meta 数据更新 ====================

void UHelpBotUEBlueprintLibrary::UpdateSDKMeta(const FString& metaJson)
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::UpdateSDKMeta(metaJson);
#endif
}

void UHelpBotUEBlueprintLibrary::UpdateCustomMeta(const FString& customMetaJson)
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::UpdateCustomMeta(customMetaJson);
#endif
}

void UHelpBotUEBlueprintLibrary::ReportSystemInfoToServer()
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::ReportSystemInfoToServer();
#endif
}

// ==================== P0: 会话管理 ====================

void UHelpBotUEBlueprintLibrary::CloseSession()
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::CloseSession();
#endif
}

void UHelpBotUEBlueprintLibrary::Destroy()
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::Destroy();
#endif
}

// ==================== P1: Issue 标签管理 ====================

void UHelpBotUEBlueprintLibrary::AddIssueTags(const TArray<FString>& tags)
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::AddIssueTags(tags);
#endif
}

void UHelpBotUEBlueprintLibrary::RemoveIssueTags(const TArray<FString>& tags)
{
#if PLATFORM_ANDROID
    HelpBotUEAndroidBridge::RemoveIssueTags(tags);
#endif
}

// ==================== P1: SDK 信息查询 ====================

bool UHelpBotUEBlueprintLibrary::IsInitialized()
{
#if PLATFORM_ANDROID
    return HelpBotUEAndroidBridge::IsInitialized();
#else
    return false;
#endif
}

bool UHelpBotUEBlueprintLibrary::IsConversationVisible()
{
#if PLATFORM_ANDROID
    return HelpBotUEAndroidBridge::IsConversationVisible();
#else
    return false;
#endif
}

bool UHelpBotUEBlueprintLibrary::IsSseNotificationEnabled()
{
#if PLATFORM_ANDROID
    return HelpBotUEAndroidBridge::IsSseNotificationEnabled();
#else
    return false;
#endif
}

FString UHelpBotUEBlueprintLibrary::GetWebSdkHealthSnapshot()
{
#if PLATFORM_ANDROID
    return HelpBotUEAndroidBridge::GetWebSdkHealthSnapshot();
#else
    return TEXT("{}");
#endif
}



