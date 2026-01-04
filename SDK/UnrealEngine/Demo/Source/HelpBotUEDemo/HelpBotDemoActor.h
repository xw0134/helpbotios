#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "HelpBotDemoActor.generated.h"

class UHelpBotUESubsystem;

/**
 * Demo Actor：演示 install -> login -> showConversation 的事件驱动链路。
 *
 * 使用方式：
 * - 将该 Actor 放到关卡中
 * - 填写 channelId/domain/token
 * - Android 运行后会在日志中看到 HB_* 事件
 */
UCLASS()
class HELPBOTUEDEMO_API AHelpBotDemoActor : public AActor
{
    GENERATED_BODY()

public:
    AHelpBotDemoActor();

protected:
    virtual void BeginPlay() override;

    UFUNCTION()
    void onHelpBotEvent(const FString& eventName, const FString& payloadJson);

    /** HelpBot 渠道 ID */
    UPROPERTY(EditAnywhere, Category = "HelpBot")
    FString channelId;

    /** 业务域名 baseURL（必须 https） */
    UPROPERTY(EditAnywhere, Category = "HelpBot")
    FString domain;

    /** 后端下发 identitiesJWT */
    UPROPERTY(EditAnywhere, Category = "HelpBot")
    FString token;

    /** install 额外配置 JSON（可空） */
    UPROPERTY(EditAnywhere, Category = "HelpBot")
    FString installConfigJson;

    /** login 额外配置 JSON（可空） */
    UPROPERTY(EditAnywhere, Category = "HelpBot")
    FString loginConfigJson;

private:
    bool installDone = false;
    bool loginDone = false;
};


