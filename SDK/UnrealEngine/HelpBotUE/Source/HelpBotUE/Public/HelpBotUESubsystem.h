#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "HelpBotUESubsystem.generated.h"

/** HelpBot 通用事件：eventName + payloadJson（JSON 字符串）。 */
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FHelpBotOnEvent, const FString&, eventName, const FString&, payloadJson);

/**
 * HelpBot UE 事件分发子系统（建议在 GameInstance 生命周期内使用）。
 *
 * 设计说明：
 * - Android 侧事件通过 JNI 进入 C++，再切换到 GameThread 广播给蓝图/业务层。
 * - 事件名与 payloadJson 均为“透传”，保持 SDK 扩展性（事件驱动）。
 */
UCLASS()
class HELPBOTUE_API UHelpBotUESubsystem : public UGameInstanceSubsystem
{
    GENERATED_BODY()

public:
    /** 通用事件：eventName 由 Android SDK/WebSDK 定义；payloadJson 为 JSON 字符串（可能为空）。 */
    UPROPERTY(BlueprintAssignable, Category = "HelpBotUE|Events")
    FHelpBotOnEvent OnHelpBotEvent;

    virtual void Initialize(FSubsystemCollectionBase& collection) override;
    virtual void Deinitialize() override;

    /** 内部使用：获取当前激活 Subsystem（用于 JNI 回调） */
    static UHelpBotUESubsystem* GetActive();

    /** 内部使用：派发事件（JNI 回调将调用） */
    void DispatchEventOnGameThread(const FString& eventName, const FString& payloadJson);

private:
    static TWeakObjectPtr<UHelpBotUESubsystem> activeInstance;
};


