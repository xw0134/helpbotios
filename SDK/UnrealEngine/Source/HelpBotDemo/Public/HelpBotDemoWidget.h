#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "Components/EditableTextBox.h"
#include "Components/TextBlock.h"
#include "Components/Button.h"
#include "Components/ScrollBox.h"
#include "HelpBotDemoWidget.generated.h"

/**
 * HelpBot Demo 主界面 Widget
 * 实现与 Android/Unity/Cocos2d 相同的功能
 */
UCLASS()
class HELPBOTDEMO_API UHelpBotDemoWidget : public UUserWidget
{
	GENERATED_BODY()

protected:
	virtual void NativeConstruct() override;
	virtual void NativeDestruct() override;

public:
	// UI 组件 - 输入字段
	UPROPERTY(meta = (BindWidget))
	UEditableTextBox* ChannelIdInput;

	UPROPERTY(meta = (BindWidget))
	UEditableTextBox* DomainInput;

	UPROPERTY(meta = (BindWidget))
	UEditableTextBox* TokenUrlInput;

	UPROPERTY(meta = (BindWidget))
	UEditableTextBox* IdentifierInput;

	UPROPERTY(meta = (BindWidget))
	UEditableTextBox* ValueInput;

	// UI 组件 - 按钮
	UPROPERTY(meta = (BindWidget))
	UButton* InstallButton;

	UPROPERTY(meta = (BindWidget))
	UButton* GenerateTokenButton;

	UPROPERTY(meta = (BindWidget))
	UButton* LoginButton;

	UPROPERTY(meta = (BindWidget))
	UButton* ShowConversationButton;

	UPROPERTY(meta = (BindWidget))
	UButton* ShowFAQsButton;

	UPROPERTY(meta = (BindWidget))
	UButton* UpdateMetaButton;

	UPROPERTY(meta = (BindWidget))
	UButton* SelfCheckButton;

	UPROPERTY(meta = (BindWidget))
	UButton* StressTestStartButton;

	UPROPERTY(meta = (BindWidget))
	UButton* StressTestStopButton;

	UPROPERTY(meta = (BindWidget))
	UButton* NegativeTestButton;

	UPROPERTY(meta = (BindWidget))
	UButton* ClearLogButton;

	// UI 组件 - 显示区域
	UPROPERTY(meta = (BindWidget))
	UTextBlock* StatusText;

	UPROPERTY(meta = (BindWidget))
	UTextBlock* TokenText;

	UPROPERTY(meta = (BindWidget))
	UScrollBox* LogScrollBox;

	UPROPERTY(meta = (BindWidget))
	UTextBlock* LogText;

private:
	// 按钮回调
	UFUNCTION()
	void OnInstallClicked();

	UFUNCTION()
	void OnGenerateTokenClicked();

	UFUNCTION()
	void OnLoginClicked();

	UFUNCTION()
	void OnShowConversationClicked();

	UFUNCTION()
	void OnShowFAQsClicked();

	UFUNCTION()
	void OnUpdateMetaClicked();

	UFUNCTION()
	void OnSelfCheckClicked();

	UFUNCTION()
	void OnStressTestStartClicked();

	UFUNCTION()
	void OnStressTestStopClicked();

	UFUNCTION()
	void OnNegativeTestClicked();

	UFUNCTION()
	void OnClearLogClicked();

	// 辅助函数
	void AppendLog(const FString& Message);
	void UpdateStatus(const FString& Status);
	FString MaskToken(const FString& Token);
	void StressTestTick();

	// 状态变量
	FString RawToken;
	FString LogBuffer;
	bool bStressTestRunning;
	int32 StressLoopCount;
	int32 StressSuccessCount;
	int32 StressFailureCount;
	FTimerHandle StressTestTimer;
};
