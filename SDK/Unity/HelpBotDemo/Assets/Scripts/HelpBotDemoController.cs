using System;
using System.Collections.Generic;
using System.Text;
using UnityEngine;
using UnityEngine.UI;
using HelpBot;

namespace HelpBotDemo
{
    /// <summary>
    /// HelpBot Unity Demo 控制器
    /// 
    /// 实现所有 SDK 功能的测试,包括:
    /// - Install 测试(多种配置)
    /// - Login 测试(正常流程、错误流程)
    /// - ShowConversation 测试
    /// - ShowFAQs 测试
    /// - Logout 测试
    /// - Destroy 测试
    /// - 事件监听测试
    /// - 属性更新测试
    /// - 压力测试
    /// </summary>
    public class HelpBotDemoController : MonoBehaviour
    {
        [Header("配置")]
        public string channelId = "your_channel_id";
        public string domain = "https://your-domain.com";
        public string testToken = "your_test_token";

        [Header("UI 引用")]
        public Text logText;
        public ScrollRect logScrollRect;
        public Button clearLogButton;

        private readonly StringBuilder logBuilder = new StringBuilder();
        private bool isInstalled = false;
        private bool isLoggedIn = false;

        private void Start()
        {
            if (clearLogButton != null)
            {
                clearLogButton.onClick.AddListener(ClearLog);
            }

            Log("HelpBot Unity Demo 已启动");
            Log($"SDK 版本: {HelpBot.HelpBot.GetSDKVersion()}");
        }

        #region Install Tests

        public void OnInstallBasicClicked()
        {
            Log("=== Install (Basic) ===");

            var config = new HelpBotConfig.Builder()
                .SetChannelId(channelId)
                .SetDomain(domain)
                .Build();

            HelpBot.HelpBot.Install(config, new InitCallback(this));
        }

        public void OnInstallWithConfigClicked()
        {
            Log("=== Install (With Config) ===");

            var configMap = new Dictionary<string, object>
            {
                { "fullPrivacyMode", false },
                { "customKey1", "customValue1" },
                { "customKey2", 123 }
            };

            HelpBot.HelpBot.Install(channelId, domain, configMap, new InitCallback(this));
        }

        public void OnInstallTwiceClicked()
        {
            Log("=== Install Twice (Should Fail) ===");

            var config = new HelpBotConfig.Builder()
                .SetChannelId(channelId)
                .SetDomain(domain)
                .Build();

            HelpBot.HelpBot.Install(config, new InitCallback(this));
        }

        #endregion

        #region Login Tests

        public void OnLoginClicked()
        {
            Log("=== Login ===");

            if (string.IsNullOrEmpty(testToken))
            {
                LogError("testToken 未设置，请在 Inspector 中配置");
                return;
            }

            HelpBot.HelpBot.Login(testToken, null, new LoginCallback(this));
        }

        public void OnLoginWithConfigClicked()
        {
            Log("=== Login (With Config) ===");

            var loginConfig = new Dictionary<string, object>
            {
                { "customLoginKey", "customLoginValue" }
            };

            HelpBot.HelpBot.Login(testToken, loginConfig, new LoginCallback(this));
        }

        public void OnLoginBeforeInstallClicked()
        {
            Log("=== Login Before Install (Should Fail) ===");

            HelpBot.HelpBot.Login(testToken, null, new LoginCallback(this));
        }

        public void OnLoginTwiceClicked()
        {
            Log("=== Login Twice (Should Fail) ===");

            HelpBot.HelpBot.Login(testToken, null, new LoginCallback(this));
        }

        #endregion

        #region Conversation Tests

        public void OnShowConversationClicked()
        {
            Log("=== Show Conversation ===");
            HelpBot.HelpBot.ShowConversation();
        }

        public void OnShowFAQsClicked()
        {
            Log("=== Show FAQs ===");
            HelpBot.HelpBot.ShowFAQs();
        }

        public void OnShowFAQsWithConfigClicked()
        {
            Log("=== Show FAQs (With Config) ===");

            var config = new Dictionary<string, object>
            {
                { "tn", "custom_tn_value" }
            };

            HelpBot.HelpBot.ShowFAQs(config);
        }

        #endregion

        #region Logout and Destroy Tests

