using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;

namespace HelpBot
{
    /// <summary>
    /// HelpBot SDK Unity 封装类
    /// 提供跨平台的统一 API 接口
    /// </summary>
    public class HelpBotSDK : MonoBehaviour
    {
        private static HelpBotSDK _instance;
        private static bool _isInitialized = false;
        
#if UNITY_ANDROID && !UNITY_EDITOR
        private static AndroidJavaClass _helpBotClass;
        private static AndroidJavaObject _currentActivity;
#elif UNITY_IOS && !UNITY_EDITOR
        // iOS Native 方法声明
        [DllImport("__Internal")]
        private static extern void HelpBot_iOS_Install(string channelId, string domain, IntPtr callback);
        
        [DllImport("__Internal")]
        private static extern void HelpBot_iOS_Login(string jwtToken, IntPtr callback);
        
        [DllImport("__Internal")]
        private static extern void HelpBot_iOS_ShowConversation(IntPtr callback);
        
        [DllImport("__Internal")]
        private static extern void HelpBot_iOS_ShowFAQs(IntPtr callback);
        
        [DllImport("__Internal")]
        private static extern bool HelpBot_iOS_IsInitialized();
        
        [DllImport("__Internal")]
        private static extern string HelpBot_iOS_GetSDKVersion();
#endif

        /// <summary>
        /// 获取单例实例
        /// </summary>
        public static HelpBotSDK Instance
        {
            get
            {
                if (_instance == null)
                {
                    GameObject go = new GameObject("HelpBotSDK");
                    _instance = go.AddComponent<HelpBotSDK>();
                    DontDestroyOnLoad(go);
                }
                return _instance;
            }
        }

        private void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
                return;
            }
            
            _instance = this;
            DontDestroyOnLoad(gameObject);
            
#if UNITY_ANDROID && !UNITY_EDITOR
            InitializeAndroid();
#endif
        }

#if UNITY_ANDROID && !UNITY_EDITOR
        private void InitializeAndroid()
        {
            try
            {
                _helpBotClass = new AndroidJavaClass("com.example.HelpBot.HelpBot");
                
                AndroidJavaClass unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
                _currentActivity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
                
                Debug.Log("[HelpBot] Android 初始化成功");
            }
            catch (Exception e)
            {
                Debug.LogError($"[HelpBot] Android 初始化失败: {e.Message}");
            }
        }
