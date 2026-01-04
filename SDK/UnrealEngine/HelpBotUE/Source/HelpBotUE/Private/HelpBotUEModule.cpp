#include "Modules/ModuleManager.h"

class FHelpBotUEModule : public IModuleInterface
{
public:
    virtual void StartupModule() override
    {
    }

    virtual void ShutdownModule() override
    {
    }
};

IMPLEMENT_MODULE(FHelpBotUEModule, HelpBotUE)