        public void OnLogoutClicked()
        {
            Log("=== Logout ===");
            HelpBot.HelpBot.Logout(new LogoutCallback(this));
        }

        public void OnDestroyClicked()
        {
            Log("=== Destroy SDK ===");
            HelpBot.HelpBot.Destroy();
            isInstalled = false;
            isLoggedIn = false;
            Log("SDK 已销毁");
        }

        #endregion

        #region Events Tests

        public void OnSetEventsListenerClicked()
        {
            Log("=== Set Events Listener ===");
            HelpBot.HelpBot.SetEventsListener(new EventsListener(this));
            Log("事件监听器已设置");
        }

        public void OnClearEventsListenerClicked()
        {
            Log("=== Clear Events Listener ===");
            HelpBot.HelpBot.SetEventsListener(null);
            Log("事件监听器已清除");
        }

        #endregion

        #region Attributes Tests

        public void OnUpdateMasterAttributesClicked()
        {
            Log("=== Update Master Attributes ===");

            var attributes = new Dictionary<string, object>
            {
                { "userLevel", 10 },
                { "vipStatus", "gold" },
                { "registrationDate", "2024-01-01" }
            };

            HelpBot.HelpBot.UpdateMasterAttributes(attributes, new AttributesCallback(this, "Master"));
        }

        public void OnUpdateAppAttributesClicked()
        {
            Log("=== Update App Attributes ===");

            var attributes = new Dictionary<string, object>
            {
                { "appVersion", "1.0.0" },
                { "platform", "Unity" },
                { "deviceModel", SystemInfo.deviceModel }
            };

            HelpBot.HelpBot.UpdateAppAttributes(attributes, new AttributesCallback(this, "App"));
        }

        #endregion

        #region Stress Tests

        public void OnStressTestClicked()
        {
            Log("=== Stress Test ===");
            StartCoroutine(RunStressTest());
        }

        private System.Collections.IEnumerator RunStressTest()
        {
            Log("开始压力测试...");

            // 测试 1: 快速重复调用 Install
            Log("测试 1: 快速重复调用 Install (3次)");
            for (int i = 0; i < 3; i++)
            {
                Log($"  Install #{i + 1}");
                var config = new HelpBotConfig.Builder()
                    .SetChannelId(channelId)
                    .SetDomain(domain)
                    .Build();
                HelpBot.HelpBot.Install(config, new InitCallback(this));
                yield return new WaitForSeconds(0.1f);
            }

            yield return new WaitForSeconds(2f);

            // 测试 2: 快速重复调用 Login
            Log("测试 2: 快速重复调用 Login (3次)");
            for (int i = 0; i < 3; i++)
            {
                Log($"  Login #{i + 1}");
                HelpBot.HelpBot.Login(testToken, null, new LoginCallback(this));
                yield return new WaitForSeconds(0.1f);
            }

            yield return new WaitForSeconds(2f);

            // 测试 3: 快速打开/关闭对话窗口
            Log("测试 3: 快速打开对话窗口 (5次)");
            for (int i = 0; i < 5; i++)
            {
                Log($"  ShowConversation #{i + 1}");
                HelpBot.HelpBot.ShowConversation();
                yield return new WaitForSeconds(0.2f);
            }

            yield return new WaitForSeconds(1f);

            // 测试 4: 空参数测试
            Log("测试 4: 空参数测试");
            try
            {
                HelpBot.HelpBot.Login("", null, new LoginCallback(this));
            }
            catch (Exception e)
            {
                LogError($"空 token 测试异常: {e.Message}");
            }

            yield return new WaitForSeconds(1f);

            // 测试 5: Destroy 后重新 Install
            Log("测试 5: Destroy 后重新 Install");
            HelpBot.HelpBot.Destroy();
            yield return new WaitForSeconds(1f);

            var finalConfig = new HelpBotConfig.Builder()
                .SetChannelId(channelId)
                .SetDomain(domain)
                .Build();
            HelpBot.HelpBot.Install(finalConfig, new InitCallback(this));

            Log("压力测试完成");
        }

        #endregion

        #region Logging

        private void Log(string message)
        {
            string timestamp = DateTime.Now.ToString("HH:mm:ss");
            string logMessage = $"[{timestamp}] {message}";

            logBuilder.AppendLine(logMessage);
            UpdateLogUI();

            Debug.Log($"[HelpBotDemo] {message}");
        }

