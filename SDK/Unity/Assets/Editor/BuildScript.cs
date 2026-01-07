using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine.SceneManagement;
using System.IO;

/// <summary>
/// Unity 构建脚本
/// 用于命令行构建和 CI/CD
/// </summary>
public class BuildScript
{
    /// <summary>
    /// 确保 Demo 场景存在（CI / batchmode 下无需手工打开编辑器创建 .unity 文件）。
    /// </summary>
    private static void EnsureSceneExists(string scenePath)
    {
        if (File.Exists(scenePath))
        {
            return;
        }

        // 说明：Scene 是 Unity 可序列化资源，走 Editor API 创建最可靠，避免手写 YAML 造成版本差异。
        var dir = Path.GetDirectoryName(scenePath);
        if (!string.IsNullOrEmpty(dir))
        {
            Directory.CreateDirectory(dir);
        }

        Scene scene = EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);
        EditorSceneManager.SaveScene(scene, scenePath);
        UnityEngine.Debug.Log("[HelpBot] Auto-created scene: " + scenePath);
    }

    [MenuItem("HelpBot/Build Android APK")]
    public static void BuildAndroid()
    {
        string[] scenes = { "Assets/Scenes/HelpBotDemo.unity" };
        string buildPath = "Builds/Android/HelpBotDemo.apk";

        EnsureSceneExists(scenes[0]);
        
        // 确保目录存在
        Directory.CreateDirectory(Path.GetDirectoryName(buildPath));
        
        BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions
        {
            scenes = scenes,
            locationPathName = buildPath,
            target = BuildTarget.Android,
            options = BuildOptions.None
        };
        
        BuildReport report = BuildPipeline.BuildPlayer(buildPlayerOptions);
        BuildSummary summary = report.summary;
        
        if (summary.result == BuildResult.Succeeded)
        {
            UnityEngine.Debug.Log("Build succeeded: " + summary.totalSize + " bytes");
        }
        else
        {
            UnityEngine.Debug.LogError("Build failed");
        }
    }
    
    [MenuItem("HelpBot/Build iOS")]
    public static void BuildIOS()
    {
        string[] scenes = { "Assets/Scenes/HelpBotDemo.unity" };
        string buildPath = "Builds/iOS";

        EnsureSceneExists(scenes[0]);
        
        Directory.CreateDirectory(buildPath);
        
        BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions
        {
            scenes = scenes,
            locationPathName = buildPath,
            target = BuildTarget.iOS,
            options = BuildOptions.None
        };
        
        BuildReport report = BuildPipeline.BuildPlayer(buildPlayerOptions);
        BuildSummary summary = report.summary;
        
        if (summary.result == BuildResult.Succeeded)
        {
            UnityEngine.Debug.Log("Build succeeded: " + summary.totalSize + " bytes");
        }
        else
        {
            UnityEngine.Debug.LogError("Build failed");
        }
    }
}
