import Foundation

/// HelpBot SDK 配置类
///
/// 设计要点:
/// 1. 使用 Builder 模式构建配置,与 Android SDK 保持一致
/// 2. 严格的参数验证,确保配置安全性
/// 3. 仅支持 HTTPS 域名,符合安全基线
public class HelpBotConfig {
    
    // MARK: - 属性
    
    /// 渠道 ID (必填)
    public let channelId: String
    
    /// 业务域名 (必填,仅支持 HTTPS)
    public let domain: String
    
    /// 完全隐私模式 (默认 false)
    public let fullPrivacyMode: Bool
    
    /// 启用 SSE 通知 (默认 true)
    public let enableSseNotification: Bool
    
    /// 初始化超时时间 (毫秒,默认 30000)
    public let initTimeoutMs: Int
    
    /// WebView 加载超时时间 (毫秒,默认 15000)
    public let webViewLoadTimeoutMs: Int
    
    /// 自定义配置
    public let customConfig: [String: Any]
    
    /// 使用 Dev API 获取 token (仅测试环境,默认 false)
    public let useDevApi: Bool
    
    /// 测试环境 companyId (仅 useDevApi=true 时需要)
    public let companyId: String?
    
    /// 测试环境 userId (仅 useDevApi=true 时需要)
    public let userId: String?
    
    /// 生产环境预生成 token
    public let preGeneratedToken: String?
    
    // MARK: - 初始化
    
    private init(builder: Builder) {
        self.channelId = builder.channelId!
        self.domain = builder.domain!
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
    
    // MARK: - Builder
    
    /// 配置构建器
    public class Builder {
        fileprivate var channelId: String?
        fileprivate var domain: String?
        fileprivate var fullPrivacyMode: Bool = false
        fileprivate var enableSseNotification: Bool = true
        fileprivate var initTimeoutMs: Int = 30000  // 30秒
        fileprivate var webViewLoadTimeoutMs: Int = 15000  // 15秒
        fileprivate var customConfig: [String: Any] = [:]
        fileprivate var useDevApi: Bool = false
        fileprivate var companyId: String?
        fileprivate var userId: String?
        fileprivate var preGeneratedToken: String?
        
        public init() {}
        
        /// 设置 Channel ID (必填)
        @discardableResult
        public func channelId(_ channelId: String) -> Builder {
            self.channelId = channelId
            return self
        }
        
        /// 设置域名 (必填,仅支持 HTTPS)
        @discardableResult
        public func domain(_ domain: String) -> Builder {
            // 注意：此处不做 fatalError/抛异常，避免宿主在链式调用阶段直接崩溃
            // 统一在 build() 时进行严格校验并通过 throw 将错误交给调用方处理
            self.domain = domain
            return self
        }
        
        /// 设置完全隐私模式 (默认 false)
        @discardableResult
        public func fullPrivacyMode(_ enabled: Bool) -> Builder {
            self.fullPrivacyMode = enabled
            return self
        }
        
        /// 设置是否启用 SSE 通知 (默认 true)
        @discardableResult
        public func enableSseNotification(_ enabled: Bool) -> Builder {
            self.enableSseNotification = enabled
            return self
        }
        
        /// 设置初始化超时时间 (默认 30000ms)
        @discardableResult
        public func initTimeout(_ timeoutMs: Int) -> Builder {
            self.initTimeoutMs = timeoutMs
            return self
        }
        
        /// 设置 WebView 加载超时时间 (默认 15000ms)
        @discardableResult
        public func webViewLoadTimeout(_ timeoutMs: Int) -> Builder {
            self.webViewLoadTimeoutMs = timeoutMs
            return self
        }
        
        /// 添加自定义配置
        @discardableResult
        public func addCustomConfig(key: String, value: Any) -> Builder {
            self.customConfig[key] = value
            return self
        }
        
        /// 设置是否使用 Dev API 获取 token (仅测试环境)
        @discardableResult
        public func useDevApi(_ enabled: Bool) -> Builder {
            self.useDevApi = enabled
            return self
        }
        
        /// 设置 companyId (仅 useDevApi=true 时需要)
        @discardableResult
        public func companyId(_ companyId: String) -> Builder {
            self.companyId = companyId
            return self
        }
        
        /// 设置 userId (仅 useDevApi=true 时需要)
        @discardableResult
        public func userId(_ userId: String) -> Builder {
            self.userId = userId
            return self
        }
        
        /// 预置生产环境 token
        @discardableResult
        public func preGeneratedToken(_ token: String) -> Builder {
            self.preGeneratedToken = token
            return self
        }
        
        /// 构建配置对象
        public func build() throws -> HelpBotConfig {
            // 参数验证
            guard let channelId = channelId, !channelId.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw NSError(domain: "HelpBotConfig", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "channelId 不能为空"])
            }
            
            guard let domain = domain, !domain.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw NSError(domain: "HelpBotConfig", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "domain 不能为空"])
            }
            
            // 规范化并强制 HTTPS（SDK 安全基线：禁止明文）
            let normalizedDomain = try Self.normalizeHttpsDomainOrThrow(domain)
            self.domain = normalizedDomain

            // useDevApi 模式需要 companyId/userId
            if useDevApi {
                guard let companyId = companyId, !companyId.trimmingCharacters(in: .whitespaces).isEmpty else {
                    throw NSError(domain: "HelpBotConfig", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "useDevApi=true 时 companyId 不能为空"])
                }
                
                guard let userId = userId, !userId.trimmingCharacters(in: .whitespaces).isEmpty else {
                    throw NSError(domain: "HelpBotConfig", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "useDevApi=true 时 userId 不能为空"])
                }
            }
            
            return HelpBotConfig(builder: self)
        }
        
        /// 将 domain 规范化为 HTTPS URL（SDK 级别：严禁 fatalError 崩宿主）
        ///
        /// 规则:
        /// - 支持传入 host (例如 example.com),会自动补全为 https://
        /// - 若传入非 https,直接 throw，避免降级到明文传输
        /// - 严格保留 scheme/host/port,去除 path/query/fragment
        private static func normalizeHttpsDomainOrThrow(_ raw: String) throws -> String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw NSError(domain: "HelpBotConfig", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "domain 不能为空"])
            }

            var candidate = trimmed
            if !candidate.contains("://") {
                candidate = "https://\(candidate)"
            }

            guard let url = URL(string: candidate) else {
                throw NSError(domain: "HelpBotConfig", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "domain 格式非法: \(raw)"])
            }

            guard let scheme = url.scheme, scheme.lowercased() == "https" else {
                throw NSError(domain: "HelpBotConfig", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "domain 仅支持 https: \(raw)"])
            }

            guard let host = url.host, !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NSError(domain: "HelpBotConfig", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "domain 缺少 host: \(raw)"])
            }

            // 构建规范化 URL (去除 path/query/fragment)
            var components = URLComponents()
            components.scheme = "https"
            components.host = host
            if let port = url.port {
                components.port = port
            }

            guard let normalized = components.url?.absoluteString else {
                throw NSError(domain: "HelpBotConfig", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "domain 解析失败: \(raw)"])
            }
            return normalized
        }
    }
    
    // MARK: - 描述
    
    public var description: String {
        return """
        HelpBotConfig {
            channelId: '\(channelId)',
            domain: '\(domain)',
            fullPrivacyMode: \(fullPrivacyMode),
            enableSseNotification: \(enableSseNotification),
            initTimeoutMs: \(initTimeoutMs),
            webViewLoadTimeoutMs: \(webViewLoadTimeoutMs)
        }
        """
    }
}
