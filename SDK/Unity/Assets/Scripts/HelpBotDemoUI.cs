using UnityEngine;
using UnityEngine.UI;
using HelpBot;
using System.Collections;
using System.Collections.Generic;
using System.Text;
using UnityEngine.Networking;

/// <summary>
/// HelpBot Demo UI 控制器
/// 实现与 Android Demo 相同的功能界面
/// </summary>
public class HelpBotDemoUI : MonoBehaviour
{
    [Header("输入字段")]
    public InputField channelIdInput;
    public InputField domainInput;
    public InputField tokenUrlInput;
    public InputField identifierInput;
    public InputField valueInput;
    
    [Header("显示区域")]
    public Text statusText;
    public Text tokenText;
    public Text logText;
    public ScrollRect logScrollRect;
    
    private string rawToken = "";
    private System.Text.StringBuilder logBuffer = new System.Text.StringBuilder();
    
    // 压力测试状态
    private bool stressTestRunning = false;
    private int stressLoopCount = 0;
    private int stressSuccessCount = 0;
    private int stressFailureCount = 0;
    private Coroutine stressTestCoroutine = null;
    
    // 网络监听
    private NetworkReachability lastNetworkStatus;
    
    void Start()
    {
        // 设置默认值
        // 对齐 Android Demo 默认值（可直接运行验证）
        if (channelIdInput) channelIdInput.text = "appc-20251126114209416-ptvea1y414vey36";
        if (domainInput) domainInput.text = "dev-bot-server.yuedongcs.com";
        if (tokenUrlInput) tokenUrlInput.text = "https://dev-bot-server.yuedongcs.com:8123/generate_token";
        if (identifierInput) identifierInput.text = "uid";
        if (valueInput) valueInput.text = "123456789";
        
        AppendLog("Unity Demo 已启动");
        AppendLog("SDK 版本: " + HelpBotSDK.Instance.GetSDKVersion());
        UpdateStatus("Ready");
        
        // 初始化网络监听
        lastNetworkStatus = Application.internetReachability;
        InvokeRepeating("CheckNetworkStatus", 1.0f, 2.0f);
    }
    
    public void OnInstallClicked()
    {
        string channelId = channelIdInput ? channelIdInput.text : "";
        string domain = domainInput ? domainInput.text : "";
        
        if (string.IsNullOrEmpty(channelId) || string.IsNullOrEmpty(domain))
        {
            UpdateStatus("Error: Channel or Domain is empty");
            return;
        }
        
        HelpBotConfig config = new HelpBotConfig(channelId, domain);
        
        string errorMsg;
        if (!config.IsValid(out errorMsg))
        {
            UpdateStatus("Config Error: " + errorMsg);
            AppendLog("配置错误: " + errorMsg);
            return;
        }
        
        AppendLog("Installing SDK...");
        UpdateStatus("Installing...");
        
        HelpBotSDK.Instance.Install(config, (success, message) =>
        {
            if (success)
            {
                UpdateStatus("Install Success");
                AppendLog("SDK Install Success");
            }
            else
            {
                UpdateStatus("Install Failed: " + message);
                AppendLog("SDK Install Failed: " + message);
            }
        });
    }
    
    public void OnGenerateTokenClicked()
    {
        // 对齐 Android Demo：优先走真实 Token API；为空时才 fallback mock
        string url = tokenUrlInput ? tokenUrlInput.text : "";
        url = string.IsNullOrEmpty(url) ? "" : url.Trim();
        if (string.IsNullOrEmpty(url))
        {
            string identifier = identifierInput ? identifierInput.text : "user";
            rawToken = "mock_jwt_token_" + identifier + "_" + System.DateTime.Now.Ticks;

            if (tokenText)
            {
                tokenText.text = "Token(脱敏): " + MaskToken(rawToken);
            }

            AppendLog("Token Generated (Mock): " + MaskToken(rawToken));
            UpdateStatus("Token Generated (Mock)");
            return;
        }

        UpdateStatus("Generating Token...");
        AppendLog("Requesting Token: " + url);
        StartCoroutine(RequestTokenCoroutine(url));
    }