#endif

        /// <summary>
        /// 初始化 HelpBot SDK
        /// </summary>
        /// <param name="config">SDK 配置</param>
        /// <param name="callback">初始化回调</param>
        public void Install(HelpBotConfig config, Action<bool, string> callback = null)
        {
            Debug.Log($"[HelpBot] 开始初始化 - ChannelId: {config.ChannelId}, Domain: {config.Domain}");
            
#if UNITY_EDITOR
            Debug.LogWarning("[HelpBot] 编辑器模式，跳过实际初始化");
            callback?.Invoke(true, "编辑器模式模拟成功");
            _isInitialized = true;
            return;
#elif UNITY_ANDROID
            try
            {
                // 创建配置 Map
                AndroidJavaObject configMap = new AndroidJavaObject("java.util.HashMap");
                configMap.Call<AndroidJavaObject>("put", "fullPrivacyMode", 
                    new AndroidJavaObject("java.lang.Boolean", config.FullPrivacyMode));
                configMap.Call<AndroidJavaObject>("put", "enableSseNotification", 
                    new AndroidJavaObject("java.lang.Boolean", config.EnableSseNotification));
                configMap.Call<AndroidJavaObject>("put", "initTimeout", 
                    new AndroidJavaObject("java.lang.Integer", config.InitTimeout));
                configMap.Call<AndroidJavaObject>("put", "webViewLoadTimeout", 
                    new AndroidJavaObject("java.lang.Integer", config.WebViewLoadTimeout));

                // Demo 对齐：默认显示标题栏（宿主可按需传 false）
                configMap.Call<AndroidJavaObject>("put", "showTitleBar", 
                    new AndroidJavaObject("java.lang.Boolean", true));
                
                // 调用 install 方法
                _helpBotClass.CallStatic("install", _currentActivity, config.ChannelId, config.Domain, configMap);
                
                _isInitialized = true;
                Debug.Log("[HelpBot] SDK 初始化成功");
                callback?.Invoke(true, "SDK 初始化成功");
            }
            catch (Exception e)
            {
                Debug.LogError($"[HelpBot] SDK 初始化失败: {e.Message}");
                callback?.Invoke(false, $"SDK 初始化失败: {e.Message}");
            }
#elif UNITY_IOS
            try
            {
                HelpBot_iOS_Install(config.ChannelId, config.Domain, IntPtr.Zero);
                _isInitialized = true;
                Debug.Log("[HelpBot] iOS SDK 初始化成功");
                callback?.Invoke(true, "SDK 初始化成功");
            }
            catch (Exception e)
            {
                Debug.LogError($"[HelpBot] iOS SDK 初始化失败: {e.Message}");
                callback?.Invoke(false, $"SDK 初始化失败: {e.Message}");
            }
#else
            Debug.LogWarning("[HelpBot] 不支持的平台");
            callback?.Invoke(false, "不支持的平台");
#endif
        }

        /// <summary>
        /// 用户登录
        /// </summary>
        /// <param name="jwtToken">JWT 令牌</param>
        /// <param name="callback">登录回调</param>
        public void Login(string jwtToken, Action<bool, string> callback = null)
        {
            Debug.Log("[HelpBot] 开始登录");
            
#if UNITY_EDITOR
            Debug.LogWarning("[HelpBot] 编辑器模式，跳过实际登录");
            callback?.Invoke(true, "编辑器模式模拟成功");
            return;
#elif UNITY_ANDROID
            try
            {
                // 创建登录配置
                AndroidJavaObject loginConfig = new AndroidJavaObject("java.util.HashMap");
                loginConfig.Call<AndroidJavaObject>("put", "full_privacy_enabled", 
                    new AndroidJavaObject("java.lang.Boolean", false));
                
                _helpBotClass.CallStatic("login", jwtToken, loginConfig);
                
                Debug.Log("[HelpBot] 登录成功");
                callback?.Invoke(true, "登录成功");
            }
            catch (Exception e)
            {
                Debug.LogError($"[HelpBot] 登录失败: {e.Message}");
                callback?.Invoke(false, $"登录失败: {e.Message}");
            }
#elif UNITY_IOS
            try
            {
                HelpBot_iOS_Login(jwtToken, IntPtr.Zero);
                Debug.Log("[HelpBot] iOS 登录成功");
                callback?.Invoke(true, "登录成功");
            }
            catch (Exception e)
            {
                Debug.LogError($"[HelpBot] iOS 登录失败: {e.Message}");
                callback?.Invoke(false, $"登录失败: {e.Message}");
            }
#else
            callback?.Invoke(false, "不支持的平台");
#endif
        }

        /// <summary>
        /// 显示对话界面
        /// </summary>
        /// <param name="callback">操作回调</param>
        public void ShowConversation(Action<bool, string> callback = null)
        {
            Debug.Log("[HelpBot] 显示对话界面");
            
#if UNITY_EDITOR
            Debug.LogWarning("[HelpBot] 编辑器模式，无法显示对话界面");
            callback?.Invoke(false, "编辑器模式不支持");
            return;
#elif UNITY_ANDROID
            try
            {
                _helpBotClass.CallStatic("showConversation", _currentActivity);
                Debug.Log("[HelpBot] 对话界面已打开");
                callback?.Invoke(true, "对话界面已打开");
            }
            catch (Exception e)
            {
                Debug.LogError($"[HelpBot] 打开对话界面失败: {e.Message}");
                callback?.Invoke(false, $"打开对话界面失败: {e.Message}");
            }
#elif UNITY_IOS
            try
            {
                HelpBot_iOS_ShowConversation(IntPtr.Zero);
                Debug.Log("[HelpBot] iOS 对话界面已打开");
                callback?.Invoke(true, "对话界面已打开");
            }
            catch (Exception e)
            {
                Debug.LogError($"[HelpBot] iOS 打开对话界面失败: {e.Message}");
                callback?.Invoke(false, $"打开对话界面失败: {e.Message}");
            }
#else
            callback?.Invoke(false, "不支持的平台");
#endif
        }

        /// <summary>
        /// 显示 FAQ 列表
        /// </summary>
        public void ShowFAQs(Action<bool, string> callback = null)
        {
            Debug.Log("[HelpBot] 显示 FAQ 列表");
            
#if UNITY_EDITOR
            callback?.Invoke(false, "编辑器模式不支持");
            return;
#elif UNITY_ANDROID
            try
            {
                _helpBotClass.CallStatic("showFAQs", _currentActivity);
                callback?.Invoke(true, "FAQ 列表已打开");
            }
            catch (Exception e)
            {
                Debug.LogError($"[HelpBot] 打开 FAQ 失败: {e.Message}");
                callback?.Invoke(false, $"打开 FAQ 失败: {e.Message}");
            }
#elif UNITY_IOS
            try
            {
                HelpBot_iOS_ShowFAQs(IntPtr.Zero);
                callback?.Invoke(true, "FAQ 列表已打开");
            }
            catch (Exception e)
            {
                callback?.Invoke(false, $"打开 FAQ 失败: {e.Message}");
            }
#else
            callback?.Invoke(false, "不支持的平台");
#endif
        }

        /// <summary>
        /// 更新 SDK 元数据
        /// </summary>
        /// <param name="sdkMeta">SDK 元数据</param>
        public void UpdateSDKMeta(Dictionary<string, string> sdkMeta)
        {
            Debug.Log("[HelpBot] 更新 SDK Meta");
            
#if UNITY_EDITOR
            return;
#elif UNITY_ANDROID
            try
            {
                AndroidJavaObject metaMap = new AndroidJavaObject("java.util.HashMap");
                foreach (var pair in sdkMeta)
                {
                    metaMap.Call<AndroidJavaObject>("put", pair.Key, pair.Value);
                }
                
                _helpBotClass.CallStatic("updateSDKMeta", metaMap);
                Debug.Log("[HelpBot] SDK Meta 更新成功");
            }
            catch (Exception e)
            {
                Debug.LogError($"[HelpBot] 更新 SDK Meta 失败: {e.Message}");
            }
#endif
        }

        /// <summary>
        /// 更新自定义元数据
        /// </summary>
        /// <param name="customMeta">自定义元数据</param>
        public void UpdateCustomMeta(Dictionary<string, string> customMeta)
        {
            Debug.Log("[HelpBot] 更新 Custom Meta");
            
#if UNITY_EDITOR
            return;
#elif UNITY_ANDROID
            try
            {
                AndroidJavaObject metaMap = new AndroidJavaObject("java.util.HashMap");
                foreach (var pair in customMeta)
                {
                    metaMap.Call<AndroidJavaObject>("put", pair.Key, pair.Value);
                }
                
                _helpBotClass.CallStatic("updateCustomMeta", metaMap);
                Debug.Log("[HelpBot] Custom Meta 更新成功");
            }
            catch (Exception e)
            {
                Debug.LogError($"[HelpBot] 更新 Custom Meta 失败: {e.Message}");
            }
#endif
        }

        /// <summary>
        /// 检查 SDK 是否已初始化
        /// </summary>
        public bool IsInitialized()
        {
#if UNITY_EDITOR
            return _isInitialized;
#elif UNITY_ANDROID
            try
            {
                return _helpBotClass.CallStatic<bool>("isInitialized");
            }
            catch
            {
                return false;
            }
#elif UNITY_IOS
            try
            {
                return HelpBot_iOS_IsInitialized();
            }
            catch
            {
                return false;
            }
#else
            return false;
#endif
        }

        /// <summary>
        /// 获取 SDK 版本
        /// </summary>
        public string GetSDKVersion()
        {
#if UNITY_EDITOR
            return "0.1.13-Editor";
#elif UNITY_ANDROID
            try
            {
                return _helpBotClass.CallStatic<string>("getSDKVersion");
            }
            catch
            {
                return "Unknown";
            }
#elif UNITY_IOS
            try
            {
                return HelpBot_iOS_GetSDKVersion();
            }
            catch
            {
                return "Unknown";
            }
#else
            return "Unknown";
#endif
        }
    }
}
