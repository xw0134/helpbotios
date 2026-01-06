using UnrealBuildTool;

public class HelpBotUE : ModuleRules
{
    public HelpBotUE(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

        PublicDependencyModuleNames.AddRange(
            new string[]
            {
                "Core",
                "CoreUObject",
                "Engine",
                "Json",
                "JsonUtilities"
            }
        );

        PrivateDependencyModuleNames.AddRange(
            new string[]
            {
            }
        );

        if (Target.Platform == UnrealTargetPlatform.Android)
        {
            PrivateDependencyModuleNames.Add("Launch");
        }

        if (Target.Platform == UnrealTargetPlatform.IOS)
        {
            // 添加 iOS Framework 支持
            string FrameworkPath = System.IO.Path.Combine(ModuleDirectory, "../../ThirdParty/iOS");
            
            // 如果存在预编译的 Framework,则添加
            if (System.IO.Directory.Exists(System.IO.Path.Combine(FrameworkPath, "HelpBot.framework")))
            {
                PublicAdditionalFrameworks.Add(
                    new Framework(
                        "HelpBot",
                        "../../ThirdParty/iOS/HelpBot.framework.zip",
                        "",
                        true
                    )
                );
            }
            
            // 添加系统 Framework 依赖
            PublicFrameworks.AddRange(new string[]
            {
                "WebKit",
                "Foundation",
                "UIKit"
            });
        }
    }
}


