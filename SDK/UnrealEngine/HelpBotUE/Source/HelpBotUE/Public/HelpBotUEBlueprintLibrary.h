#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "HelpBotUEBlueprintLibrary.generated.h"

/**
 * HelpBot UE 蓝图接口（Android 端通过 JNI 调用 AAR）。
 *
 * 注意：
 * - install/login 为异步：结果与错误通过 `HelpBotUESubsystem.OnHelpBotEvent` 事件回调派发。
 * - 事件名约定见 `HelpBotUEBridge.java`，以 `HB_` 前缀区分。
 */
UCLASS()
class HELPBOTUE_API UHelpBotUEBlueprintLibrary : public UBlueprintFunctionLibrary
{
    GENERATED_BODY()

public:
    /**
     * 初始化 SDK（异步）。
     *
     * @param channelId HelpBot channelId（必填）
     * @param domain    baseURL（必填，必须 https）
     * @param configJson 额外配置 JSON（可空，透传为 Map<String,Object>）
     */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE")
    static void Install(const FString& channelId, const FString& domain, const FString& configJson);

    /**
     * 登录（异步）。
     *
     * @param token identitiesJWT/preGeneratedToken（必填）
     * @param loginConfigJson 登录配置 JSON（可空）
     */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE")
    static void Login(const FString& token, const FString& loginConfigJson);

    /** 打开会话界面（需要先 install + login 成功）。 */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE")
    static void ShowConversation();

    /** 隐藏会话界面（不销毁会话）。 */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE")
    static void HideConversation();

    /** 登出（异步）。 */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE")
    static void Logout();

    /** 发送文本消息（异步）。 */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE")
    static void SendMessage(const FString& message);

    /** 是否启用 SSE 新消息通知。 */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE")
    static void EnableSseNotification(bool enable);

    /** 获取 SDK 版本（来自 Android SDK: HelpBot.getSDKVersion）。 */
    UFUNCTION(BlueprintPure, Category = "HelpBotUE")
    static FString GetSdkVersion();

    /** 是否当前平台支持（仅 Android）。 */
    UFUNCTION(BlueprintPure, Category = "HelpBotUE")
    static bool IsSupported();

    // ==================== P0: 历史消息功能 ====================
    
    /**
     * 获取历史消息（异步）。
     * 
     * 事件回调:
     * - HB_GET_HISTORY_MESSAGES_SUCCESS: 成功，payloadJson 包含消息数据
     * - HB_GET_HISTORY_MESSAGES_FAILURE: 失败，payloadJson 包含错误信息
     */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE|Messages")
    static void GetHistoryMessages();

    /**
     * 分页加载更多历史消息（异步）。
     * 
     * @param limit 每页消息数量
     * @param offset 偏移量
     * 
     * 事件回调:
     * - HB_LOAD_MORE_MESSAGES_SUCCESS: 成功
     * - HB_LOAD_MORE_MESSAGES_FAILURE: 失败
     */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE|Messages")
    static void LoadMoreMessages(int32 limit, int32 offset);

    // ==================== P0: FAQ 功能 ====================
    
    /**
     * 显示 FAQ 主页面（使用系统浏览器）。
     * 
     * @param configJson 配置 JSON（可空），例如: {"tn":"custom_value"}
     * 
     * 事件回调:
     * - HB_SHOW_FAQS_SUCCESS: 成功
     * - HB_SHOW_FAQS_FAILURE: 失败
     */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE|FAQ")
    static void ShowFAQs(const FString& configJson);

    /**
     * 显示 FAQ 主页面（简化版，使用默认配置）。
     */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE|FAQ")
    static void ShowFAQsSimple();

    /**
     * 显示 FAQ 文章分组页面。
     * 
     * @param sectionPublishId 分组 ID（必填）
     * @param configJson 配置 JSON（可空）
     * 
     * 事件回调:
     * - HB_SHOW_FAQ_SECTION_SUCCESS: 成功
     * - HB_SHOW_FAQ_SECTION_FAILURE: 失败
     */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE|FAQ")
    static void ShowFAQSection(const FString& sectionPublishId, const FString& configJson);

    /**
     * 显示 FAQ 文章分组页面（简化版）。
     */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE|FAQ")
    static void ShowFAQSectionSimple(const FString& sectionPublishId);

