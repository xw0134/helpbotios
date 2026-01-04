using UnrealBuildTool;
using System.Collections.Generic;

public class HelpBotUEDemoTarget : TargetRules
{
    public HelpBotUEDemoTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Game;
        DefaultBuildSettings = BuildSettingsVersion.V2;
        ExtraModuleNames.Add("HelpBotUEDemo");
    }
}


