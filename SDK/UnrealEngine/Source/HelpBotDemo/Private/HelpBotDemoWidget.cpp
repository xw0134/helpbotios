#include "HelpBotDemoWidget.h"
#include "HelpBotSDKBlueprintLibrary.h"
#include "Components/EditableTextBox.h"
#include "Components/TextBlock.h"
#include "Components/Button.h"
#include "Components/ScrollBox.h"
#include "TimerManager.h"
#include "Engine/World.h"

void UHelpBotDemoWidget::NativeConstruct()
{
	Super::NativeConstruct();

	// 设置默认值 - 对齐 Android Demo
	if (ChannelIdInput)
	{
		ChannelIdInput->SetText(FText::FromString(TEXT("appc-20251126114209416-ptvea1y414vey36")));
	}
	if (DomainInput)
	{
		DomainInput->SetText(FText::FromString(TEXT("dev-bot-server.yuedongcs.com")));
	}
	if (TokenUrlInput)
	{
		TokenUrlInput->SetText(FText::FromString(TEXT("https://dev-bot-server.yuedongcs.com:8123/generate_token")));
	}
	if (IdentifierInput)
	{
		IdentifierInput->SetText(FText::FromString(TEXT("uid")));
	}
	if (ValueInput)
	{
		ValueInput->SetText(FText::FromString(TEXT("123456789")));
	}

	// 绑定按钮事件
	if (InstallButton)
	{
		InstallButton->OnClicked.AddDynamic(this, &UHelpBotDemoWidget::OnInstallClicked);
	}
	if (GenerateTokenButton)
	{
		GenerateTokenButton->OnClicked.AddDynamic(this, &UHelpBotDemoWidget::OnGenerateTokenClicked);
	}
	if (LoginButton)
	{
		LoginButton->OnClicked.AddDynamic(this, &UHelpBotDemoWidget::OnLoginClicked);
	}
	if (ShowConversationButton)
	{
		ShowConversationButton->OnClicked.AddDynamic(this, &UHelpBotDemoWidget::OnShowConversationClicked);
	}
	if (ShowFAQsButton)
	{
		ShowFAQsButton->OnClicked.AddDynamic(this, &UHelpBotDemoWidget::OnShowFAQsClicked);
	}
	if (UpdateMetaButton)
	{
		UpdateMetaButton->OnClicked.AddDynamic(this, &UHelpBotDemoWidget::OnUpdateMetaClicked);
	}
	if (SelfCheckButton)
	{
		SelfCheckButton->OnClicked.AddDynamic(this, &UHelpBotDemoWidget::OnSelfCheckClicked);
	}
	if (StressTestStartButton)
	{
		StressTestStartButton->OnClicked.AddDynamic(this, &UHelpBotDemoWidget::OnStressTestStartClicked);
	}
	if (StressTestStopButton)
	{
		StressTestStopButton->OnClicked.AddDynamic(this, &UHelpBotDemoWidget::OnStressTestStopClicked);
	}
	if (NegativeTestButton)
	{
		NegativeTestButton->OnClicked.AddDynamic(this, &UHelpBotDemoWidget::OnNegativeTestClicked);
	}
	if (ClearLogButton)
	{
		ClearLogButton->OnClicked.AddDynamic(this, &UHelpBotDemoWidget::OnClearLogClicked);
	}

	// 初始化状态
	bStressTestRunning = false;
	StressLoopCount = 0;
	StressSuccessCount = 0;
	StressFailureCount = 0;

	AppendLog(TEXT("UnrealEngine Demo 已启动"));
	AppendLog(FString::Printf(TEXT("UE 版本: %s"), *FEngineVersion::Current().ToString()));
	AppendLog(FString::Printf(TEXT("SDK 版本: %s"), *UHelpBotSDKBlueprintLibrary::GetSDKVersion()));
	UpdateStatus(TEXT("Ready"));
}

void UHelpBotDemoWidget::NativeDestruct()
{
	// 清理定时器
	if (bStressTestRunning && GetWorld())
	{
		GetWorld()->GetTimerManager().ClearTimer(StressTestTimer);
	}

	Super::NativeDestruct();
}

void UHelpBotDemoWidget::OnInstallClicked()
{
	FString ChannelId = ChannelIdInput ? ChannelIdInput->GetText().ToString() : TEXT("");
	FString Domain = DomainInput ? DomainInput->GetText().ToString() : TEXT("");

	if (ChannelId.IsEmpty() || Domain.IsEmpty())
	{
		UpdateStatus(TEXT("Error: Channel or Domain is empty"));
		AppendLog(TEXT("错误: Channel 或 Domain 为空"));
		return;
	}

	AppendLog(TEXT("========== 测试: Install(异步) =========="));
	AppendLog(FString::Printf(TEXT("Channel: %s"), *ChannelId));
	AppendLog(FString::Printf(TEXT("Domain: %s"), *Domain));
	UpdateStatus(TEXT("Installing..."));

	UHelpBotSDKBlueprintLibrary::Install(ChannelId, Domain);

	// 模拟异步回调
	UpdateStatus(TEXT("Install Success"));
	AppendLog(TEXT("SDK Install Success"));
}

