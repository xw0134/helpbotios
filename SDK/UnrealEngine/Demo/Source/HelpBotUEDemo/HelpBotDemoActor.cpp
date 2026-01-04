#include "HelpBotDemoActor.h"

#include "HelpBotUEBlueprintLibrary.h"
#include "HelpBotUESubsystem.h"
#include "Engine/GameInstance.h"
#include "Kismet/GameplayStatics.h"

AHelpBotDemoActor::AHelpBotDemoActor()
{
    PrimaryActorTick.bCanEverTick = false;
}

void AHelpBotDemoActor::BeginPlay()
{
    Super::BeginPlay();

    if (!UHelpBotUEBlueprintLibrary::IsSupported())
    {
        UE_LOG(LogTemp, Warning, TEXT("[HelpBotDemo] 当前平台非 Android，Demo 不执行"));
        return;
    }

    UGameInstance* gameInstance = UGameplayStatics::GetGameInstance(this);
    if (gameInstance == nullptr)
    {
        UE_LOG(LogTemp, Error, TEXT("[HelpBotDemo] GameInstance 为空"));
        return;
    }

    UHelpBotUESubsystem* subsystem = gameInstance->GetSubsystem<UHelpBotUESubsystem>();
    if (subsystem == nullptr)
    {
        UE_LOG(LogTemp, Error, TEXT("[HelpBotDemo] HelpBotUESubsystem 获取失败"));
        return;
    }

    subsystem->OnHelpBotEvent.AddDynamic(this, &AHelpBotDemoActor::onHelpBotEvent);

    UE_LOG(LogTemp, Log, TEXT("[HelpBotDemo] 开始 install：channelId=%s, domain=%s"), *channelId, *domain);
    UHelpBotUEBlueprintLibrary::Install(channelId, domain, installConfigJson);
}

void AHelpBotDemoActor::onHelpBotEvent(const FString& eventName, const FString& payloadJson)
{
    UE_LOG(LogTemp, Log, TEXT("[HelpBotDemo] Event=%s payload=%s"), *eventName, *payloadJson);

    if (eventName == TEXT("HB_INSTALL_SUCCESS"))
    {
        installDone = true;
        if (!token.IsEmpty())
        {
            UE_LOG(LogTemp, Log, TEXT("[HelpBotDemo] install 成功，开始 login"));
            UHelpBotUEBlueprintLibrary::Login(token, loginConfigJson);
        }
        return;
    }

    if (eventName == TEXT("HB_LOGIN_SUCCESS"))
    {
        loginDone = true;
        UE_LOG(LogTemp, Log, TEXT("[HelpBotDemo] login 成功，打开会话界面"));
        UHelpBotUEBlueprintLibrary::ShowConversation();
        return;
    }

    if (eventName == TEXT("HB_INSTALL_FAILURE") || eventName == TEXT("HB_LOGIN_FAILURE"))
    {
        UE_LOG(LogTemp, Error, TEXT("[HelpBotDemo] 初始化/登录失败：%s"), *payloadJson);
        return;
    }
}


