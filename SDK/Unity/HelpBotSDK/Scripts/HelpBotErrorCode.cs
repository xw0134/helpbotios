using System;

namespace HelpBot
{
    /// <summary>
    /// HelpBot SDK 错误码定义
    /// 
    /// 统一的错误码体系，方便宿主应用进行错误处理和统计
    /// 完全对应 Android SDK 的错误码定义
    /// </summary>
    public enum HelpBotErrorCode
    {
        // ==================== 初始化相关错误 (1000-1099) ====================
        
        /// <summary>
        /// SDK 未初始化
        /// </summary>
        SDK_NOT_INITIALIZED = 1000,

        /// <summary>
        /// SDK 已初始化
        /// </summary>
        SDK_ALREADY_INITIALIZED = 1001,

        /// <summary>
        /// 参数无效
        /// </summary>
        INVALID_PARAMETER = 1002,

        /// <summary>
        /// Context 为 null
        /// </summary>
        CONTEXT_NULL = 1003,

        /// <summary>
        /// ChannelId 无效
        /// </summary>
        INVALID_CHANNEL_ID = 1004,

        /// <summary>
        /// Domain 无效
        /// </summary>
        INVALID_DOMAIN = 1005,

        // ==================== WebView 相关错误 (1100-1199) ====================
        
        /// <summary>
        /// WebView 组件不可用
        /// </summary>
        WEBVIEW_UNAVAILABLE = 1100,

        /// <summary>
        /// WebView 初始化失败
        /// </summary>
        WEBVIEW_INIT_FAILED = 1101,

        /// <summary>
        /// WebView 加载超时
        /// </summary>
        WEBVIEW_LOAD_TIMEOUT = 1102,

        /// <summary>
        /// WebView 加载失败
        /// </summary>
        WEBVIEW_LOAD_FAILED = 1103,

        /// <summary>
        /// WebView 已销毁
        /// </summary>
        WEBVIEW_DESTROYED = 1104,

        // ==================== 网络相关错误 (1200-1299) ====================
        
        /// <summary>
        /// 网络不可用
        /// </summary>
        NETWORK_UNAVAILABLE = 1200,

        /// <summary>
        /// 网络请求失败
        /// </summary>
        NETWORK_REQUEST_FAILED = 1201,

        /// <summary>
        /// 网络超时
        /// </summary>
        NETWORK_TIMEOUT = 1202,

        // ==================== 认证相关错误 (1300-1399) ====================
        
        /// <summary>
        /// Token 无效
        /// </summary>
        INVALID_TOKEN = 1300,

        /// <summary>
        /// Token 过期
        /// </summary>
        TOKEN_EXPIRED = 1301,

        /// <summary>
        /// 未登录
        /// </summary>
        NOT_LOGGED_IN = 1302,

        /// <summary>
        /// 登录失败
        /// </summary>
        LOGIN_FAILED = 1303,

        /// <summary>
        /// 缺少预生成 Token（preGeneratedToken）
        /// </summary>
        MISSING_PRE_GENERATED_TOKEN = 1304,

        /// <summary>
        /// 预生成 Token 无效（格式不正确或为空）
        /// </summary>
        INVALID_PRE_GENERATED_TOKEN = 1305,

        /// <summary>
        /// 已登录
        /// </summary>
        ALREADY_LOGGED_IN = 1306,

        // ==================== 存储相关错误 (1400-1499) ====================
        
        /// <summary>
        /// 存储失败
        /// </summary>
        STORAGE_FAILED = 1400,

        /// <summary>
        /// 读取失败
        /// </summary>
        READ_FAILED = 1401,

        /// <summary>
        /// 加密失败
        /// </summary>
        ENCRYPTION_FAILED = 1402,

        /// <summary>
        /// 解密失败
        /// </summary>
        DECRYPTION_FAILED = 1403,

        // ==================== 权限相关错误 (1500-1599) ====================
        
        /// <summary>
        /// 权限被拒绝
        /// </summary>
        PERMISSION_DENIED = 1500,

        /// <summary>
        /// 缺少必要权限
        /// </summary>
        PERMISSION_REQUIRED = 1501,

        // ==================== 其他错误 (9000-9999) ====================
        
        /// <summary>
        /// 未知错误
        /// </summary>
        UNKNOWN_ERROR = 9000,

        /// <summary>
        /// 内部错误
        /// </summary>
        INTERNAL_ERROR = 9001,

        /// <summary>
        /// 操作超时
        /// </summary>
        OPERATION_TIMEOUT = 9002,

        /// <summary>
        /// 操作被取消
        /// </summary>
        OPERATION_CANCELLED = 9003,

        /// <summary>
        /// 操作进行中（例如 install/login 并发重复调用）
        /// </summary>
        OPERATION_IN_PROGRESS = 9004,

        /// <summary>
        /// 功能暂不支持（用于对外 API 占位，避免误返回 success）
        /// </summary>
        NOT_SUPPORTED = 9005,

