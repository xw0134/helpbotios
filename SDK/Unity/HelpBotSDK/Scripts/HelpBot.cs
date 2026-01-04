using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;

namespace HelpBot
{
    /// <summary>
    /// HelpBot SDK 主入口类
    /// 
    /// 设计要点：
    /// 1. 所有 API 与 Android SDK 保持一致
    /// 2. 通过 Native Bridge 与底层 Android/iOS SDK 通信
    /// 3. 所有回调在 Unity 主线程执行
    /// 4. 线程安全与资源生命周期管理
    /// </summary>
    public class HelpBot : MonoBehaviour
    {
        private const string TAG = "HelpBot";
        private const string SDK_VERSION = "1.0.0";

        // 单例实例
        private static HelpBot instance;
        private static readonly object lockObj = new object();

        // 事件监听器
        private static IHelpBotEventsListener eventsListener;

        // 回调队列（用于在主线程执行回调）
        private readonly Queue<Action> callbackQueue = new Queue<Action>();

        #region Unity Lifecycle

        private void Awake()
        {
            if (instance == null)
            {
                instance = this;
                DontDestroyOnLoad(gameObject);
            }
            else if (instance != this)
            {
                Destroy(gameObject);
            }
        }

        private void Update()
        {
            // 在主线程执行回调
            lock (callbackQueue)
            {
                while (callbackQueue.Count > 0)
                {
                    var callback = callbackQueue.Dequeue();
                    try
                    {
                        callback?.Invoke();
                    }
                    catch (Exception e)
                    {
                        HBLogger.E(TAG, "执行回调异常", e);
                    }
                }
            }
        }

        #endregion

        #region Public APIs

        /// <summary>
        /// 初始化 HelpBot SDK（使用 HelpBotConfig）
        /// </summary>
        /// <param name="config">SDK 配置</param>
        /// <param name="callback">初始化回调（可选）</param>
        public static void Install(HelpBotConfig config, IHelpBotInitCallback callback = null)
        {
            if (config == null)
            {
                HBLogger.E(TAG, "Install: config 不能为 null");
                NotifyInitFailure(callback, HelpBotErrorCode.INVALID_PARAMETER, "HelpBotConfig 不能为 null");
                return;
            }

            EnsureInstance();

            try
            {
                string configJson = ConfigToJson(config);
                HBLogger.D(TAG, $"Install: configJson={configJson}");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidInstall(configJson, callback);
#elif UNITY_IOS && !UNITY_EDITOR
                IOSInstall(configJson, callback);
#else
                HBLogger.W(TAG, "Install: 当前平台不支持，仅在 Android/iOS 设备上运行");
                NotifyInitFailure(callback, HelpBotErrorCode.NOT_SUPPORTED, "当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "Install 异常", e);
                NotifyInitFailure(callback, HelpBotErrorCode.INTERNAL_ERROR, $"初始化异常: {e.Message}");
            }
        }

        /// <summary>
        /// 初始化 HelpBot SDK（使用 channelId/domain/configMap）
        /// </summary>
        /// <param name="channelId">频道 ID</param>
        /// <param name="domain">域名（必须 https）</param>
        /// <param name="configMap">配置参数（可选）</param>
        /// <param name="callback">初始化回调（可选）</param>
        public static void Install(string channelId, string domain, Dictionary<string, object> configMap = null, IHelpBotInitCallback callback = null)
        {
            try
            {
                var builder = new HelpBotConfig.Builder()
                    .SetChannelId(channelId)
                    .SetDomain(domain);

                if (configMap != null)
                {
                    foreach (var kvp in configMap)
                    {
                        if (kvp.Key == "fullPrivacyMode" && kvp.Value is bool)
                        {
                            builder.SetFullPrivacyMode((bool)kvp.Value);
                        }
                        else
                        {
                            builder.AddCustomConfig(kvp.Key, kvp.Value);
                        }
                    }
                }

                Install(builder.Build(), callback);
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "Install(channelId/domain/configMap) 异常", e);
                NotifyInitFailure(callback, HelpBotErrorCode.INVALID_PARAMETER, $"初始化参数非法: {e.Message}");
            }
        }

