import Foundation

/**
 HelpBot SDK 错误码定义（iOS）。

 说明：为便于跨端一致性。
 */
public enum HelpBotErrorCode: Int, Codable {
    // ==================== 初始化相关错误 (1000-1099) ====================
    case sdkNotInitialized = 1000
    case sdkAlreadyInitialized = 1001
    case invalidParameter = 1002
    case contextNull = 1003
    case invalidChannelId = 1004
    case invalidDomain = 1005

    // ==================== WebView 相关错误 (1100-1199) ====================
    case webViewUnavailable = 1100
    case webViewInitFailed = 1101
    case webViewLoadTimeout = 1102
    case webViewLoadFailed = 1103
    case webViewDestroyed = 1104

    // ==================== 网络相关错误 (1200-1299) ====================
    case networkUnavailable = 1200
    case networkRequestFailed = 1201
    case networkTimeout = 1202

    // ==================== 认证相关错误 (1300-1399) ====================
    case invalidToken = 1300
    case tokenExpired = 1301
    case notLoggedIn = 1302
    case loginFailed = 1303
    case missingPreGeneratedToken = 1304
    case invalidPreGeneratedToken = 1305
    case alreadyLoggedIn = 1306

    // ==================== 存储相关错误 (1400-1499) ====================
    case storageFailed = 1400
    case readFailed = 1401
    case encryptionFailed = 1402
    case decryptionFailed = 1403

    // ==================== 权限相关错误 (1500-1599) ====================
    case permissionDenied = 1500
    case permissionRequired = 1501

    // ==================== 其他错误 (9000-9999) ====================
    case unknownError = 9000
    case internalError = 9001
    case operationTimeout = 9002
    case operationCancelled = 9003
    case operationInProgress = 9004
    case notSupported = 9005
    case operationNotAllowed = 9006

    public var message: String {
        switch self {
        case .sdkNotInitialized:
            return "SDK未初始化，请先调用 HelpBot.install()"
        case .sdkAlreadyInitialized:
            return "SDK已初始化，请勿重复调用"
        case .invalidParameter:
            return "参数无效"
        case .contextNull:
            return "Context 不能为 nil"
        case .invalidChannelId:
            return "ChannelId 不能为空"
        case .invalidDomain:
            return "Domain 格式无效"
        case .webViewUnavailable:
            return "WebView组件不可用"
        case .webViewInitFailed:
            return "WebView初始化失败"
        case .webViewLoadTimeout:
            return "WebView加载超时"
        case .webViewLoadFailed:
            return "WebView加载失败"
        case .webViewDestroyed:
            return "WebView已销毁"
        case .networkUnavailable:
            return "网络不可用"
        case .networkRequestFailed:
            return "网络请求失败"
        case .networkTimeout:
            return "网络请求超时"
        case .invalidToken:
            return "Token无效"
        case .tokenExpired:
            return "Token已过期"
        case .notLoggedIn:
            return "用户未登录"
        case .loginFailed:
            return "登录失败"
        case .missingPreGeneratedToken:
            return "缺少预生成Token（preGeneratedToken）"
        case .invalidPreGeneratedToken:
            return "预生成Token无效（preGeneratedToken）"
        case .alreadyLoggedIn:
            return "用户已登录，请勿重复调用 login（如需切换账号请先 logout）"
        case .storageFailed:
            return "数据存储失败"
        case .readFailed:
            return "数据读取失败"
        case .encryptionFailed:
            return "数据加密失败"
        case .decryptionFailed:
            return "数据解密失败"
        case .permissionDenied:
            return "权限被拒绝"
        case .permissionRequired:
            return "缺少必要权限"
        case .unknownError:
            return "未知错误"
        case .internalError:
            return "SDK内部错误"
        case .operationTimeout:
            return "操作超时"
        case .operationCancelled:
            return "操作被取消"
        case .operationInProgress:
            return "操作进行中，请勿重复调用"
        case .notSupported:
            return "功能暂不支持"
        case .operationNotAllowed:
            return "当前状态不允许该操作"
        }
    }
}


