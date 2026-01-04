using UnrealBuildTool;

public class HelpBotUEDemo : ModuleRules
{
    public HelpBotUEDemo(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

        PublicDependencyModuleNames.AddRange(
            new string[]
            {
                "Core",
                "CoreUObject",
                "Engine",
                "HelpBotUE"
            }
        );
    }
}


