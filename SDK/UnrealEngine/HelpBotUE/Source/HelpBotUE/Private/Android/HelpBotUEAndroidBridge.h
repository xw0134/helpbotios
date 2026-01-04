#pragma once

#include "CoreMinimal.h"

/**
 * Android JNI 桥（C++ -> Java）。
 *
 * 说明：
 * - Java 侧桥类：com.helpbot.ue.HelpBotUEBridge
 * - 该桥类内部再调用 Android AAR: com.example.HelpBot.HelpBot
 */
class HelpBotUEAndroidBridge
{
public:
    static void Install(const FString& channelId, const FString& domain, const FString& configJson);
    static void Login(const FString& token, const FString& loginConfigJson);
    static void ShowConversation();
    static void HideConversation();
    static void Logout();
    static void SendMessage(const FString& message);
    static void EnableSseNotification(bool enable);
    static FString GetSdkVersion();

    // ==================== P0: 历史消息功能 ====================
    static void GetHistoryMessages();
    static void LoadMoreMessages(int32 limit, int32 offset);

    // ==================== P0: FAQ 功能 ====================
    static void ShowFAQs(const FString& configJson);
    static void ShowFAQsSimple();
    static void ShowFAQSection(const FString& sectionPublishId, const FString& configJson);
    static void ShowFAQSectionSimple(const FString& sectionPublishId);
    static void ShowSingleFAQ(const FString& questionPublishId, const FString& configJson);
    static void ShowSingleFAQSimple(const FString& questionPublishId);

    // ==================== P0: Meta 数据更新 ====================
    static void UpdateSDKMeta(const FString& metaJson);
    static void UpdateCustomMeta(const FString& customMetaJson);
    static void ReportSystemInfoToServer();

    // ==================== P0: 会话管理 ====================
    static void CloseSession();
    static void Destroy();

    // ==================== P1: Issue 标签管理 ====================
    static void AddIssueTags(const TArray<FString>& tags);
    static void RemoveIssueTags(const TArray<FString>& tags);

    // ==================== P1: SDK 信息查询 ====================
    static bool IsInitialized();
    static bool IsConversationVisible();
    static bool IsSseNotificationEnabled();
    static FString GetWebSdkHealthSnapshot();
};


