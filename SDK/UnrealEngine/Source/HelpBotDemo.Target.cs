using UnrealBuildTool;
using System.Collections.Generic;

public class HelpBotDemoTarget : TargetRules
{
	public HelpBotDemoTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Game;
		DefaultBuildSettings = BuildSettingsVersion.V2;
		ExtraModuleNames.AddRange( new string[] { "HelpBotDemo" } );
	}
}
