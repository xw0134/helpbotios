using UnrealBuildTool;
using System.IO;

public class HelpBotSDK : ModuleRules
{
	public HelpBotSDK(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = ModuleRules.PCHUsageMode.UseExplicitOrSharedPCHs;
		
		PublicDependencyModuleNames.AddRange(
			new string[]
			{
				"Core",
				// ... add other public dependencies that you statically link with here ...
			}
			);
			
		PrivateDependencyModuleNames.AddRange(
			new string[]
			{
				"CoreUObject",
				"Engine",
				"Slate",
				"SlateCore",
				// ... add private dependencies that you statically link with here ...	
			}
			);
			
		if (Target.Platform == UnrealTargetPlatform.Android)
		{
			// Add AAR dependency
			string PluginPath = Utils.MakePathRelativeTo(ModuleDirectory, Target.RelativeEnginePath);
			AdditionalPropertiesForReceipt.Add("AndroidPlugin", Path.Combine(PluginPath, "../Android/HelpBotSDK_APL.xml"));
			
			// Note: AARs are handled via APL in UE4/UE5 usually, or by copying to Build/Android/Java/libs
			// However, APL <resource> tag is the standard way to distribute AARs in plugins
		}
		else if (Target.Platform == UnrealTargetPlatform.IOS)
		{
			PublicFrameworks.Add(Path.Combine(ModuleDirectory, "../iOS/Frameworks/HelpBotSDK.framework"));
			PublicAdditionalFrameworks.Add(
				new Framework(
					"HelpBotSDK",
					Path.Combine(ModuleDirectory, "../iOS/Frameworks/HelpBotSDK.framework.zip")
				)
			);
		}
	}
}