    /**
     * 显示单个 FAQ 问题页面。
     * 
     * @param questionPublishId 问题 ID（必填）
     * @param configJson 配置 JSON（可空）
     * 
     * 事件回调:
     * - HB_SHOW_SINGLE_FAQ_SUCCESS: 成功
     * - HB_SHOW_SINGLE_FAQ_FAILURE: 失败
     */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE|FAQ")
    static void ShowSingleFAQ(const FString& questionPublishId, const FString& configJson);

    /**
     * 显示单个 FAQ 问题页面（简化版）。
     */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE|FAQ")
    static void ShowSingleFAQSimple(const FString& questionPublishId);

    // ==================== P0: Meta 数据更新 ====================
    
    /**
     * 更新 SDK Meta 数据（同步）。
     * 
     * @param metaJson Meta 数据 JSON，例如: {"key1":"value1","key2":"value2"}
     * 
     * 事件回调:
     * - HB_UPDATE_SDK_META_SUCCESS: 成功
     * - HB_UPDATE_SDK_META_FAILURE: 失败
     */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE|Meta")
    static void UpdateSDKMeta(const FString& metaJson);

    /**
     * 更新用户自定义 Meta 数据（同步）。
     * 
     * @param customMetaJson 自定义 Meta 数据 JSON
     * 
     * 事件回调:
     * - HB_UPDATE_CUSTOM_META_SUCCESS: 成功
     * - HB_UPDATE_CUSTOM_META_FAILURE: 失败
     */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE|Meta")
    static void UpdateCustomMeta(const FString& customMetaJson);

    /**
     * 上报系统信息到服务器（同步）。
     * 
     * 说明: 自动采集设备信息（OS、设备型号、App版本等）并上报。
     * 
     * 事件回调:
     * - HB_REPORT_SYSTEM_INFO_SUCCESS: 成功
     * - HB_REPORT_SYSTEM_INFO_FAILURE: 失败
     */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE|Meta")
    static void ReportSystemInfoToServer();

    // ==================== P0: 会话管理 ====================
    
    /**
     * 关闭当前会话（同步）。
     * 
     * 说明: 关闭会话但不销毁 SDK，可以再次调用 ShowConversation 重新打开。
     * 
     * 事件回调:
     * - HB_CLOSE_SESSION_SUCCESS: 成功
     * - HB_CLOSE_SESSION_FAILURE: 失败
     */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE|Session")
    static void CloseSession();

    /**
     * 完全销毁 SDK，释放所有资源（同步）。
     * 
     * 说明: 调用后需要重新 Install 才能使用 SDK。
     * 
     * 事件回调:
     * - HB_DESTROY_SUCCESS: 成功
     * - HB_DESTROY_FAILURE: 失败
     */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE|Session")
    static void Destroy();

    // ==================== P1: Issue 标签管理 ====================
    
    /**
     * 添加 Issue 标签（同步）。
     * 
     * @param tags 标签数组
     * 
     * 事件回调:
     * - HB_ADD_ISSUE_TAGS_SUCCESS: 成功
     * - HB_ADD_ISSUE_TAGS_FAILURE: 失败
     */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE|Issue")
    static void AddIssueTags(const TArray<FString>& tags);

    /**
     * 移除 Issue 标签（同步）。
     * 
     * @param tags 标签数组
     * 
     * 事件回调:
     * - HB_REMOVE_ISSUE_TAGS_SUCCESS: 成功
     * - HB_REMOVE_ISSUE_TAGS_FAILURE: 失败
     */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE|Issue")
    static void RemoveIssueTags(const TArray<FString>& tags);

    // ==================== P1: SDK 信息查询 ====================
    
    /**
     * 是否已初始化（同步）。
     * 
     * @return true: 已初始化，false: 未初始化
     */
    UFUNCTION(BlueprintPure, Category = "HelpBotUE|Info")
    static bool IsInitialized();

    /**
     * 会话界面是否正在显示（同步）。
     * 
     * @return true: 正在显示，false: 未显示
     */
    UFUNCTION(BlueprintPure, Category = "HelpBotUE|Info")
    static bool IsConversationVisible();

    /**
     * SSE 通知是否已启用（同步）。
     * 
     * @return true: 已启用，false: 未启用
     */
    UFUNCTION(BlueprintPure, Category = "HelpBotUE|Info")
    static bool IsSseNotificationEnabled();

    /**
     * 获取 WebSDK 健康快照（同步）。
     * 
     * @return JSON 字符串，包含 WebSDK 健康状态数据
     */
    UFUNCTION(BlueprintCallable, Category = "HelpBotUE|Info")
    static FString GetWebSdkHealthSnapshot();
};


