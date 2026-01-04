package com.example.HelpBot.core;

/**
 * HelpBot SDK 错误码定义
 * 
 * 统一的错误码体系，方便宿主应用进行错误处理和统计
 */
public enum HelpBotErrorCode {

    // ==================== 初始化相关错误 (1000-1099) ====================
    /**
     * SDK 未初始化
     */
    SDK_NOT_INITIALIZED(1000, "SDK未初始化，请先调用 HelpBot.install()"),

    /**
     * SDK 已初始化
     */
    SDK_ALREADY_INITIALIZED(1001, "SDK已初始化，请勿重复调用"),

    /**
     * 参数无效
     */
    INVALID_PARAMETER(1002, "参数无效"),

    /**
     * Context 为 null
     */
    CONTEXT_NULL(1003, "Context 不能为 null"),

    /**
     * ChannelId 无效
     */
    INVALID_CHANNEL_ID(1004, "ChannelId 不能为空"),

    /**
     * Domain 无效
     */
    INVALID_DOMAIN(1005, "Domain 格式无效"),

    // ==================== WebView 相关错误 (1100-1199) ====================
    /**
     * WebView 组件不可用
     */
    WEBVIEW_UNAVAILABLE(1100, "WebView组件不可用，部分设备可能未安装WebView"),

    /**
     * WebView 初始化失败
     */
    WEBVIEW_INIT_FAILED(1101, "WebView初始化失败"),

    /**
     * WebView 加载超时
     */
    WEBVIEW_LOAD_TIMEOUT(1102, "WebView加载超时"),

    /**
     * WebView 加载失败
     */
    WEBVIEW_LOAD_FAILED(1103, "WebView加载失败"),

    /**
     * WebView 已销毁
     */
    WEBVIEW_DESTROYED(1104, "WebView已销毁"),

    // ==================== 网络相关错误 (1200-1299) ====================
    /**
     * 网络不可用
     */
    NETWORK_UNAVAILABLE(1200, "网络不可用"),

    /**
     * 网络请求失败
     */
    NETWORK_REQUEST_FAILED(1201, "网络请求失败"),

    /**
     * 网络超时
     */
    NETWORK_TIMEOUT(1202, "网络请求超时"),

    // ==================== 认证相关错误 (1300-1399) ====================
    /**
     * Token 无效
     */
    INVALID_TOKEN(1300, "Token无效"),

    /**
     * Token 过期
     */
    TOKEN_EXPIRED(1301, "Token已过期"),

    /**
     * 未登录
     */
    NOT_LOGGED_IN(1302, "用户未登录"),

    /**
     * 登录失败
     */
    LOGIN_FAILED(1303, "登录失败"),

    /**
     * 已登录
     */
    ALREADY_LOGGED_IN(1306, "用户已登录，请勿重复调用 login（如需切换账号请先 logout）"),

    /**
     * 生产环境缺少预生成 Token（preGeneratedToken）。
     * 
     * 说明：这是 WebSDK 的硬性规则。当 useDevAPI=false（默认生产模式）时，必须由宿主后端生成并下发 token。
     */
    MISSING_PRE_GENERATED_TOKEN(1304, "缺少预生成Token（preGeneratedToken）"),

    /**
     * 预生成 Token 无效（格式不正确或为空）。
     */
    INVALID_PRE_GENERATED_TOKEN(1305, "预生成Token无效（preGeneratedToken）"),

    // ==================== 存储相关错误 (1400-1499) ====================
    /**
     * 存储失败
     */
    STORAGE_FAILED(1400, "数据存储失败"),

    /**
     * 读取失败
     */
    READ_FAILED(1401, "数据读取失败"),

    /**
     * 加密失败
     */
    ENCRYPTION_FAILED(1402, "数据加密失败"),

    /**
     * 解密失败
     */
    DECRYPTION_FAILED(1403, "数据解密失败"),

    // ==================== 权限相关错误 (1500-1599) ====================
    /**
     * 权限被拒绝
     */
    PERMISSION_DENIED(1500, "权限被拒绝"),

    /**
     * 缺少必要权限
     */
    PERMISSION_REQUIRED(1501, "缺少必要权限"),

    // ==================== 其他错误 (9000-9999) ====================
    /**
     * 未知错误
     */
    UNKNOWN_ERROR(9000, "未知错误"),

    /**
     * 内部错误
     */
    INTERNAL_ERROR(9001, "SDK内部错误"),

    /**
     * 操作超时
     */
    OPERATION_TIMEOUT(9002, "操作超时"),

    /**
     * 操作被取消
     */
    OPERATION_CANCELLED(9003, "操作被取消"),

    /**
     * 操作进行中（例如 install/login 并发重复调用）。
     */
    OPERATION_IN_PROGRESS(9004, "操作进行中，请勿重复调用"),

    /**
     * 功能暂不支持（用于对外 API 占位，避免误返回 success）。
     */
    NOT_SUPPORTED(9005, "功能暂不支持"),

    /**
     * 当前状态不允许该操作（例如：已成功 install 后重复 install、已成功 login 后重复 login）。
     */
    OPERATION_NOT_ALLOWED(9006, "当前状态不允许该操作");

    private final int code;
    private final String message;

    HelpBotErrorCode(final int code, final String message) {
        this.code = code;
        this.message = message;
    }

    /**
     * 获取错误码
     */
    public int getCode() {
        return code;
    }

    /**
     * 获取错误描述
     */
    public String getMessage() {
        return message;
    }

    /**
     * 根据错误码获取枚举
     */
    public static HelpBotErrorCode fromCode(final int code) {
        for (HelpBotErrorCode errorCode : values()) {
            if (errorCode.code == code) {
                return errorCode;
            }
        }
        return UNKNOWN_ERROR;
    }

    @Override
    public String toString() {
        return "HelpBotErrorCode{" +
                "code=" + code +
                ", message='" + message + '\'' +
                '}';
    }
}