        /// <summary>
        /// 当前状态不允许该操作（例如：已成功 install 后重复 install、已成功 login 后重复 login）
        /// </summary>
        OPERATION_NOT_ALLOWED = 9006
    }

    /// <summary>
    /// HelpBotErrorCode 扩展方法
    /// </summary>
    public static class HelpBotErrorCodeExtensions
    {
        /// <summary>
        /// 获取错误码的数值
        /// </summary>
        public static int GetCode(this HelpBotErrorCode errorCode)
        {
            return (int)errorCode;
        }

        /// <summary>
        /// 获取错误描述
        /// </summary>
        public static string GetMessage(this HelpBotErrorCode errorCode)
        {
            switch (errorCode)
            {
                case HelpBotErrorCode.SDK_NOT_INITIALIZED:
                    return "SDK未初始化，请先调用 HelpBot.Install()";
                case HelpBotErrorCode.SDK_ALREADY_INITIALIZED:
                    return "SDK已初始化，请勿重复调用";
                case HelpBotErrorCode.INVALID_PARAMETER:
                    return "参数无效";
                case HelpBotErrorCode.CONTEXT_NULL:
                    return "Context 不能为 null";
                case HelpBotErrorCode.INVALID_CHANNEL_ID:
                    return "ChannelId 不能为空";
                case HelpBotErrorCode.INVALID_DOMAIN:
                    return "Domain 格式无效";
                case HelpBotErrorCode.WEBVIEW_UNAVAILABLE:
                    return "WebView组件不可用，部分设备可能未安装WebView";
                case HelpBotErrorCode.WEBVIEW_INIT_FAILED:
                    return "WebView初始化失败";
                case HelpBotErrorCode.WEBVIEW_LOAD_TIMEOUT:
                    return "WebView加载超时";
                case HelpBotErrorCode.WEBVIEW_LOAD_FAILED:
                    return "WebView加载失败";
                case HelpBotErrorCode.WEBVIEW_DESTROYED:
                    return "WebView已销毁";
                case HelpBotErrorCode.NETWORK_UNAVAILABLE:
                    return "网络不可用";
                case HelpBotErrorCode.NETWORK_REQUEST_FAILED:
                    return "网络请求失败";
                case HelpBotErrorCode.NETWORK_TIMEOUT:
                    return "网络请求超时";
                case HelpBotErrorCode.INVALID_TOKEN:
                    return "Token无效";
                case HelpBotErrorCode.TOKEN_EXPIRED:
                    return "Token已过期";
                case HelpBotErrorCode.NOT_LOGGED_IN:
                    return "用户未登录";
                case HelpBotErrorCode.LOGIN_FAILED:
                    return "登录失败";
                case HelpBotErrorCode.MISSING_PRE_GENERATED_TOKEN:
                    return "缺少预生成Token（preGeneratedToken）";
                case HelpBotErrorCode.INVALID_PRE_GENERATED_TOKEN:
                    return "预生成Token无效（preGeneratedToken）";
                case HelpBotErrorCode.ALREADY_LOGGED_IN:
                    return "用户已登录，请勿重复调用 login（如需切换账号请先 logout）";
                case HelpBotErrorCode.STORAGE_FAILED:
                    return "数据存储失败";
                case HelpBotErrorCode.READ_FAILED:
                    return "数据读取失败";
                case HelpBotErrorCode.ENCRYPTION_FAILED:
                    return "数据加密失败";
                case HelpBotErrorCode.DECRYPTION_FAILED:
                    return "数据解密失败";
                case HelpBotErrorCode.PERMISSION_DENIED:
                    return "权限被拒绝";
                case HelpBotErrorCode.PERMISSION_REQUIRED:
                    return "缺少必要权限";
                case HelpBotErrorCode.UNKNOWN_ERROR:
                    return "未知错误";
                case HelpBotErrorCode.INTERNAL_ERROR:
                    return "SDK内部错误";
                case HelpBotErrorCode.OPERATION_TIMEOUT:
                    return "操作超时";
                case HelpBotErrorCode.OPERATION_CANCELLED:
                    return "操作被取消";
                case HelpBotErrorCode.OPERATION_IN_PROGRESS:
                    return "操作进行中，请勿重复调用";
                case HelpBotErrorCode.NOT_SUPPORTED:
                    return "功能暂不支持";
                case HelpBotErrorCode.OPERATION_NOT_ALLOWED:
                    return "当前状态不允许该操作";
                default:
                    return "未知错误";
            }
        }

        /// <summary>
        /// 根据错误码数值获取枚举
        /// </summary>
        public static HelpBotErrorCode FromCode(int code)
        {
            if (Enum.IsDefined(typeof(HelpBotErrorCode), code))
            {
                return (HelpBotErrorCode)code;
            }
            return HelpBotErrorCode.UNKNOWN_ERROR;
        }
    }
}
