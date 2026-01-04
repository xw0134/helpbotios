#include "HelpBotUESubsystem.h"

#include "Async/Async.h"

TWeakObjectPtr<UHelpBotUESubsystem> UHelpBotUESubsystem::activeInstance;

void UHelpBotUESubsystem::Initialize(FSubsystemCollectionBase& collection)
{
    Super::Initialize(collection);
    activeInstance = this;
}

void UHelpBotUESubsystem::Deinitialize()
{
    if (activeInstance.Get() == this)
    {
        activeInstance = nullptr;
    }
    Super::Deinitialize();
}

UHelpBotUESubsystem* UHelpBotUESubsystem::GetActive()
{
    return activeInstance.Get();
}

void UHelpBotUESubsystem::DispatchEventOnGameThread(const FString& eventName, const FString& payloadJson)
{
    // 统一切到游戏线程广播，避免蓝图/引擎对象跨线程访问导致崩溃
    AsyncTask(ENamedThreads::GameThread, [weakThis = TWeakObjectPtr<UHelpBotUESubsystem>(this), eventName, payloadJson]()
    {
        UHelpBotUESubsystem* self = weakThis.Get();
        if (self == nullptr)
        {
            return;
        }
        self->OnHelpBotEvent.Broadcast(eventName, payloadJson);
    });
}


