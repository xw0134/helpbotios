#include "HelpBotSDKBlueprintLibrary.h"

#include "HelpBotSDK.h"

#include "Logging/LogMacros.h"

DEFINE_LOG_CATEGORY_STATIC(LogHelpBotSDK, Log, All);

void UHelpBotSDKBlueprintLibrary::Install(const FString& ChannelId, const FString& Domain)
{
	if (!FHelpBotSDKModule::IsAvailable())
	{
		UE_LOG(LogHelpBotSDK, Warning, TEXT("[HelpBot] HelpBotSDK module not available"));
		return;
	}
	UE_LOG(LogHelpBotSDK, Log, TEXT("[HelpBot] Install: channelId=%s domain=%s"), *ChannelId, *Domain);
	FHelpBotSDKModule::Get().Install(ChannelId, Domain);
}

void UHelpBotSDKBlueprintLibrary::Login(const FString& JwtToken)
{
	if (!FHelpBotSDKModule::IsAvailable())
	{
		UE_LOG(LogHelpBotSDK, Warning, TEXT("[HelpBot] HelpBotSDK module not available"));
		return;
	}
	UE_LOG(LogHelpBotSDK, Log, TEXT("[HelpBot] Login: token=<masked>"));
	FHelpBotSDKModule::Get().Login(JwtToken);
}

void UHelpBotSDKBlueprintLibrary::ShowConversation()
{
	if (!FHelpBotSDKModule::IsAvailable())
	{
		UE_LOG(LogHelpBotSDK, Warning, TEXT("[HelpBot] HelpBotSDK module not available"));
		return;
	}
	UE_LOG(LogHelpBotSDK, Log, TEXT("[HelpBot] ShowConversation"));
	FHelpBotSDKModule::Get().ShowConversation();
}

FString UHelpBotSDKBlueprintLibrary::GetDefaultChannelId()
{
	return TEXT("appc-20251126114209416-ptvea1y414vey36");
}

FString UHelpBotSDKBlueprintLibrary::GetDefaultDomain()
{
	// 对齐 Android Demo：允许仅 host，由 Android SDK 自动补全为 https://
	return TEXT("dev-bot-server.yuedongcs.com");
}

FString UHelpBotSDKBlueprintLibrary::GetDefaultTokenUrl()
{
	return TEXT("https://dev-bot-server.yuedongcs.com:8123/generate_token");
}

FString UHelpBotSDKBlueprintLibrary::GetDefaultIdentityIdentifier()
{
	return TEXT("uid");
}

FString UHelpBotSDKBlueprintLibrary::GetDefaultIdentityValue()
{
	return TEXT("123456789");
}

void UHelpBotSDKBlueprintLibrary::ShowFAQs()
{
	if (!FHelpBotSDKModule::IsAvailable())
	{
		UE_LOG(LogHelpBotSDK, Warning, TEXT("[HelpBot] HelpBotSDK module not available"));
		return;
	}
	UE_LOG(LogHelpBotSDK, Log, TEXT("[HelpBot] ShowFAQs"));
	// TODO: 实现 ShowFAQs 功能
}

void UHelpBotSDKBlueprintLibrary::UpdateCustomMeta(const TMap<FString, FString>& MetaData)
{
	if (!FHelpBotSDKModule::IsAvailable())
	{
		UE_LOG(LogHelpBotSDK, Warning, TEXT("[HelpBot] HelpBotSDK module not available"));
		return;
	}
	UE_LOG(LogHelpBotSDK, Log, TEXT("[HelpBot] UpdateCustomMeta with %d entries"), MetaData.Num());
	for (const auto& Pair : MetaData)
	{
		UE_LOG(LogHelpBotSDK, Log, TEXT("  %s = %s"), *Pair.Key, *Pair.Value);
	}
	// TODO: 实现 UpdateCustomMeta 功能
}

FString UHelpBotSDKBlueprintLibrary::GetSDKVersion()
{
	return TEXT("0.1.13");
}

bool UHelpBotSDKBlueprintLibrary::IsInitialized()
{
	// TODO: 实现状态检查
	return FHelpBotSDKModule::IsAvailable();
}



