#pragma once

#include "CoreMinimal.h"
#include "Modules/ModuleManager.h"

class FHelpBotSDKModule : public IModuleInterface
{
public:
	/** IModuleInterface implementation */
	virtual void StartupModule() override;
	virtual void ShutdownModule() override;
	
	/**
	 * Singleton-like access to this module's interface.  This is just for convenience!
	 * Beware of calling this during the shutdown phase, though.  Your module might have been unloaded already.
	 *
	 * @return Returns singleton instance, loading the module on demand if needed
	 */
	static inline FHelpBotSDKModule& Get()
	{
		return FModuleManager::LoadModuleChecked< FHelpBotSDKModule >("HelpBotSDK");
	}

	/**
	 * Check if the module is available.
	 *
	 * @return True if the module is loaded and ready to use
	 */
	static inline bool IsAvailable()
	{
		return FModuleManager::Get().IsModuleLoaded("HelpBotSDK");
	}

    // Public API
    void Install(const FString& ChannelId, const FString& Domain);
    void Login(const FString& JwtToken);
    void ShowConversation();
};
