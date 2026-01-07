#pragma once

#include "Kismet/BlueprintFunctionLibrary.h"
#include "HelpBotSDKBlueprintLibrary.generated.h"

/**
 * HelpBotSDKBlueprintLibrary
 *
 * 用途：
 * - 让 UnrealEngine Demo 在蓝图侧即可调用 HelpBot（对齐 Android Demo 的“Install/Login/OpenConversation”流程）
 * - 便于快速验证 SDK 行为与参数对齐
 */
UCLASS()
class HELPBOTSDK_API UHelpBotSDKBlueprintLibrary : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	/** SDK 初始化（Install） */
	UFUNCTION(BlueprintCallable, Category="HelpBot")
	static void Install(const FString& ChannelId, const FString& Domain);

	/** 用户登录（Login） */
	UFUNCTION(BlueprintCallable, Category="HelpBot")
	static void Login(const FString& JwtToken);

	/** 打开会话（OpenConversation） */
	UFUNCTION(BlueprintCallable, Category="HelpBot")
	static void ShowConversation();

	/** 打开 FAQ 列表 */
	UFUNCTION(BlueprintCallable, Category="HelpBot")
	static void ShowFAQs();

	/** 更新自定义元数据 */
	UFUNCTION(BlueprintCallable, Category="HelpBot")
	static void UpdateCustomMeta(const TMap<FString, FString>& MetaData);

	/** 获取 SDK 版本 */
	UFUNCTION(BlueprintPure, Category="HelpBot")
	static FString GetSDKVersion();

	/** 检查 SDK 是否已初始化 */
	UFUNCTION(BlueprintPure, Category="HelpBot")
	static bool IsInitialized();

	/** Android Demo 默认参数（便于一键对齐验证） */
	UFUNCTION(BlueprintPure, Category="HelpBot|Defaults")
	static FString GetDefaultChannelId();

	UFUNCTION(BlueprintPure, Category="HelpBot|Defaults")
	static FString GetDefaultDomain();

	UFUNCTION(BlueprintPure, Category="HelpBot|Defaults")
	static FString GetDefaultTokenUrl();

	UFUNCTION(BlueprintPure, Category="HelpBot|Defaults")
	static FString GetDefaultIdentityIdentifier();

	UFUNCTION(BlueprintPure, Category="HelpBot|Defaults")
	static FString GetDefaultIdentityValue();
};