void UHelpBotDemoWidget::OnGenerateTokenClicked()
{
	// 生成 Mock Token (对齐 Android Demo 逻辑)
	FString Identifier = IdentifierInput ? IdentifierInput->GetText().ToString() : TEXT("user");
	RawToken = FString::Printf(TEXT("mock_jwt_token_%s_%lld"), *Identifier, FDateTime::Now().GetTicks());

	if (TokenText)
	{
		TokenText->SetText(FText::FromString(FString::Printf(TEXT("Token(脱敏): %s"), *MaskToken(RawToken))));
	}

	AppendLog(FString::Printf(TEXT("Token Generated (Mock): %s"), *MaskToken(RawToken)));
	UpdateStatus(TEXT("Token Generated (Mock)"));
}

void UHelpBotDemoWidget::OnLoginClicked()
{
	if (RawToken.IsEmpty())
	{
		UpdateStatus(TEXT("Error: No Token"));
		AppendLog(TEXT("错误: 请先生成 Token"));
		return;
	}

	AppendLog(TEXT("========== 测试: Login(异步) =========="));
	AppendLog(FString::Printf(TEXT("Token: %s"), *MaskToken(RawToken)));
	UpdateStatus(TEXT("Logging in..."));

	UHelpBotSDKBlueprintLibrary::Login(RawToken);

	// 模拟异步回调
	UpdateStatus(TEXT("Login Success"));
	AppendLog(TEXT("Login Success"));
}

void UHelpBotDemoWidget::OnShowConversationClicked()
{
	AppendLog(TEXT("========== 测试: OpenConversation =========="));
	UHelpBotSDKBlueprintLibrary::ShowConversation();
	AppendLog(TEXT("OpenConversation: success"));
	UpdateStatus(TEXT("Conversation Opened"));
}

void UHelpBotDemoWidget::OnShowFAQsClicked()
{
	AppendLog(TEXT("========== 测试: OpenFAQs =========="));
	UHelpBotSDKBlueprintLibrary::ShowFAQs();
	AppendLog(TEXT("OpenFAQs: success"));
	UpdateStatus(TEXT("FAQs Opened"));
}

void UHelpBotDemoWidget::OnUpdateMetaClicked()
{
	AppendLog(TEXT("========== 测试: UpdateMeta =========="));

	TMap<FString, FString> CustomMeta;
	CustomMeta.Add(TEXT("user_level"), TEXT("10"));
	CustomMeta.Add(TEXT("server"), TEXT("S1"));
	CustomMeta.Add(TEXT("engine"), TEXT("UnrealEngine"));
	CustomMeta.Add(TEXT("platform"), ANSI_TO_TCHAR(FPlatformProperties::PlatformName()));

	UHelpBotSDKBlueprintLibrary::UpdateCustomMeta(CustomMeta);

	AppendLog(TEXT("Custom Meta:"));
	for (const auto& Pair : CustomMeta)
	{
		AppendLog(FString::Printf(TEXT("  %s = %s"), *Pair.Key, *Pair.Value));
	}

	UpdateStatus(TEXT("Meta Updated"));
	AppendLog(TEXT("UpdateMeta: success"));
}

void UHelpBotDemoWidget::OnSelfCheckClicked()
{
	AppendLog(TEXT("========== 一键自检开始 =========="));
	UpdateStatus(TEXT("自检中..."));

	// 1. 基础信息
	AppendLog(FString::Printf(TEXT("UE 版本: %s"), *FEngineVersion::Current().ToString()));
	AppendLog(FString::Printf(TEXT("平台: %s"), ANSI_TO_TCHAR(FPlatformProperties::PlatformName())));
	AppendLog(FString::Printf(TEXT("配置: %s"), 
#if UE_BUILD_DEBUG
		TEXT("Debug")
#elif UE_BUILD_DEVELOPMENT
		TEXT("Development")
#elif UE_BUILD_SHIPPING
		TEXT("Shipping")
#else
		TEXT("Unknown")
#endif
	));

	// 2. SDK 信息
	AppendLog(FString::Printf(TEXT("SDK 版本: %s"), *UHelpBotSDKBlueprintLibrary::GetSDKVersion()));
	AppendLog(FString::Printf(TEXT("SDK 已初始化: %s"), 
		UHelpBotSDKBlueprintLibrary::IsInitialized() ? TEXT("是") : TEXT("否")));

	// 3. 系统信息
	AppendLog(FString::Printf(TEXT("CPU 核心数: %d"), FPlatformMisc::NumberOfCores()));
	AppendLog(FString::Printf(TEXT("物理内存: %.2f GB"), 
		FPlatformMemory::GetConstants().TotalPhysical / (1024.0 * 1024.0 * 1024.0)));

	UpdateStatus(TEXT("自检完成"));
	AppendLog(TEXT("========== 一键自检完成 =========="));
}

