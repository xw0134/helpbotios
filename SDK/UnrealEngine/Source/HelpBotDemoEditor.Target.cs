using UnrealBuildTool;
using System.Collections.Generic;

public class HelpBotDemoEditorTarget : TargetRules
{
	public HelpBotDemoEditorTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Editor;
		DefaultBuildSettings = BuildSettingsVersion.V2;
		ExtraModuleNames.AddRange( new string[] { "HelpBotDemo" } );
	}
}
