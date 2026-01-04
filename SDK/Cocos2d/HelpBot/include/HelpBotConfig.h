#ifndef HELPBOT_CONFIG_H
#define HELPBOT_CONFIG_H

#include <string>
#include <map>
#include <stdexcept>

namespace helpbot {

/**
 * HelpBot SDK 配置类
 * 
 * 使用 Builder 模式构建配置,与 Android SDK 完全对齐
 */
class HelpBotConfig {
public:
    /**
     * 配置构建器
     */
    class Builder {
    public:
        Builder() 
            : m_fullPrivacyMode(false)
            , m_enableSseNotification(true)
            , m_initTimeoutMs(30000)
            , m_webViewLoadTimeoutMs(15000)
            , m_useDevApi(false) {
        }

        /**
         * 设置 Channel ID(必填)
         */
        Builder& channelId(const std::string& channelId) {
            m_channelId = channelId;
            return *this;
        }

        /**
         * 设置域名(必填,必须 https)
         */
        Builder& domain(const std::string& domain) {
            m_domain = normalizeHttpsDomain(domain);
            return *this;
        }

        /**
         * 设置完全隐私模式(默认 false)
         */
        Builder& fullPrivacyMode(bool enabled) {
            m_fullPrivacyMode = enabled;
            return *this;
        }

        /**
         * 设置是否启用 SSE 通知(默认 true)
         */
        Builder& enableSseNotification(bool enabled) {
            m_enableSseNotification = enabled;
            return *this;
        }

        /**
         * 设置初始化超时时间(默认 30000ms)
         */
        Builder& initTimeout(int timeoutMs) {
            m_initTimeoutMs = timeoutMs;
            return *this;
        }

        /**
         * 设置 WebView 加载超时时间(默认 15000ms)
         */
        Builder& webViewLoadTimeout(int timeoutMs) {
            m_webViewLoadTimeoutMs = timeoutMs;
            return *this;
        }

        /**
         * 添加自定义配置
         */
        Builder& addCustomConfig(const std::string& key, const std::string& value) {
            m_customConfig[key] = value;
            return *this;
        }

        /**
         * 设置是否使用 Dev API 获取 token(仅测试环境)
         */
        Builder& useDevApi(bool enabled) {
            m_useDevApi = enabled;
            return *this;
        }

        /**
         * 设置 companyId(仅 useDevApi=true 时需要)
         */
        Builder& companyId(const std::string& companyId) {
            m_companyId = companyId;
            return *this;
        }

        /**
         * 设置 userId(仅 useDevApi=true 时需要)
         */
        Builder& userId(const std::string& userId) {
            m_userId = userId;
            return *this;
        }

        /**
         * 预置生产环境 token
         */
        Builder& preGeneratedToken(const std::string& token) {
            m_preGeneratedToken = token;
            return *this;
        }

        /**
         * 构建配置对象
         */
        HelpBotConfig build() {
            // 参数验证
            if (m_channelId.empty()) {
                throw std::invalid_argument("channelId 不能为空");
            }
            if (m_domain.empty()) {
                throw std::invalid_argument("domain 不能为空");
            }

            // useDevApi 模式需要 companyId/userId
            if (m_useDevApi) {
                if (m_companyId.empty()) {
                    throw std::invalid_argument("useDevApi=true 时 companyId 不能为空");
                }
                if (m_userId.empty()) {
                    throw std::invalid_argument("useDevApi=true 时 userId 不能为空");
                }
            }

            return HelpBotConfig(*this);
        }

    private:
        std::string m_channelId;
        std::string m_domain;
        bool m_fullPrivacyMode;
        bool m_enableSseNotification;
        int m_initTimeoutMs;
        int m_webViewLoadTimeoutMs;
        std::map<std::string, std::string> m_customConfig;
        bool m_useDevApi;
        std::string m_companyId;
        std::string m_userId;
        std::string m_preGeneratedToken;

        /**
         * 将 domain 规范化为 HTTPS URL
         */
        static std::string normalizeHttpsDomain(const std::string& raw) {
            std::string trimmed = trim(raw);
            if (trimmed.empty()) {
                throw std::invalid_argument("domain 不能为空");
            }

            // 如果没有协议,自动添加 https://
            std::string candidate = trimmed;
            if (candidate.find("://") == std::string::npos) {
                candidate = "https://" + candidate;
            }

            // 检查是否为 https
            if (candidate.find("https://") != 0) {
                throw std::invalid_argument("domain 仅支持 https: " + raw);
            }

            /**
             * 与 Android SDK 对齐：严格保留 scheme/host/port，去除 path/query/fragment，降低误用风险。
             *
             * 例如：
             * - https://example.com/path?a=1#x  -> https://example.com
             * - https://example.com:8443/abc   -> https://example.com:8443
             */
            const size_t schemeEnd = std::string("https://").size();
            const size_t cutPos = candidate.find_first_of("/?#", schemeEnd);
            if (cutPos != std::string::npos) {
                candidate = candidate.substr(0, cutPos);
            }

            // 去除尾部斜杠（理论上 cut 后不会有，但保持兜底一致）
            while (!candidate.empty() && candidate.back() == '/') {
                candidate.pop_back();
            }

            return candidate;
        }

        static std::string trim(const std::string& str) {
            size_t first = str.find_first_not_of(" \t\n\r");
            if (first == std::string::npos) {
                return "";
            }
            size_t last = str.find_last_not_of(" \t\n\r");
            return str.substr(first, last - first + 1);
        }

        friend class HelpBotConfig;
    };

    // Getters
    std::string getChannelId() const { return m_channelId; }
    std::string getDomain() const { return m_domain; }
    bool isFullPrivacyMode() const { return m_fullPrivacyMode; }
    bool isEnableSseNotification() const { return m_enableSseNotification; }
    int getInitTimeoutMs() const { return m_initTimeoutMs; }
    int getWebViewLoadTimeoutMs() const { return m_webViewLoadTimeoutMs; }
    std::map<std::string, std::string> getCustomConfig() const { return m_customConfig; }
    bool isUseDevApi() const { return m_useDevApi; }
    std::string getCompanyId() const { return m_companyId; }
    std::string getUserId() const { return m_userId; }
    std::string getPreGeneratedToken() const { return m_preGeneratedToken; }

private:
    HelpBotConfig(const Builder& builder)
        : m_channelId(builder.m_channelId)
        , m_domain(builder.m_domain)
        , m_fullPrivacyMode(builder.m_fullPrivacyMode)
        , m_enableSseNotification(builder.m_enableSseNotification)
        , m_initTimeoutMs(builder.m_initTimeoutMs)
        , m_webViewLoadTimeoutMs(builder.m_webViewLoadTimeoutMs)
        , m_customConfig(builder.m_customConfig)
        , m_useDevApi(builder.m_useDevApi)
        , m_companyId(builder.m_companyId)
        , m_userId(builder.m_userId)
        , m_preGeneratedToken(builder.m_preGeneratedToken) {
    }

    std::string m_channelId;
    std::string m_domain;
    bool m_fullPrivacyMode;
    bool m_enableSseNotification;
    int m_initTimeoutMs;
    int m_webViewLoadTimeoutMs;
    std::map<std::string, std::string> m_customConfig;
    bool m_useDevApi;
    std::string m_companyId;
    std::string m_userId;
    std::string m_preGeneratedToken;
};

} // namespace helpbot

#endif // HELPBOT_CONFIG_H
