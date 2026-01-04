import Foundation

/**
 HelpBot SDK 配置类（iOS），使用 Builder 构建，尽量与 Android 字段对齐。
 */
public final class HelpBotConfig {
    public let channelId: String
    public let domain: String
    public let fullPrivacyMode: Bool
    public let enableSseNotification: Bool
    public let initTimeoutMs: Int
    public let webViewLoadTimeoutMs: Int
    public let customConfig: [String: Any]

    /// WebSDK Token 获取模式：useDevApi=true（仅测试）；false（生产）需 preGeneratedToken 或 login 注入
    public let useDevApi: Bool
    public let companyId: String?
    public let userId: String?
    public let preGeneratedToken: String?

    private init(builder: Builder) {
        self.channelId = builder.channelId
        self.domain = builder.domain
        self.fullPrivacyMode = builder.fullPrivacyMode
        self.enableSseNotification = builder.enableSseNotification
        self.initTimeoutMs = builder.initTimeoutMs
        self.webViewLoadTimeoutMs = builder.webViewLoadTimeoutMs
        self.customConfig = builder.customConfig
        self.useDevApi = builder.useDevApi
        self.companyId = builder.companyId
        self.userId = builder.userId
        self.preGeneratedToken = builder.preGeneratedToken
    }

    public final class Builder {
        fileprivate var channelId: String = ""
        fileprivate var domain: String = ""
        fileprivate var fullPrivacyMode: Bool = false
        fileprivate var enableSseNotification: Bool = true
        fileprivate var initTimeoutMs: Int = 30_000
        fileprivate var webViewLoadTimeoutMs: Int = 15_000
        fileprivate var customConfig: [String: Any] = [:]

        fileprivate var useDevApi: Bool = false
        fileprivate var companyId: String?
        fileprivate var userId: String?
        fileprivate var preGeneratedToken: String?

        public init() {}

        /// 设置 Channel ID（必填）
        @discardableResult
        public func channelId(_ channelId: String) -> Builder {
            self.channelId = channelId
            return self
        }

        /// 设置域名（必填，必须 https）
        @discardableResult
        public func domain(_ domain: String) -> Builder {
            self.domain = Self.normalizeHttpsDomain(domain)
            return self
        }

        /// 设置完全隐私模式（默认 false）
        @discardableResult
        public func fullPrivacyMode(_ enabled: Bool) -> Builder {
            self.fullPrivacyMode = enabled
            return self
        }

        /// 设置是否启用 SSE 通知（默认 true）
        @discardableResult
        public func enableSseNotification(_ enabled: Bool) -> Builder {
            self.enableSseNotification = enabled
            return self
        }

        /// 设置初始化超时时间（默认 30000ms）
        @discardableResult
        public func initTimeoutMs(_ timeoutMs: Int) -> Builder {
            self.initTimeoutMs = max(timeoutMs, 0)
            return self
        }

        /// 设置 WebView 加载超时时间（默认 15000ms）
        @discardableResult
        public func webViewLoadTimeoutMs(_ timeoutMs: Int) -> Builder {
            self.webViewLoadTimeoutMs = max(timeoutMs, 0)
            return self
        }

        /// 添加自定义配置（透传给 UI 行为）
        @discardableResult
        public func addCustomConfig(_ key: String, _ value: Any) -> Builder {
            guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return self }
            self.customConfig[key] = value
            return self
        }

        /// 设置是否使用 Dev API 获取 token（仅测试环境）
        @discardableResult
        public func useDevApi(_ enabled: Bool) -> Builder {
            self.useDevApi = enabled
            return self
        }

        /// 设置 companyId（仅 useDevApi=true 时需要）
        @discardableResult
        public func companyId(_ companyId: String) -> Builder {
            self.companyId = companyId
            return self
        }

        /// 设置 userId（仅 useDevApi=true 时需要）
        @discardableResult
        public func userId(_ userId: String) -> Builder {
            self.userId = userId
            return self
        }

        /// 预置生产环境 token（preGeneratedToken）
        @discardableResult
        public func preGeneratedToken(_ token: String) -> Builder {
            self.preGeneratedToken = token
            return self
        }

        /// 构建配置对象
        public func build() throws -> HelpBotConfig {
            let cid = channelId.trimmingCharacters(in: .whitespacesAndNewlines)
            if cid.isEmpty { throw HelpBotConfigError.invalidChannelId }

            let d = domain.trimmingCharacters(in: .whitespacesAndNewlines)
            if d.isEmpty { throw HelpBotConfigError.invalidDomain }

            if useDevApi {
                let c = (companyId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let u = (userId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if c.isEmpty { throw HelpBotConfigError.missingCompanyId }
                if u.isEmpty { throw HelpBotConfigError.missingUserId }
            }

            return HelpBotConfig(builder: self)
        }

        /**
         将 domain 规范化为 HTTPS URL（SDK 安全基线）：
         - 支持传入 host（例如 example.com 或 example.com:8443），会自动补全为 https://
         - 若传入非 https（例如 http://）直接抛异常，避免降级到明文传输
         - 严格保留 scheme/host/port；默认去除 path/query/fragment，减少配置误用导致的跳转与白名单风险
         */
        fileprivate static func normalizeHttpsDomain(_ raw: String) -> String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "" }

            var candidate = trimmed
            if !candidate.contains("://") {
                candidate = "https://\(candidate)"
            }
            guard let url = URL(string: candidate) else { return "" }
            guard (url.scheme ?? "").lowercased() == "https" else { return "" }
            guard let host = url.host, !host.isEmpty else { return "" }

            var comps = URLComponents()
            comps.scheme = "https"
            comps.host = host
            comps.port = url.port
            return comps.string ?? ""
        }
    }
}

public enum HelpBotConfigError: Error {
    case invalidChannelId
    case invalidDomain
    case missingCompanyId
    case missingUserId
}