    private IEnumerator RequestTokenCoroutine(string url)
    {
        string identifier = identifierInput ? identifierInput.text : "";
        string value = valueInput ? valueInput.text : "";

        string json = BuildTokenRequestJson(identifier, value);
        byte[] bodyRaw = Encoding.UTF8.GetBytes(json);

        using (UnityWebRequest req = new UnityWebRequest(url, "POST"))
        {
            req.uploadHandler = new UploadHandlerRaw(bodyRaw);
            req.downloadHandler = new DownloadHandlerBuffer();
            req.SetRequestHeader("Content-Type", "application/json");

            yield return req.SendWebRequest();

            bool ok = false;
            string msg = "";
            try
            {
                if (req.result != UnityWebRequest.Result.Success)
                {
                    msg = "网络失败: " + req.error;
                }
                else
                {
                    string resp = req.downloadHandler != null ? req.downloadHandler.text : "";
                    TokenResponse tr = JsonUtility.FromJson<TokenResponse>(resp);
                    if (tr != null && !string.IsNullOrEmpty(tr.token))
                    {
                        rawToken = tr.token.Trim();
                        ok = true;
                        msg = "Token Generated";
                    }
                    else
                    {
                        msg = "Token 解析失败";
                    }
                }
            }
            catch (System.Exception e)
            {
                msg = "Token 请求异常: " + e.Message;
            }

            if (ok)
            {
                if (tokenText)
                {
                    tokenText.text = "Token(脱敏): " + MaskToken(rawToken);
                }
                AppendLog("Token Generated: " + MaskToken(rawToken));
                UpdateStatus("Token Generated");
            }
            else
            {
                AppendLog("Token Failed: " + msg);
                UpdateStatus("Token Failed: " + msg);
            }
        }
    }

    [System.Serializable]
    private class TokenResponse
    {
        public string token;
    }

    private static string BuildTokenRequestJson(string identifier, string value)
    {
        // {"identities":[{"identifier":"uid","value":"123"}]}
        return "{\"identities\":[{\"identifier\":\"" + EscapeJson(identifier) + "\",\"value\":\"" + EscapeJson(value) + "\"}]}";
    }

    private static string EscapeJson(string s)
    {
        if (s == null) return "";
        return s.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\n", "\\n").Replace("\r", "\\r").Replace("\t", "\\t");
    }

    private static string MaskToken(string token)
    {
        if (string.IsNullOrEmpty(token)) return "";
        string t = token.Trim();
        if (t.Length <= 12) return t.Substring(0, Mathf.Min(4, t.Length)) + "***";
        return t.Substring(0, 6) + "..." + t.Substring(t.Length - 6);
    }
    
    public void OnLoginClicked()
    {
        if (string.IsNullOrEmpty(rawToken))
        {
            UpdateStatus("Error: No Token");
            AppendLog("请先生成 Token");
            return;
        }
        
        AppendLog("Logging in...");
        UpdateStatus("Logging in...");
        
        HelpBotSDK.Instance.Login(rawToken, (success, message) =>
        {
            if (success)
            {
                UpdateStatus("Login Success");
                AppendLog("Login Success");
            }
            else
            {
                UpdateStatus("Login Failed: " + message);
                AppendLog("Login Failed: " + message);
            }
        });
    }
    
    public void OnShowConversationClicked()
    {
        AppendLog("Opening conversation...");
        
        HelpBotSDK.Instance.ShowConversation((success, message) =>
        {
            if (!success)
            {
                AppendLog("Show Conversation Failed: " + message);
                UpdateStatus("Failed: " + message);
            }
            else
            {
                AppendLog("Conversation opened");
            }
        });
    }
    
    public void OnShowFAQsClicked()
    {
        AppendLog("Opening FAQs...");
        
        HelpBotSDK.Instance.ShowFAQs((success, message) =>
        {
            if (!success)
            {
                AppendLog("Show FAQs Failed: " + message);
            }
            else
            {
                AppendLog("FAQs opened");
            }
        });
    }
    