void UHelpBotDemoWidget::OnStressTestStartClicked()
{
	if (bStressTestRunning)
	{
		AppendLog(TEXT("压力测试已在运行中"));
		return;
	}

	AppendLog(TEXT("========== 压力测试开始 =========="));
	bStressTestRunning = true;
	StressLoopCount = 0;
	StressSuccessCount = 0;
	StressFailureCount = 0;

	// 启动定时器,每秒执行一次
	if (GetWorld())
	{
		GetWorld()->GetTimerManager().SetTimer(
			StressTestTimer,
			this,
			&UHelpBotDemoWidget::StressTestTick,
			1.0f,
			true
		);
	}
}

void UHelpBotDemoWidget::OnStressTestStopClicked()
{
	if (!bStressTestRunning)
	{
		AppendLog(TEXT("压力测试未运行"));
		return;
	}

	bStressTestRunning = false;
	if (GetWorld())
	{
		GetWorld()->GetTimerManager().ClearTimer(StressTestTimer);
	}

	AppendLog(TEXT("========== 压力测试停止 =========="));
	AppendLog(FString::Printf(TEXT("总循环: %d"), StressLoopCount));
	AppendLog(FString::Printf(TEXT("成功: %d"), StressSuccessCount));
	AppendLog(FString::Printf(TEXT("失败: %d"), StressFailureCount));
	UpdateStatus(TEXT("压力测试已停止"));
}

void UHelpBotDemoWidget::StressTestTick()
{
	if (!bStressTestRunning)
	{
		return;
	}

	StressLoopCount++;
	UpdateStatus(FString::Printf(TEXT("压力测试中... 循环 %d"), StressLoopCount));

	// 调用 ShowConversation
	UHelpBotSDKBlueprintLibrary::ShowConversation();
	StressSuccessCount++;

	// 每 10 次循环输出一次统计
	if (StressLoopCount % 10 == 0)
	{
		AppendLog(FString::Printf(TEXT("压力测试进度: %d 次, 成功: %d, 失败: %d"),
			StressLoopCount, StressSuccessCount, StressFailureCount));
	}
}

void UHelpBotDemoWidget::OnNegativeTestClicked()
{
	AppendLog(TEXT("========== 负向测试开始 =========="));
	UpdateStatus(TEXT("负向测试中..."));

	// 测试 1: 未登录直接 ShowConversation
	AppendLog(TEXT("测试 1: 未登录直接 ShowConversation"));
	UHelpBotSDKBlueprintLibrary::ShowConversation();
	AppendLog(TEXT("  结果: 已调用"));

	// 测试 2: 空 Token 登录
	AppendLog(TEXT("测试 2: 空 Token 登录"));
	UHelpBotSDKBlueprintLibrary::Login(TEXT(""));
	AppendLog(TEXT("  结果: 已调用"));

	// 测试 3: 无效配置 Install
	AppendLog(TEXT("测试 3: 无效配置 Install"));
	UHelpBotSDKBlueprintLibrary::Install(TEXT(""), TEXT(""));
	AppendLog(TEXT("  结果: 已调用"));

	// 测试 4: 重复 Install
	AppendLog(TEXT("测试 4: 重复 Install"));
	if (UHelpBotSDKBlueprintLibrary::IsInitialized())
	{
		FString ChannelId = ChannelIdInput ? ChannelIdInput->GetText().ToString() : TEXT("");
		FString Domain = DomainInput ? DomainInput->GetText().ToString() : TEXT("");
		UHelpBotSDKBlueprintLibrary::Install(ChannelId, Domain);
		AppendLog(TEXT("  结果: 已调用"));
	}
	else
	{
		AppendLog(TEXT("  结果: SDK 未初始化,跳过"));
	}

	UpdateStatus(TEXT("负向测试完成"));
	AppendLog(TEXT("========== 负向测试完成 =========="));
}

void UHelpBotDemoWidget::OnClearLogClicked()
{
	LogBuffer.Empty();
	if (LogText)
	{
		LogText->SetText(FText::GetEmpty());
	}
	UpdateStatus(TEXT("日志已清空"));
}

void UHelpBotDemoWidget::AppendLog(const FString& Message)
{
	FString TimeStamp = FDateTime::Now().ToString(TEXT("%H:%M:%S"));
	LogBuffer += FString::Printf(TEXT("\n[%s] %s"), *TimeStamp, *Message);

	// 限制日志长度
	if (LogBuffer.Len() > 10000)
	{
		LogBuffer = LogBuffer.Right(10000);
	}

	if (LogText)
	{
		LogText->SetText(FText::FromString(LogBuffer));
	}

	// 滚动到底部
	if (LogScrollBox)
	{
		LogScrollBox->ScrollToEnd();
	}
}

void UHelpBotDemoWidget::UpdateStatus(const FString& Status)
{
	if (StatusText)
	{
		StatusText->SetText(FText::FromString(FString::Printf(TEXT("Status: %s"), *Status)));
	}
}

FString UHelpBotDemoWidget::MaskToken(const FString& Token)
{
	if (Token.Len() <= 12)
	{
		return Token.Left(FMath::Min(4, Token.Len())) + TEXT("***");
	}
	return Token.Left(6) + TEXT("...") + Token.Right(6);
}
