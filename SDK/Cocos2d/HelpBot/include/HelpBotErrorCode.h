#ifndef HELPBOT_ERROR_CODE_H
#define HELPBOT_ERROR_CODE_H

#include <string>

namespace helpbot {

/**
 * HelpBot SDK 错误码定义
 * 
 * 与 Android SDK 完全对齐的错误码体系
 */
enum class HelpBotErrorCode {
    // ==================== 初始化相关错误 (1000-1099) ====================
    SDK_NOT_INITIALIZED = 1000,           // SDK未初始化
    SDK_ALREADY_INITIALIZED = 1001,       // SDK已初始化
    INVALID_PARAMETER = 1002,             // 参数无效
    CONTEXT_NULL = 1003,                  // Context为null
    INVALID_CHANNEL_ID = 1004,            // ChannelId无效
    INVALID_DOMAIN = 1005,                // Domain无效

    // ==================== WebView 相关错误 (1100-1199) ====================
    WEBVIEW_UNAVAILABLE = 1100,           // WebView组件不可用
    WEBVIEW_INIT_FAILED = 1101,           // WebView初始化失败
    WEBVIEW_LOAD_TIMEOUT = 1102,          // WebView加载超时
    WEBVIEW_LOAD_FAILED = 1103,           // WebView加载失败
    WEBVIEW_DESTROYED = 1104,             // WebView已销毁

    // ==================== 网络相关错误 (1200-1299) ====================
    NETWORK_UNAVAILABLE = 1200,           // 网络不可用
    NETWORK_REQUEST_FAILED = 1201,        // 网络请求失败
    NETWORK_TIMEOUT = 1202,               // 网络超时

    // ==================== 认证相关错误 (1300-1399) ====================
    INVALID_TOKEN = 1300,                 // Token无效
    TOKEN_EXPIRED = 1301,                 // Token过期
    NOT_LOGGED_IN = 1302,                 // 未登录
    LOGIN_FAILED = 1303,                  // 登录失败
    MISSING_PRE_GENERATED_TOKEN = 1304,   // 缺少预生成Token
    INVALID_PRE_GENERATED_TOKEN = 1305,   // 预生成Token无效
    ALREADY_LOGGED_IN = 1306,             // 已登录

    // ==================== 存储相关错误 (1400-1499) ====================
    STORAGE_FAILED = 1400,                // 存储失败
    READ_FAILED = 1401,                   // 读取失败
    ENCRYPTION_FAILED = 1402,             // 加密失败
    DECRYPTION_FAILED = 1403,             // 解密失败

    // ==================== 权限相关错误 (1500-1599) ====================
    PERMISSION_DENIED = 1500,             // 权限被拒绝
    PERMISSION_REQUIRED = 1501,           // 缺少必要权限

    // ==================== 其他错误 (9000-9999) ====================
    UNKNOWN_ERROR = 9000,                 // 未知错误
    INTERNAL_ERROR = 9001,                // 内部错误
    OPERATION_TIMEOUT = 9002,             // 操作超时
    OPERATION_CANCELLED = 9003,           // 操作被取消
    OPERATION_IN_PROGRESS = 9004,         // 操作进行中
    NOT_SUPPORTED = 9005,                 // 功能暂不支持
    OPERATION_NOT_ALLOWED = 9006          // 操作不允许
};

/**
 * 获取错误码对应的错误信息
 */
inline std::string getErrorMessage(HelpBotErrorCode code) {
    switch (code) {
        case HelpBotErrorCode::SDK_NOT_INITIALIZED:
            return "SDK未初始化,请先调用 HelpBot::install()";
        case HelpBotErrorCode::SDK_ALREADY_INITIALIZED:
            return "SDK已初始化,请勿重复调用";
        case HelpBotErrorCode::INVALID_PARAMETER:
            return "参数无效";
        case HelpBotErrorCode::CONTEXT_NULL:
            return "Context不能为null";
        case HelpBotErrorCode::INVALID_CHANNEL_ID:
            return "ChannelId不能为空";
        case HelpBotErrorCode::INVALID_DOMAIN:
            return "Domain格式无效";
        case HelpBotErrorCode::WEBVIEW_UNAVAILABLE:
            return "WebView组件不可用,部分设备可能未安装WebView";
        case HelpBotErrorCode::WEBVIEW_INIT_FAILED:
            return "WebView初始化失败";
        case HelpBotErrorCode::WEBVIEW_LOAD_TIMEOUT:
            return "WebView加载超时";
        case HelpBotErrorCode::WEBVIEW_LOAD_FAILED:
            return "WebView加载失败";
        case HelpBotErrorCode::WEBVIEW_DESTROYED:
            return "WebView已销毁";
        case HelpBotErrorCode::NETWORK_UNAVAILABLE:
            return "网络不可用";
        case HelpBotErrorCode::NETWORK_REQUEST_FAILED:
            return "网络请求失败";
        case HelpBotErrorCode::NETWORK_TIMEOUT:
            return "网络请求超时";
        case HelpBotErrorCode::INVALID_TOKEN:
            return "Token无效";
        case HelpBotErrorCode::TOKEN_EXPIRED:
            return "Token已过期";
        case HelpBotErrorCode::NOT_LOGGED_IN:
            return "用户未登录";
        case HelpBotErrorCode::LOGIN_FAILED:
            return "登录失败";
        case HelpBotErrorCode::MISSING_PRE_GENERATED_TOKEN:
            return "缺少预生成Token(preGeneratedToken)";
        case HelpBotErrorCode::INVALID_PRE_GENERATED_TOKEN:
            return "预生成Token无效(preGeneratedToken)";
        case HelpBotErrorCode::ALREADY_LOGGED_IN:
            return "用户已登录,请勿重复调用login(如需切换账号请先logout)";
        case HelpBotErrorCode::STORAGE_FAILED:
            return "数据存储失败";
        case HelpBotErrorCode::READ_FAILED:
            return "数据读取失败";
        case HelpBotErrorCode::ENCRYPTION_FAILED:
            return "数据加密失败";
        case HelpBotErrorCode::DECRYPTION_FAILED:
            return "数据解密失败";
        case HelpBotErrorCode::PERMISSION_DENIED:
            return "权限被拒绝";
        case HelpBotErrorCode::PERMISSION_REQUIRED:
            return "缺少必要权限";
        case HelpBotErrorCode::UNKNOWN_ERROR:
            return "未知错误";
        case HelpBotErrorCode::INTERNAL_ERROR:
            return "SDK内部错误";
        case HelpBotErrorCode::OPERATION_TIMEOUT:
            return "操作超时";
        case HelpBotErrorCode::OPERATION_CANCELLED:
            return "操作被取消";
        case HelpBotErrorCode::OPERATION_IN_PROGRESS:
            return "操作进行中,请勿重复调用";
        case HelpBotErrorCode::NOT_SUPPORTED:
            return "功能暂不支持";
        case HelpBotErrorCode::OPERATION_NOT_ALLOWED:
            return "当前状态不允许该操作";
        default:
            return "未知错误";
    }
}

/**
 * 获取错误码的整数值
 */
inline int getErrorCode(HelpBotErrorCode code) {
    return static_cast<int>(code);
}

} // namespace helpbot

#endif // HELPBOT_ERROR_CODE_H