    public void OnUpdateMetaClicked()
    {
        var customMeta = new Dictionary<string, string>
        {
            { "user_level", "10" },
            { "server", "S1" },
            { "player_name", valueInput ? valueInput.text : "Guest" }
        };
        
        HelpBotSDK.Instance.UpdateCustomMeta(customMeta);
        AppendLog("Custom Meta Updated");
        
        var sdkMeta = new Dictionary<string, string>
        {
            { "engine", "Unity" },
            { "unity_version", Application.unityVersion },
            { "platform", Application.platform.ToString() }
        };
        
        HelpBotSDK.Instance.UpdateSDKMeta(sdkMeta);
        AppendLog("SDK Meta Updated");
        
        UpdateStatus("Meta Updated");
    }
    
    public void OnClearLogClicked()
    {
        logBuffer.Clear();
        if (logText) logText.text = "";
    }
    
    public void OnCopyTokenClicked()
    {
        if (!string.IsNullOrEmpty(rawToken))
        {
            GUIUtility.systemCopyBuffer = rawToken;
            AppendLog("Token copied to clipboard");
        }
    }
    
    private void AppendLog(string message)
    {
        logBuffer.AppendLine("> " + message);
        
        // 限制日志长度
        if (logBuffer.Length > 5000)
        {
            logBuffer.Remove(0, logBuffer.Length - 5000);
        }
        
        if (logText)
        {
            logText.text = logBuffer.ToString();
            
            // 滚动到底部
            if (logScrollRect)
            {
                Canvas.ForceUpdateCanvases();
                logScrollRect.verticalNormalizedPosition = 0f;
            }
        }
    }
    
    private void UpdateStatus(string status)
    {
        if (statusText)
        {
            statusText.text = "Status: " + status;
        }
    }
    
    // ==================== 高级功能 ====================
    
    /// <summary>
    /// 自检功能 - 对齐 Android Demo
    /// </summary>
    public void OnSelfCheckClicked()
    {
        AppendLog("========== 一键自检开始 ==========");
        UpdateStatus("自检中...");
        
        // 1. 基础信息
        AppendLog("Unity 版本: " + Application.unityVersion);
        AppendLog("平台: " + Application.platform.ToString());
        AppendLog("设备型号: " + SystemInfo.deviceModel);
        AppendLog("操作系统: " + SystemInfo.operatingSystem);
        AppendLog("SDK 版本: " + HelpBotSDK.Instance.GetSDKVersion());
        
        // 2. 网络状态
        AppendLog("网络状态: " + Application.internetReachability.ToString());
        
        // 3. 内存信息
        AppendLog("系统内存: " + (SystemInfo.systemMemorySize / 1024f).ToString("F2") + " GB");
        AppendLog("显存: " + (SystemInfo.graphicsMemorySize / 1024f).ToString("F2") + " GB");
        
        // 4. SDK 状态
        AppendLog("SDK 已初始化: " + HelpBotSDK.Instance.IsInitialized());
        
        UpdateStatus("自检完成");
        AppendLog("========== 一键自检完成 ==========");
    }
    
    /// <summary>
    /// 网络监听 - 定期检查网络状态变化
    /// </summary>
    private void CheckNetworkStatus()
    {
        NetworkReachability current = Application.internetReachability;
        if (current != lastNetworkStatus)
        {
            AppendLog("网络状态变化: " + lastNetworkStatus + " -> " + current);
            lastNetworkStatus = current;
            
            if (current == NetworkReachability.NotReachable)
            {
                UpdateStatus("网络断开");
            }
            else
            {
                UpdateStatus("网络已连接");
            }
        }
    }
    
    /// <summary>
    /// 压力测试 - 开始
    /// </summary>
    public void OnStressTestStartClicked()
    {
        if (stressTestRunning)
        {
            AppendLog("压力测试已在运行中");
            return;
        }
        
        AppendLog("========== 压力测试开始 ==========");
        stressTestRunning = true;
        stressLoopCount = 0;
        stressSuccessCount = 0;
        stressFailureCount = 0;
        
        stressTestCoroutine = StartCoroutine(StressTestCoroutine());
    }
    