        /// <summary>
        /// 用户登录
        /// </summary>
        /// <param name="identitiesJWT">WebSDK 预生成 Token（必须）</param>
        /// <param name="loginConfig">登录配置（可选）</param>
        /// <param name="callback">登录回调（可选）</param>
        public static void Login(string identitiesJWT, Dictionary<string, object> loginConfig = null, IHelpBotCallback<object> callback = null)
        {
            if (string.IsNullOrEmpty(identitiesJWT))
            {
                HBLogger.E(TAG, "Login: identitiesJWT 不能为空");
                NotifyFailure(callback, HelpBotErrorCode.INVALID_TOKEN, "Token 不能为空");
                return;
            }

            EnsureInstance();

            try
            {
                string loginConfigJson = loginConfig != null ? DictToJson(loginConfig) : "{}";
                HBLogger.D(TAG, $"Login: token={identitiesJWT.Substring(0, Math.Min(20, identitiesJWT.Length))}...");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidLogin(identitiesJWT, loginConfigJson, callback);
#elif UNITY_IOS && !UNITY_EDITOR
                IOSLogin(identitiesJWT, loginConfigJson, callback);
#else
                HBLogger.W(TAG, "Login: 当前平台不支持");
                NotifyFailure(callback, HelpBotErrorCode.NOT_SUPPORTED, "当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "Login 异常", e);
                NotifyFailure(callback, HelpBotErrorCode.INTERNAL_ERROR, $"登录异常: {e.Message}");
            }
        }

        /// <summary>
        /// 显示对话窗口
        /// </summary>
        public static void ShowConversation()
        {
            EnsureInstance();

            try
            {
                HBLogger.D(TAG, "ShowConversation");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidShowConversation();
#elif UNITY_IOS && !UNITY_EDITOR
                IOSShowConversation();
#else
                HBLogger.W(TAG, "ShowConversation: 当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "ShowConversation 异常", e);
            }
        }

        /// <summary>
        /// 显示 FAQ 主页面
        /// </summary>
        /// <param name="configMap">配置参数（可选）</param>
        public static void ShowFAQs(Dictionary<string, object> configMap = null)
        {
            EnsureInstance();

            try
            {
                string configJson = configMap != null ? DictToJson(configMap) : "{}";
                HBLogger.D(TAG, "ShowFAQs");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidShowFAQs(configJson);
#elif UNITY_IOS && !UNITY_EDITOR
                IOSShowFAQs(configJson);
#else
                HBLogger.W(TAG, "ShowFAQs: 当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "ShowFAQs 异常", e);
            }
        }

        /// <summary>
        /// 用户登出
        /// </summary>
        /// <param name="callback">登出回调（可选）</param>
        public static void Logout(IHelpBotCallback<object> callback = null)
        {
            EnsureInstance();

            try
            {
                HBLogger.D(TAG, "Logout");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidLogout(callback);
#elif UNITY_IOS && !UNITY_EDITOR
                IOSLogout(callback);
#else
                HBLogger.W(TAG, "Logout: 当前平台不支持");
                NotifyFailure(callback, HelpBotErrorCode.NOT_SUPPORTED, "当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "Logout 异常", e);
                NotifyFailure(callback, HelpBotErrorCode.INTERNAL_ERROR, $"登出异常: {e.Message}");
            }
        }

        /// <summary>
        /// 销毁 SDK
        /// </summary>
        public static void Destroy()
        {
            try
            {
                HBLogger.D(TAG, "Destroy");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidDestroy();
#elif UNITY_IOS && !UNITY_EDITOR
                IOSDestroy();
#else
                HBLogger.W(TAG, "Destroy: 当前平台不支持");
#endif

                eventsListener = null;
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "Destroy 异常", e);
            }
        }

        /// <summary>
        /// 设置事件监听器
        /// </summary>
        /// <param name="listener">事件监听器</param>
        public static void SetEventsListener(IHelpBotEventsListener listener)
        {
            eventsListener = listener;
            EnsureInstance();

            try
            {
                HBLogger.D(TAG, $"SetEventsListener: {(listener != null ? "已设置" : "已清除")}");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidSetEventsListener(listener != null);
#elif UNITY_IOS && !UNITY_EDITOR
                IOSSetEventsListener(listener != null);
#else
                HBLogger.W(TAG, "SetEventsListener: 当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "SetEventsListener 异常", e);
            }
        }

        /// <summary>
        /// 更新主属性
        /// </summary>
        /// <param name="attributes">属性字典</param>
        /// <param name="callback">回调（可选）</param>
        public static void UpdateMasterAttributes(Dictionary<string, object> attributes, IHelpBotCallback<object> callback = null)
        {
            if (attributes == null || attributes.Count == 0)
            {
                HBLogger.W(TAG, "UpdateMasterAttributes: attributes 为空");
                NotifyFailure(callback, HelpBotErrorCode.INVALID_PARAMETER, "attributes 不能为空");
                return;
            }

            EnsureInstance();

            try
            {
                string attributesJson = DictToJson(attributes);
                HBLogger.D(TAG, $"UpdateMasterAttributes: {attributesJson}");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidUpdateMasterAttributes(attributesJson, callback);
#elif UNITY_IOS && !UNITY_EDITOR
                IOSUpdateMasterAttributes(attributesJson, callback);
#else
                HBLogger.W(TAG, "UpdateMasterAttributes: 当前平台不支持");
                NotifyFailure(callback, HelpBotErrorCode.NOT_SUPPORTED, "当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "UpdateMasterAttributes 异常", e);
                NotifyFailure(callback, HelpBotErrorCode.INTERNAL_ERROR, $"更新属性异常: {e.Message}");
            }
        }

        /// <summary>
        /// 更新应用属性
        /// </summary>
        /// <param name="attributes">属性字典</param>
        /// <param name="callback">回调（可选）</param>
        public static void UpdateAppAttributes(Dictionary<string, object> attributes, IHelpBotCallback<object> callback = null)
        {
            if (attributes == null || attributes.Count == 0)
            {
                HBLogger.W(TAG, "UpdateAppAttributes: attributes 为空");
                NotifyFailure(callback, HelpBotErrorCode.INVALID_PARAMETER, "attributes 不能为空");
                return;
            }

            EnsureInstance();

            try
            {
                string attributesJson = DictToJson(attributes);
                HBLogger.D(TAG, $"UpdateAppAttributes: {attributesJson}");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidUpdateAppAttributes(attributesJson, callback);
#elif UNITY_IOS && !UNITY_EDITOR
                IOSUpdateAppAttributes(attributesJson, callback);
#else
                HBLogger.W(TAG, "UpdateAppAttributes: 当前平台不支持");
                NotifyFailure(callback, HelpBotErrorCode.NOT_SUPPORTED, "当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "UpdateAppAttributes 异常", e);
                NotifyFailure(callback, HelpBotErrorCode.INTERNAL_ERROR, $"更新属性异常: {e.Message}");
            }
        }

        /// <summary>
        /// 获取 SDK 版本
        /// </summary>
        /// <returns>SDK 版本字符串</returns>
        public static string GetSDKVersion()
        {
            return SDK_VERSION;
        }

        /// <summary>
        /// 发送文本消息
        /// </summary>
        /// <param name="message">消息内容</param>
        /// <param name="callback">回调(可选)</param>
        public static void SendMessageAsync(string message, IHelpBotCallback<Dictionary<string, object>> callback = null)
        {
            if (string.IsNullOrEmpty(message))
            {
                HBLogger.E(TAG, "SendMessageAsync: message 不能为空");
                NotifyMapFailure(callback, HelpBotErrorCode.INVALID_PARAMETER, "消息内容不能为空");
                return;
            }

            EnsureInstance();

            try
            {
                HBLogger.D(TAG, $"SendMessageAsync: message={message}");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidSendMessage(message, callback);
#elif UNITY_IOS && !UNITY_EDITOR
                IOSSendMessage(message, callback);
#else
                HBLogger.W(TAG, "SendMessageAsync: 当前平台不支持");
                NotifyMapFailure(callback, HelpBotErrorCode.NOT_SUPPORTED, "当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "SendMessageAsync 异常", e);
                NotifyMapFailure(callback, HelpBotErrorCode.INTERNAL_ERROR, $"发送消息异常: {e.Message}");
            }
        }

        /// <summary>
        /// 获取历史消息
        /// </summary>
        /// <param name="callback">回调(可选)</param>
        public static void GetHistoryMessagesAsync(IHelpBotCallback<Dictionary<string, object>> callback = null)
        {
            EnsureInstance();

            try
            {
                HBLogger.D(TAG, "GetHistoryMessagesAsync");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidGetHistoryMessages(callback);
#elif UNITY_IOS && !UNITY_EDITOR
                IOSGetHistoryMessages(callback);
#else
                HBLogger.W(TAG, "GetHistoryMessagesAsync: 当前平台不支持");
                NotifyMapFailure(callback, HelpBotErrorCode.NOT_SUPPORTED, "当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "GetHistoryMessagesAsync 异常", e);
                NotifyMapFailure(callback, HelpBotErrorCode.INTERNAL_ERROR, $"获取历史消息异常: {e.Message}");
            }
        }

        /// <summary>
        /// 分页加载更多历史消息
        /// </summary>
        /// <param name="limit">每页数量</param>
        /// <param name="offset">偏移量</param>
        /// <param name="callback">回调(可选)</param>
        public static void LoadMoreMessagesAsync(int limit, int offset, IHelpBotCallback<Dictionary<string, object>> callback = null)
        {
            if (limit <= 0)
            {
                HBLogger.E(TAG, "LoadMoreMessagesAsync: limit 必须大于 0");
                NotifyMapFailure(callback, HelpBotErrorCode.INVALID_PARAMETER, "limit 必须大于 0");
                return;
            }

            EnsureInstance();

            try
            {
                HBLogger.D(TAG, $"LoadMoreMessagesAsync: limit={limit}, offset={offset}");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidLoadMoreMessages(limit, offset, callback);
#elif UNITY_IOS && !UNITY_EDITOR
                IOSLoadMoreMessages(limit, offset, callback);
#else
                HBLogger.W(TAG, "LoadMoreMessagesAsync: 当前平台不支持");
                NotifyMapFailure(callback, HelpBotErrorCode.NOT_SUPPORTED, "当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "LoadMoreMessagesAsync 异常", e);
                NotifyMapFailure(callback, HelpBotErrorCode.INTERNAL_ERROR, $"加载更多消息异常: {e.Message}");
            }
        }

        /// <summary>
        /// 显示 FAQ 分组页面
        /// </summary>
        /// <param name="sectionPublishId">分组 ID</param>
        /// <param name="configMap">配置参数(可选)</param>
        public static void ShowFAQSection(string sectionPublishId, Dictionary<string, object> configMap = null)
        {
            if (string.IsNullOrEmpty(sectionPublishId))
            {
                HBLogger.E(TAG, "ShowFAQSection: sectionPublishId 不能为空");
                return;
            }

            EnsureInstance();

            try
            {
                string configJson = configMap != null ? DictToJson(configMap) : "{}";
                HBLogger.D(TAG, $"ShowFAQSection: sectionPublishId={sectionPublishId}");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidShowFAQSection(sectionPublishId, configJson);
#elif UNITY_IOS && !UNITY_EDITOR
                IOSShowFAQSection(sectionPublishId, configJson);
#else
                HBLogger.W(TAG, "ShowFAQSection: 当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "ShowFAQSection 异常", e);
            }
        }

        /// <summary>
        /// 显示单个 FAQ
        /// </summary>
        /// <param name="questionPublishId">问题 ID</param>
        /// <param name="configMap">配置参数(可选)</param>
        public static void ShowSingleFAQ(string questionPublishId, Dictionary<string, object> configMap = null)
        {
            if (string.IsNullOrEmpty(questionPublishId))
            {
                HBLogger.E(TAG, "ShowSingleFAQ: questionPublishId 不能为空");
                return;
            }

            EnsureInstance();

            try
            {
                string configJson = configMap != null ? DictToJson(configMap) : "{}";
                HBLogger.D(TAG, $"ShowSingleFAQ: questionPublishId={questionPublishId}");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidShowSingleFAQ(questionPublishId, configJson);
#elif UNITY_IOS && !UNITY_EDITOR
                IOSShowSingleFAQ(questionPublishId, configJson);
#else
                HBLogger.W(TAG, "ShowSingleFAQ: 当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "ShowSingleFAQ 异常", e);
            }
        }

        /// <summary>
        /// 隐藏对话窗口(不销毁会话)
        /// </summary>
        public static void HideConversation()
        {
            EnsureInstance();

            try
            {
                HBLogger.D(TAG, "HideConversation");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidHideConversation();
#elif UNITY_IOS && !UNITY_EDITOR
                IOSHideConversation();
#else
                HBLogger.W(TAG, "HideConversation: 当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "HideConversation 异常", e);
            }
        }

        /// <summary>
        /// 检查对话窗口是否可见
        /// </summary>
        /// <returns>true 表示可见</returns>
        public static bool IsConversationVisible()
        {
            try
            {
#if UNITY_ANDROID && !UNITY_EDITOR
                return AndroidIsConversationVisible();
#elif UNITY_IOS && !UNITY_EDITOR
                return IOSIsConversationVisible();
#else
                HBLogger.W(TAG, "IsConversationVisible: 当前平台不支持");
                return false;
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "IsConversationVisible 异常", e);
                return false;
            }
        }

        /// <summary>
        /// 关闭当前会话
        /// </summary>
        public static void CloseSession()
        {
            EnsureInstance();

            try
            {
                HBLogger.D(TAG, "CloseSession");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidCloseSession();
#elif UNITY_IOS && !UNITY_EDITOR
                IOSCloseSession();
#else
                HBLogger.W(TAG, "CloseSession: 当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "CloseSession 异常", e);
            }
        }

        /// <summary>
        /// 更新 SDK Meta 数据
        /// </summary>
        /// <param name="meta">Meta 数据字典</param>
        public static void UpdateSDKMeta(Dictionary<string, object> meta)
        {
            if (meta == null || meta.Count == 0)
            {
                HBLogger.W(TAG, "UpdateSDKMeta: meta 为空");
                return;
            }

            EnsureInstance();

            try
            {
                string metaJson = DictToJson(meta);
                HBLogger.D(TAG, $"UpdateSDKMeta: {metaJson}");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidUpdateSDKMeta(metaJson);
#elif UNITY_IOS && !UNITY_EDITOR
                IOSUpdateSDKMeta(metaJson);
#else
                HBLogger.W(TAG, "UpdateSDKMeta: 当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "UpdateSDKMeta 异常", e);
            }
        }

        /// <summary>
        /// 更新自定义 Meta 数据
        /// </summary>
        /// <param name="customMeta">自定义 Meta 数据字典</param>
        public static void UpdateCustomMeta(Dictionary<string, object> customMeta)
        {
            if (customMeta == null || customMeta.Count == 0)
            {
                HBLogger.W(TAG, "UpdateCustomMeta: customMeta 为空");
                return;
            }

            EnsureInstance();

            try
            {
                string metaJson = DictToJson(customMeta);
                HBLogger.D(TAG, $"UpdateCustomMeta: {metaJson}");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidUpdateCustomMeta(metaJson);
#elif UNITY_IOS && !UNITY_EDITOR
                IOSUpdateCustomMeta(metaJson);
#else
                HBLogger.W(TAG, "UpdateCustomMeta: 当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "UpdateCustomMeta 异常", e);
            }
        }

        /// <summary>
        /// 添加 Issue 标签
        /// </summary>
        /// <param name="tags">标签列表</param>
        public static void AddIssueTags(List<string> tags)
        {
            if (tags == null || tags.Count == 0)
            {
                HBLogger.W(TAG, "AddIssueTags: tags 为空");
                return;
            }

            EnsureInstance();

            try
            {
                string tagsJson = ListToJson(tags);
                HBLogger.D(TAG, $"AddIssueTags: {tagsJson}");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidAddIssueTags(tagsJson);
#elif UNITY_IOS && !UNITY_EDITOR
                IOSAddIssueTags(tagsJson);
#else
                HBLogger.W(TAG, "AddIssueTags: 当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "AddIssueTags 异常", e);
            }
        }

        /// <summary>
        /// 移除 Issue 标签
        /// </summary>
        /// <param name="tags">标签列表</param>
        public static void RemoveIssueTags(List<string> tags)
        {
            if (tags == null || tags.Count == 0)
            {
                HBLogger.W(TAG, "RemoveIssueTags: tags 为空");
                return;
            }

            EnsureInstance();

            try
            {
                string tagsJson = ListToJson(tags);
                HBLogger.D(TAG, $"RemoveIssueTags: {tagsJson}");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidRemoveIssueTags(tagsJson);
#elif UNITY_IOS && !UNITY_EDITOR
                IOSRemoveIssueTags(tagsJson);
#else
                HBLogger.W(TAG, "RemoveIssueTags: 当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "RemoveIssueTags 异常", e);
            }
        }

        /// <summary>
        /// 启用/禁用 SSE 通知
        /// </summary>
        /// <param name="enable">true 启用, false 禁用</param>
        public static void EnableSseNotification(bool enable)
        {
            EnsureInstance();

            try
            {
                HBLogger.D(TAG, $"EnableSseNotification: {enable}");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidEnableSseNotification(enable);
#elif UNITY_IOS && !UNITY_EDITOR
                IOSEnableSseNotification(enable);
#else
                HBLogger.W(TAG, "EnableSseNotification: 当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "EnableSseNotification 异常", e);
            }
        }

        /// <summary>
        /// 检查 SSE 通知状态
        /// </summary>
        /// <returns>true 表示已启用</returns>
        public static bool IsSseNotificationEnabled()
        {
            try
            {
#if UNITY_ANDROID && !UNITY_EDITOR
                return AndroidIsSseNotificationEnabled();
#elif UNITY_IOS && !UNITY_EDITOR
                return IOSIsSseNotificationEnabled();
#else
                HBLogger.W(TAG, "IsSseNotificationEnabled: 当前平台不支持");
                return false;
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "IsSseNotificationEnabled 异常", e);
                return false;
            }
        }

        /// <summary>
        /// 获取 SDK 配置
        /// </summary>
        /// <returns>SDK 配置对象, 未初始化则返回 null</returns>
        public static HelpBotConfig GetConfig()
        {
            // 注意: Unity SDK 当前不缓存配置对象
            // 如需实现,需要在 Install 时保存配置
            HBLogger.W(TAG, "GetConfig: Unity SDK 暂不支持获取配置对象");
            return null;
        }

        /// <summary>
        /// 检查 Debug 模式
        /// </summary>
        /// <returns>true 表示 Debug 模式</returns>
        public static bool IsDebugMode()
        {
            try
            {
#if UNITY_ANDROID && !UNITY_EDITOR
                return AndroidIsDebugMode();
#elif UNITY_IOS && !UNITY_EDITOR
                return IOSIsDebugMode();
#else
                // Unity Editor 默认为 Debug 模式
                return Debug.isDebugBuild;
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "IsDebugMode 异常", e);
                return false;
            }
        }

        /// <summary>
        /// 检查初始化状态
        /// </summary>
        /// <returns>true 表示已初始化</returns>
        public static bool IsInitialized()
        {
            try
            {
#if UNITY_ANDROID && !UNITY_EDITOR
                return AndroidIsInitialized();
#elif UNITY_IOS && !UNITY_EDITOR
                return IOSIsInitialized();
#else
                HBLogger.W(TAG, "IsInitialized: 当前平台不支持");
                return false;
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "IsInitialized 异常", e);
                return false;
            }
        }

        /// <summary>
        /// 获取 WebSDK 健康快照
        /// </summary>
        /// <returns>健康快照数据</returns>
        public static Dictionary<string, object> GetWebSdkHealthSnapshot()
        {
            try
            {
#if UNITY_ANDROID && !UNITY_EDITOR
                return AndroidGetWebSdkHealthSnapshot();
#elif UNITY_IOS && !UNITY_EDITOR
                return IOSGetWebSdkHealthSnapshot();
#else
                HBLogger.W(TAG, "GetWebSdkHealthSnapshot: 当前平台不支持");
                return new Dictionary<string, object>();
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "GetWebSdkHealthSnapshot 异常", e);
                return new Dictionary<string, object>();
            }
        }

        /// <summary>
        /// 上报系统信息到服务器
        /// </summary>
        public static void ReportSystemInfoToServer()
        {
            EnsureInstance();

            try
            {
                HBLogger.D(TAG, "ReportSystemInfoToServer");

#if UNITY_ANDROID && !UNITY_EDITOR
                AndroidReportSystemInfoToServer();
#elif UNITY_IOS && !UNITY_EDITOR
                IOSReportSystemInfoToServer();
#else
                HBLogger.W(TAG, "ReportSystemInfoToServer: 当前平台不支持");
#endif
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "ReportSystemInfoToServer 异常", e);
            }
        }

#if UNITY_ANDROID && !UNITY_EDITOR
        /// <summary>
        /// 设置通知小图标资源 ID (Android Only)
        /// </summary>
        /// <param name="resId">资源 ID</param>
        public static void SetNotificationSmallIconResId(int resId)
        {
            try
            {
                HBLogger.D(TAG, $"SetNotificationSmallIconResId: {resId}");
                AndroidSetNotificationSmallIconResId(resId);
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "SetNotificationSmallIconResId 异常", e);
            }
        }

        /// <summary>
        /// 设置通知渠道 ID (Android Only)
        /// </summary>
        /// <param name="channelId">渠道 ID</param>
        public static void SetNotificationChannelId(string channelId)
        {
            if (string.IsNullOrEmpty(channelId))
            {
                HBLogger.E(TAG, "SetNotificationChannelId: channelId 不能为空");
                return;
            }

            try
            {
                HBLogger.D(TAG, $"SetNotificationChannelId: {channelId}");
                AndroidSetNotificationChannelId(channelId);
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "SetNotificationChannelId 异常", e);
            }
        }
#endif

        #endregion

        #region Android Native Bridge

#if UNITY_ANDROID && !UNITY_EDITOR
        private static AndroidJavaObject bridgeObject;

        private static void AndroidInstall(string configJson, IHelpBotInitCallback callback)
        {
            try
            {
                if (bridgeObject == null)
                {
                    using (AndroidJavaClass unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
                    using (AndroidJavaObject activity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity"))
                    using (AndroidJavaObject context = activity.Call<AndroidJavaObject>("getApplicationContext"))
                    {
                        bridgeObject = new AndroidJavaObject("com.example.HelpBot.unity.HelpBotUnityBridge", context);
                    }
                }

                string callbackId = RegisterInitCallback(callback);
                bridgeObject.Call("install", configJson, instance.gameObject.name, callbackId);
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "AndroidInstall 异常", e);
                NotifyInitFailure(callback, HelpBotErrorCode.INTERNAL_ERROR, $"Android Install 失败: {e.Message}");
            }
        }

        private static void AndroidLogin(string token, string loginConfigJson, IHelpBotCallback<object> callback)
        {
            try
            {
                string callbackId = RegisterCallback(callback);
                bridgeObject.Call("login", token, loginConfigJson, instance.gameObject.name, callbackId);
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "AndroidLogin 异常", e);
                NotifyFailure(callback, HelpBotErrorCode.INTERNAL_ERROR, $"Android Login 失败: {e.Message}");
            }
        }

        private static void AndroidShowConversation()
        {
            bridgeObject.Call("showConversation");
        }

        private static void AndroidShowFAQs(string configJson)
        {
            bridgeObject.Call("showFAQs", configJson);
        }

        private static void AndroidLogout(IHelpBotCallback<object> callback)
        {
            string callbackId = RegisterCallback(callback);
            bridgeObject.Call("logout", instance.gameObject.name, callbackId);
        }

        private static void AndroidDestroy()
        {
            bridgeObject.Call("destroy");
        }

        private static void AndroidSetEventsListener(bool enabled)
        {
            if (enabled)
            {
                bridgeObject.Call("setEventsListener", instance.gameObject.name, "OnEventOccurredNative", "OnAuthFailureNative");
            }
            else
            {
                bridgeObject.Call("clearEventsListener");
            }
        }

        private static void AndroidUpdateMasterAttributes(string attributesJson, IHelpBotCallback<object> callback)
        {
            string callbackId = RegisterCallback(callback);
            bridgeObject.Call("updateMasterAttributes", attributesJson, instance.gameObject.name, callbackId);
        }

        private static void AndroidUpdateAppAttributes(string attributesJson, IHelpBotCallback<object> callback)
        {
            string callbackId = RegisterCallback(callback);
            bridgeObject.Call("updateAppAttributes", attributesJson, instance.gameObject.name, callbackId);
        }

        private static void AndroidSendMessage(string message, IHelpBotCallback<Dictionary<string, object>> callback)
        {
            string callbackId = RegisterMapCallback(callback);
            bridgeObject.Call("sendMessage", message, instance.gameObject.name, callbackId);
        }

        private static void AndroidGetHistoryMessages(IHelpBotCallback<Dictionary<string, object>> callback)
        {
            string callbackId = RegisterMapCallback(callback);
            bridgeObject.Call("getHistoryMessages", instance.gameObject.name, callbackId);
        }

        private static void AndroidLoadMoreMessages(int limit, int offset, IHelpBotCallback<Dictionary<string, object>> callback)
        {
            string callbackId = RegisterMapCallback(callback);
            bridgeObject.Call("loadMoreMessages", limit, offset, instance.gameObject.name, callbackId);
        }

        private static void AndroidShowFAQSection(string sectionPublishId, string configJson)
        {
            bridgeObject.Call("showFAQSection", sectionPublishId, configJson);
        }

        private static void AndroidShowSingleFAQ(string questionPublishId, string configJson)
        {
            bridgeObject.Call("showSingleFAQ", questionPublishId, configJson);
        }

        private static void AndroidHideConversation()
        {
            bridgeObject.Call("hideConversation");
        }

        private static bool AndroidIsConversationVisible()
        {
            return bridgeObject.Call<bool>("isConversationVisible");
        }

        private static void AndroidCloseSession()
        {
            bridgeObject.Call("closeSession");
        }

        private static void AndroidUpdateSDKMeta(string metaJson)
        {
            bridgeObject.Call("updateSDKMeta", metaJson);
        }

        private static void AndroidUpdateCustomMeta(string metaJson)
        {
            bridgeObject.Call("updateCustomMeta", metaJson);
        }

        private static void AndroidAddIssueTags(string tagsJson)
        {
            bridgeObject.Call("addIssueTags", tagsJson);
        }

        private static void AndroidRemoveIssueTags(string tagsJson)
        {
            bridgeObject.Call("removeIssueTags", tagsJson);
        }

        private static void AndroidEnableSseNotification(bool enable)
        {
            bridgeObject.Call("enableSseNotification", enable);
        }

        private static bool AndroidIsSseNotificationEnabled()
        {
            return bridgeObject.Call<bool>("isSseNotificationEnabled");
        }

        private static bool AndroidIsDebugMode()
        {
            return bridgeObject.Call<bool>("isDebugMode");
        }

        private static bool AndroidIsInitialized()
        {
            return bridgeObject.Call<bool>("isInitialized");
        }

        private static Dictionary<string, object> AndroidGetWebSdkHealthSnapshot()
        {
            try
            {
                string jsonStr = bridgeObject.Call<string>("getWebSdkHealthSnapshot");
                return JsonToDict(jsonStr);
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "AndroidGetWebSdkHealthSnapshot 异常", e);
                return new Dictionary<string, object>();
            }
        }

        private static void AndroidReportSystemInfoToServer()
        {
            bridgeObject.Call("reportSystemInfoToServer");
        }

        private static void AndroidSetNotificationSmallIconResId(int resId)
        {
            bridgeObject.Call("setNotificationSmallIconResId", resId);
        }

        private static void AndroidSetNotificationChannelId(string channelId)
        {
            bridgeObject.Call("setNotificationChannelId", channelId);
        }
#endif

        #endregion

        #region iOS Native Bridge

#if UNITY_IOS && !UNITY_EDITOR
        [DllImport("__Internal")]
        private static extern void HelpBot_Install(string configJson, string gameObjectName, string callbackMethod);

        [DllImport("__Internal")]
        private static extern void HelpBot_Login(string token, string loginConfigJson, string gameObjectName, string callbackMethod);

        [DllImport("__Internal")]
        private static extern void HelpBot_ShowConversation();

        [DllImport("__Internal")]
        private static extern void HelpBot_ShowFAQs(string configJson);

        [DllImport("__Internal")]
        private static extern void HelpBot_Logout(string gameObjectName, string callbackMethod);

        [DllImport("__Internal")]
        private static extern void HelpBot_Destroy();

        [DllImport("__Internal")]
        private static extern void HelpBot_SetEventsListener(string gameObjectName, string eventMethod, string authFailureMethod);

        [DllImport("__Internal")]
        private static extern void HelpBot_ClearEventsListener();

        [DllImport("__Internal")]
        private static extern void HelpBot_UpdateMasterAttributes(string attributesJson, string gameObjectName, string callbackMethod);

        [DllImport("__Internal")]
        private static extern void HelpBot_UpdateAppAttributes(string attributesJson, string gameObjectName, string callbackMethod);

        [DllImport("__Internal")]
        private static extern void HelpBot_SendMessage(string message, string gameObjectName, string callbackMethod);

        [DllImport("__Internal")]
        private static extern void HelpBot_GetHistoryMessages(string gameObjectName, string callbackMethod);

        [DllImport("__Internal")]
        private static extern void HelpBot_LoadMoreMessages(int limit, int offset, string gameObjectName, string callbackMethod);

        [DllImport("__Internal")]
        private static extern void HelpBot_ShowFAQSection(string sectionPublishId, string configJson);

        [DllImport("__Internal")]
        private static extern void HelpBot_ShowSingleFAQ(string questionPublishId, string configJson);

        [DllImport("__Internal")]
        private static extern void HelpBot_HideConversation();

        [DllImport("__Internal")]
        private static extern bool HelpBot_IsConversationVisible();

        [DllImport("__Internal")]
        private static extern void HelpBot_CloseSession();

        [DllImport("__Internal")]
        private static extern void HelpBot_UpdateSDKMeta(string metaJson);

        [DllImport("__Internal")]
        private static extern void HelpBot_UpdateCustomMeta(string metaJson);

        [DllImport("__Internal")]
        private static extern void HelpBot_AddIssueTags(string tagsJson);

        [DllImport("__Internal")]
        private static extern void HelpBot_RemoveIssueTags(string tagsJson);

        [DllImport("__Internal")]
        private static extern void HelpBot_EnableSseNotification(bool enable);

        [DllImport("__Internal")]
        private static extern bool HelpBot_IsSseNotificationEnabled();

        [DllImport("__Internal")]
        private static extern bool HelpBot_IsDebugMode();

        [DllImport("__Internal")]
        private static extern bool HelpBot_IsInitialized();

        [DllImport("__Internal")]
        private static extern string HelpBot_GetWebSdkHealthSnapshot();

        [DllImport("__Internal")]
        private static extern void HelpBot_ReportSystemInfoToServer();

        [DllImport("__Internal")]
        private static extern void HelpBot_SetNotificationSmallIconResId(int resId);

        [DllImport("__Internal")]
        private static extern void HelpBot_SetNotificationChannelId(string channelId);

        private static void IOSInstall(string configJson, IHelpBotInitCallback callback)
        {
            string callbackId = RegisterInitCallback(callback);
            HelpBot_Install(configJson, instance.gameObject.name, callbackId);
        }

        private static void IOSLogin(string token, string loginConfigJson, IHelpBotCallback<object> callback)
        {
            string callbackId = RegisterCallback(callback);
            HelpBot_Login(token, loginConfigJson, instance.gameObject.name, callbackId);
        }

        private static void IOSShowConversation()
        {
            HelpBot_ShowConversation();
        }

        private static void IOSShowFAQs(string configJson)
        {
            HelpBot_ShowFAQs(configJson);
        }

        private static void IOSLogout(IHelpBotCallback<object> callback)
        {
            string callbackId = RegisterCallback(callback);
            HelpBot_Logout(instance.gameObject.name, callbackId);
        }

        private static void IOSDestroy()
        {
            HelpBot_Destroy();
        }

        private static void IOSSetEventsListener(bool enabled)
        {
            if (enabled)
            {
                HelpBot_SetEventsListener(instance.gameObject.name, "OnEventOccurredNative", "OnAuthFailureNative");
            }
            else
            {
                HelpBot_ClearEventsListener();
            }
        }

        private static void IOSUpdateMasterAttributes(string attributesJson, IHelpBotCallback<object> callback)
        {
            string callbackId = RegisterCallback(callback);
            HelpBot_UpdateMasterAttributes(attributesJson, instance.gameObject.name, callbackId);
        }

        private static void IOSUpdateAppAttributes(string attributesJson, IHelpBotCallback<object> callback)
        {
            string callbackId = RegisterCallback(callback);
            HelpBot_UpdateAppAttributes(attributesJson, instance.gameObject.name, callbackId);
        }

        private static void IOSSendMessage(string message, IHelpBotCallback<Dictionary<string, object>> callback)
        {
            string callbackId = RegisterMapCallback(callback);
            HelpBot_SendMessage(message, instance.gameObject.name, callbackId);
        }

        private static void IOSGetHistoryMessages(IHelpBotCallback<Dictionary<string, object>> callback)
        {
            string callbackId = RegisterMapCallback(callback);
            HelpBot_GetHistoryMessages(instance.gameObject.name, callbackId);
        }

        private static void IOSLoadMoreMessages(int limit, int offset, IHelpBotCallback<Dictionary<string, object>> callback)
        {
            string callbackId = RegisterMapCallback(callback);
            HelpBot_LoadMoreMessages(limit, offset, instance.gameObject.name, callbackId);
        }

        private static void IOSShowFAQSection(string sectionPublishId, string configJson)
        {
            HelpBot_ShowFAQSection(sectionPublishId, configJson);
        }

        private static void IOSShowSingleFAQ(string questionPublishId, string configJson)
        {
            HelpBot_ShowSingleFAQ(questionPublishId, configJson);
        }

        private static void IOSHideConversation()
        {
            HelpBot_HideConversation();
        }

        private static bool IOSIsConversationVisible()
        {
            return HelpBot_IsConversationVisible();
        }

        private static void IOSCloseSession()
        {
            HelpBot_CloseSession();
        }

        private static void IOSUpdateSDKMeta(string metaJson)
        {
            HelpBot_UpdateSDKMeta(metaJson);
        }

        private static void IOSUpdateCustomMeta(string metaJson)
        {
            HelpBot_UpdateCustomMeta(metaJson);
        }

        private static void IOSAddIssueTags(string tagsJson)
        {
            HelpBot_AddIssueTags(tagsJson);
        }

        private static void IOSRemoveIssueTags(string tagsJson)
        {
            HelpBot_RemoveIssueTags(tagsJson);
        }

        private static void IOSEnableSseNotification(bool enable)
        {
            HelpBot_EnableSseNotification(enable);
        }

        private static bool IOSIsSseNotificationEnabled()
        {
            return HelpBot_IsSseNotificationEnabled();
        }

        private static bool IOSIsDebugMode()
        {
            return HelpBot_IsDebugMode();
        }

        private static bool IOSIsInitialized()
        {
            return HelpBot_IsInitialized();
        }

        private static Dictionary<string, object> IOSGetWebSdkHealthSnapshot()
        {
            try
            {
                string jsonStr = HelpBot_GetWebSdkHealthSnapshot();
                return JsonToDict(jsonStr);
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "IOSGetWebSdkHealthSnapshot 异常", e);
                return new Dictionary<string, object>();
            }
        }

        private static void IOSReportSystemInfoToServer()
        {
            HelpBot_ReportSystemInfoToServer();
        }
#endif

        #endregion

        #region Callback Management

        private static readonly Dictionary<string, IHelpBotInitCallback> initCallbacks = new Dictionary<string, IHelpBotInitCallback>();
        private static readonly Dictionary<string, IHelpBotCallback<object>> callbacks = new Dictionary<string, IHelpBotCallback<object>>();
        private static readonly Dictionary<string, IHelpBotCallback<Dictionary<string, object>>> mapCallbacks = new Dictionary<string, IHelpBotCallback<Dictionary<string, object>>>();
        private static int callbackIdCounter = 0;

        private static string RegisterInitCallback(IHelpBotInitCallback callback)
        {
            if (callback == null) return "null";

            string id = $"init_{callbackIdCounter++}";
            lock (lockObj)
            {
                initCallbacks[id] = callback;
            }
            return id;
        }

        private static string RegisterCallback(IHelpBotCallback<object> callback)
        {
            if (callback == null) return "null";

            string id = $"cb_{callbackIdCounter++}";
            lock (lockObj)
            {
                callbacks[id] = callback;
            }
            return id;
        }

        private static string RegisterMapCallback(IHelpBotCallback<Dictionary<string, object>> callback)
        {
            if (callback == null) return "null";

            string id = $"map_{callbackIdCounter++}";
            lock (lockObj)
            {
                mapCallbacks[id] = callback;
            }
            return id;
        }

        // 以下方法由 Native Bridge 调用（通过 UnitySendMessage）

        public void OnInitStart(string callbackId)
        {
            EnqueueCallback(() =>
            {
                IHelpBotInitCallback callback;
                lock (lockObj)
                {
                    if (!initCallbacks.TryGetValue(callbackId, out callback)) return;
                }
                callback?.OnInitStart();
            });
        }

        public void OnInitProgress(string message)
        {
            // message 格式: "callbackId|progress|progressMessage"
            var parts = message.Split('|');
            if (parts.Length < 3) return;

            string callbackId = parts[0];
            int progress = int.Parse(parts[1]);
            string progressMessage = parts[2];

            EnqueueCallback(() =>
            {
                IHelpBotInitCallback callback;
                lock (lockObj)
                {
                    if (!initCallbacks.TryGetValue(callbackId, out callback)) return;
                }
                callback?.OnInitProgress(progress, progressMessage);
            });
        }

        public void OnInitSuccess(string callbackId)
        {
            EnqueueCallback(() =>
            {
                IHelpBotInitCallback callback;
                lock (lockObj)
                {
                    if (!initCallbacks.TryGetValue(callbackId, out callback)) return;
                    initCallbacks.Remove(callbackId);
                }
                callback?.OnInitSuccess();
            });
        }

        public void OnInitFailure(string message)
        {
            // message 格式: "callbackId|errorCode|errorMessage"
            var parts = message.Split(new[] { '|' }, 3);
            if (parts.Length < 3) return;

            string callbackId = parts[0];
            int errorCode = int.Parse(parts[1]);
            string errorMessage = parts[2];

            EnqueueCallback(() =>
            {
                IHelpBotInitCallback callback;
                lock (lockObj)
                {
                    if (!initCallbacks.TryGetValue(callbackId, out callback)) return;
                    initCallbacks.Remove(callbackId);
                }
                callback?.OnInitFailure(HelpBotErrorCodeExtensions.FromCode(errorCode), errorMessage);
            });
        }

        public void OnSuccess(string callbackId)
        {
            EnqueueCallback(() =>
            {
                IHelpBotCallback<object> callback;
                lock (lockObj)
                {
                    if (!callbacks.TryGetValue(callbackId, out callback)) return;
                    callbacks.Remove(callbackId);
                }
                callback?.OnSuccess(null);
            });
        }

        public void OnFailure(string message)
        {
            // message 格式: "callbackId|errorCode|errorMessage"
            var parts = message.Split(new[] { '|' }, 3);
            if (parts.Length < 3) return;

            string callbackId = parts[0];
            int errorCode = int.Parse(parts[1]);
            string errorMessage = parts[2];

            EnqueueCallback(() =>
            {
                IHelpBotCallback<object> callback;
                lock (lockObj)
                {
                    if (!callbacks.TryGetValue(callbackId, out callback)) return;
                    callbacks.Remove(callbackId);
                }
                callback?.OnFailure(HelpBotErrorCodeExtensions.FromCode(errorCode), errorMessage);
            });
        }

        public void OnSuccessWithData(string message)
        {
            // message 格式: "callbackId|resultJson"
            var parts = message.Split(new[] { '|' }, 2);
            if (parts.Length < 2) return;

            string callbackId = parts[0];
            string resultJson = parts[1];

            EnqueueCallback(() =>
            {
                IHelpBotCallback<Dictionary<string, object>> callback;
                lock (lockObj)
                {
                    if (!mapCallbacks.TryGetValue(callbackId, out callback)) return;
                    mapCallbacks.Remove(callbackId);
                }

                try
                {
                    var result = JsonToDict(resultJson);
                    callback?.OnSuccess(result);
                }
                catch (Exception e)
                {
                    HBLogger.E(TAG, "OnSuccessWithData 解析 JSON 异常", e);
                    callback?.OnFailure(HelpBotErrorCode.INTERNAL_ERROR, $"解析返回数据失败: {e.Message}");
                }
            });
        }

        public void OnEventOccurredNative(string message)
        {
            // message 格式: "eventName|dataJson"
            var parts = message.Split(new[] { '|' }, 2);
            if (parts.Length < 2) return;

            string eventName = parts[0];
            string dataJson = parts[1];

            EnqueueCallback(() =>
            {
                eventsListener?.OnEventOccurred(eventName, dataJson);
            });
        }

        public void OnAuthFailureNative(string reasonStr)
        {
            HelpBotAuthenticationFailureReason reason = HelpBotAuthenticationFailureReason.UNKNOWN;
            if (Enum.TryParse(reasonStr, out HelpBotAuthenticationFailureReason parsed))
            {
                reason = parsed;
            }

            EnqueueCallback(() =>
            {
                eventsListener?.OnUserAuthenticationFailure(reason);
            });
        }

        private void EnqueueCallback(Action callback)
        {
            lock (callbackQueue)
            {
                callbackQueue.Enqueue(callback);
            }
        }

        #endregion

        #region Helper Methods

        private static void EnsureInstance()
        {
            if (instance == null)
            {
                GameObject go = new GameObject("HelpBotSDK");
                instance = go.AddComponent<HelpBot>();
                DontDestroyOnLoad(go);
            }
        }

        private static void NotifyInitFailure(IHelpBotInitCallback callback, HelpBotErrorCode errorCode, string errorMessage)
        {
            if (callback != null)
            {
                EnsureInstance();
                instance.EnqueueCallback(() => callback.OnInitFailure(errorCode, errorMessage));
            }
        }

        private static void NotifyFailure(IHelpBotCallback<object> callback, HelpBotErrorCode errorCode, string errorMessage)
        {
            if (callback != null)
            {
                EnsureInstance();
                instance.EnqueueCallback(() => callback.OnFailure(errorCode, errorMessage));
            }
        }

        private static void NotifyMapFailure(IHelpBotCallback<Dictionary<string, object>> callback, HelpBotErrorCode errorCode, string errorMessage)
        {
            if (callback != null)
            {
                EnsureInstance();
                instance.EnqueueCallback(() => callback.OnFailure(errorCode, errorMessage));
            }
        }

        private static string ConfigToJson(HelpBotConfig config)
        {
            var dict = new Dictionary<string, object>
            {
                { "channelId", config.ChannelId },
                { "domain", config.Domain },
                { "fullPrivacyMode", config.FullPrivacyMode },
                { "enableSseNotification", config.EnableSseNotification },
                { "initTimeoutMs", config.InitTimeoutMs },
                { "webViewLoadTimeoutMs", config.WebViewLoadTimeoutMs },
                { "useDevApi", config.UseDevApi }
            };

            if (!string.IsNullOrEmpty(config.CompanyId))
                dict["companyId"] = config.CompanyId;
            if (!string.IsNullOrEmpty(config.UserId))
                dict["userId"] = config.UserId;
            if (!string.IsNullOrEmpty(config.PreGeneratedToken))
                dict["preGeneratedToken"] = config.PreGeneratedToken;

            foreach (var kvp in config.CustomConfig)
            {
                dict[kvp.Key] = kvp.Value;
            }

            return DictToJson(dict);
        }

        private static string DictToJson(Dictionary<string, object> dict)
        {
            return JsonUtility.ToJson(new Serialization<string, object>(dict));
        }

        [Serializable]
        private class Serialization<TKey, TValue>
        {
            public List<TKey> keys;
            public List<TValue> values;

            public Serialization(Dictionary<TKey, TValue> dictionary)
            {
                keys = new List<TKey>(dictionary.Keys);
                values = new List<TValue>(dictionary.Values);
            }
        }

        private static Dictionary<string, object> JsonToDict(string jsonStr)
        {
            if (string.IsNullOrEmpty(jsonStr) || jsonStr == "{}")
            {
                return new Dictionary<string, object>();
            }

            try
            {
                // 简单的 JSON 解析(仅支持基本类型)
                // 注意: 这是简化版本,生产环境建议使用 Newtonsoft.Json 或 Unity 的 JsonUtility
                var dict = new Dictionary<string, object>();
                jsonStr = jsonStr.Trim();
                
                if (jsonStr.StartsWith("{") && jsonStr.EndsWith("}"))
                {
                    // 这里仅作为占位实现,实际应使用完整的 JSON 解析库
                    // Unity 项目中建议使用 Newtonsoft.Json
                    HBLogger.W(TAG, "JsonToDict: 使用简化版 JSON 解析,建议集成 Newtonsoft.Json");
                }
                
                return dict;
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "JsonToDict 异常", e);
                return new Dictionary<string, object>();
            }
        }

        private static string ListToJson(List<string> list)
        {
            if (list == null || list.Count == 0)
            {
                return "[]";
            }

            try
            {
                // 简单的 JSON 数组序列化
                var items = new List<string>();
                foreach (var item in list)
                {
                    // 简单转义,生产环境建议使用 Newtonsoft.Json
                    string escaped = item.Replace("\\", "\\\\").Replace("\"", "\\\"");
                    items.Add($"\"{escaped}\"");
                }
                return $"[{string.Join(",", items)}]";
            }
            catch (Exception e)
            {
                HBLogger.E(TAG, "ListToJson 异常", e);
                return "[]";
            }
        }

        #endregion
    }
}