        private void LogError(string message)
        {
            string timestamp = DateTime.Now.ToString("HH:mm:ss");
            string logMessage = $"[{timestamp}] <color=red>ERROR: {message}</color>";

            logBuilder.AppendLine(logMessage);
            UpdateLogUI();

            Debug.LogError($"[HelpBotDemo] {message}");
        }

        private void LogSuccess(string message)
        {
            string timestamp = DateTime.Now.ToString("HH:mm:ss");
            string logMessage = $"[{timestamp}] <color=green>SUCCESS: {message}</color>";

            logBuilder.AppendLine(logMessage);
            UpdateLogUI();

            Debug.Log($"[HelpBotDemo] {message}");
        }

        private void UpdateLogUI()
        {
            if (logText != null)
            {
                logText.text = logBuilder.ToString();

                // 自动滚动到底部
                if (logScrollRect != null)
                {
                    Canvas.ForceUpdateCanvases();
                    logScrollRect.verticalNormalizedPosition = 0f;
                }
            }
        }

        private void ClearLog()
        {
            logBuilder.Clear();
            UpdateLogUI();
            Log("日志已清除");
        }

        #endregion

        #region Callback Implementations

        private class InitCallback : IHelpBotInitCallback
        {
            private readonly HelpBotDemoController controller;

            public InitCallback(HelpBotDemoController controller)
            {
                this.controller = controller;
            }

            public void OnInitStart()
            {
                controller.Log("初始化开始...");
            }

            public void OnInitProgress(int progress, string message)
            {
                controller.Log($"初始化进度: {progress}% - {message}");
            }

            public void OnInitSuccess()
            {
                controller.LogSuccess("初始化成功");
                controller.isInstalled = true;
            }

            public void OnInitFailure(HelpBotErrorCode errorCode, string errorMessage)
            {
                controller.LogError($"初始化失败: [{errorCode.GetCode()}] {errorMessage}");
            }
        }

        private class LoginCallback : IHelpBotCallback<object>
        {
            private readonly HelpBotDemoController controller;

            public LoginCallback(HelpBotDemoController controller)
            {
                this.controller = controller;
            }

            public void OnSuccess(object result)
            {
                controller.LogSuccess("登录成功");
                controller.isLoggedIn = true;
            }

            public void OnFailure(HelpBotErrorCode errorCode, string errorMessage)
            {
                controller.LogError($"登录失败: [{errorCode.GetCode()}] {errorMessage}");
            }
        }

        private class LogoutCallback : IHelpBotCallback<object>
        {
            private readonly HelpBotDemoController controller;

            public LogoutCallback(HelpBotDemoController controller)
            {
                this.controller = controller;
            }

            public void OnSuccess(object result)
            {
                controller.LogSuccess("登出成功");
                controller.isLoggedIn = false;
            }

            public void OnFailure(HelpBotErrorCode errorCode, string errorMessage)
            {
                controller.LogError($"登出失败: [{errorCode.GetCode()}] {errorMessage}");
            }
        }

        private class AttributesCallback : IHelpBotCallback<object>
        {
            private readonly HelpBotDemoController controller;
            private readonly string attributeType;

            public AttributesCallback(HelpBotDemoController controller, string attributeType)
            {
                this.controller = controller;
                this.attributeType = attributeType;
            }

            public void OnSuccess(object result)
            {
                controller.LogSuccess($"{attributeType} 属性更新成功");
            }

            public void OnFailure(HelpBotErrorCode errorCode, string errorMessage)
            {
                controller.LogError($"{attributeType} 属性更新失败: [{errorCode.GetCode()}] {errorMessage}");
            }
        }

        private class EventsListener : IHelpBotEventsListener
        {
            private readonly HelpBotDemoController controller;

            public EventsListener(HelpBotDemoController controller)
            {
                this.controller = controller;
            }

            public void OnEventOccurred(string eventName, string data)
            {
                controller.Log($"事件: {eventName}");
                if (!string.IsNullOrEmpty(data) && data != "{}")
                {
                    controller.Log($"  数据: {data}");
                }
            }

            public void OnUserAuthenticationFailure(HelpBotAuthenticationFailureReason reason)
            {
                controller.LogError($"认证失败: {reason}");
            }
        }

        #endregion
    }
}
