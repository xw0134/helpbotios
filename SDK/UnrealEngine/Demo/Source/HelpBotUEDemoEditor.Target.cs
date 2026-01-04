using UnrealBuildTool;
using System.Collections.Generic;

public class HelpBotUEDemoEditorTarget : TargetRules
{
    public HelpBotUEDemoEditorTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Editor;
        DefaultBuildSettings = BuildSettingsVersion.V2;
        ExtraModuleNames.Add("HelpBotUEDemo");
    }
}