    /// <summary>
    /// 压力测试 - 停止
    /// </summary>
    public void OnStressTestStopClicked()
    {
        if (!stressTestRunning)
        {
            AppendLog("压力测试未运行");
            return;
        }
        
        stressTestRunning = false;
        if (stressTestCoroutine != null)
        {
            StopCoroutine(stressTestCoroutine);
            stressTestCoroutine = null;
        }
        
        AppendLog("========== 压力测试停止 ==========");
        AppendLog("总循环: " + stressLoopCount);
        AppendLog("成功: " + stressSuccessCount);
        AppendLog("失败: " + stressFailureCount);
        UpdateStatus("压力测试已停止");
    }
    
    /// <summary>
    /// 压力测试协程 - 循环调用 Show/Hide
    /// </summary>
    private IEnumerator StressTestCoroutine()
    {
        while (stressTestRunning)
        {
            stressLoopCount++;
            UpdateStatus("压力测试中... 循环 " + stressLoopCount);
            
            // 显示对话
            bool showSuccess = false;
            HelpBotSDK.Instance.ShowConversation((success, message) =>
            {
                if (success)
                {
                    stressSuccessCount++;
                    showSuccess = true;
                }
                else
                {
                    stressFailureCount++;
                    AppendLog("Show 失败: " + message);
                }
            });
            
            yield return new WaitForSeconds(0.5f);
            
            // 隐藏对话 (如果 SDK 支持)
            // HelpBotSDK.Instance.HideConversation();
            
            yield return new WaitForSeconds(0.5f);
            
            // 每 10 次循环输出一次统计
            if (stressLoopCount % 10 == 0)
            {
                AppendLog("压力测试进度: " + stressLoopCount + " 次, 成功: " + stressSuccessCount + ", 失败: " + stressFailureCount);
            }
        }
    }
    
    /// <summary>
    /// 负向测试 - 对齐 Android Demo
    /// </summary>
    public void OnNegativeTestsClicked()
    {
        AppendLog("========== 负向测试开始 ==========");
        UpdateStatus("负向测试中...");
        
        // 1. 未登录直接 ShowConversation
        AppendLog("测试 1: 未登录直接 ShowConversation");
        HelpBotSDK.Instance.ShowConversation((success, message) =>
        {
            AppendLog("  结果: " + (success ? "成功" : "失败 - " + message));
        });
        
        // 2. 空 Token 登录
        AppendLog("测试 2: 空 Token 登录");
        HelpBotSDK.Instance.Login("", (success, message) =>
        {
            AppendLog("  结果: " + (success ? "意外成功" : "预期失败 - " + message));
        });
        
        // 3. 无效配置 Install
        AppendLog("测试 3: 无效配置 Install");
        HelpBotConfig invalidConfig = new HelpBotConfig("", "");
        string errorMsg;
        if (!invalidConfig.IsValid(out errorMsg))
        {
            AppendLog("  结果: 配置验证失败 (预期) - " + errorMsg);
        }
        
        // 4. 重复 Install
        AppendLog("测试 4: 重复 Install");
        if (HelpBotSDK.Instance.IsInitialized())
        {
            HelpBotConfig config = new HelpBotConfig(
                channelIdInput ? channelIdInput.text : "",
                domainInput ? domainInput.text : ""
            );
            HelpBotSDK.Instance.Install(config, (success, message) =>
            {
                AppendLog("  结果: " + (success ? "成功" : "失败 - " + message));
            });
        }
        
        UpdateStatus("负向测试完成");
        AppendLog("========== 负向测试完成 ==========");
    }
    
    /// <summary>
    /// 清理资源
    /// </summary>
    private void OnDestroy()
    {
        // 停止网络监听
        CancelInvoke("CheckNetworkStatus");
        
        // 停止压力测试
        if (stressTestRunning)
        {
            OnStressTestStopClicked();
        }
    }
}

