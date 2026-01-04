package com.example.HelpBot.core;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.HashMap;
import java.util.Map;

/**
 * HelpBot SDK 配置类
 * 
 * 使用 Builder 模式构建配置
 */
public class HelpBotConfig {

    private final String channelId;
    private final String domain;
    private final boolean fullPrivacyMode;
    private final boolean enableSseNotification;
    private final int initTimeoutMs;
    private final int webViewLoadTimeoutMs;
    private final Map<String, Object> customConfig;

    /**
     * WebSDK Token 获取模式：
     * - useDevAPI=true：仅测试环境，WebSDK 会调用 dev API 生成 token（需要 companyId/userId）
     * - useDevAPI=false：生产环境，必须提供 preGeneratedToken（由宿主后端生成）
     */
    private final boolean useDevApi;

    /**
     * 测试环境 token 生成参数（仅 useDevAPI=true 时需要）
     */
    @Nullable
    private final String companyId;
    @Nullable
    private final String userId;

    /**
     * 生产环境预生成 token（建议在登录时传入；也可通过配置预置，注意不要在日志中输出）
     */
    @Nullable
    private final String preGeneratedToken;

    private HelpBotConfig(Builder builder) {
        this.channelId = builder.channelId;
        this.domain = builder.domain;
        this.fullPrivacyMode = builder.fullPrivacyMode;
        this.enableSseNotification = builder.enableSseNotification;
        this.initTimeoutMs = builder.initTimeoutMs;
        this.webViewLoadTimeoutMs = builder.webViewLoadTimeoutMs;
        this.customConfig = builder.customConfig;
        this.useDevApi = builder.useDevApi;
        this.companyId = builder.companyId;
        this.userId = builder.userId;
        this.preGeneratedToken = builder.preGeneratedToken;
    }

    public String getChannelId() {
        return channelId;
    }

    public String getDomain() {
        return domain;
    }

    public boolean isFullPrivacyMode() {
        return fullPrivacyMode;
    }

    public boolean isEnableSseNotification() {
        return enableSseNotification;
    }

    public int getInitTimeoutMs() {
        return initTimeoutMs;
    }

    public int getWebViewLoadTimeoutMs() {
        return webViewLoadTimeoutMs;
    }

    public Map<String, Object> getCustomConfig() {
        return new HashMap<>(customConfig);
    }

    public boolean isUseDevApi() {
        return useDevApi;
    }

    @Nullable
    public String getCompanyId() {
        return companyId;
    }

    @Nullable
    public String getUserId() {
        return userId;
    }

    @Nullable
    public String getPreGeneratedToken() {
        return preGeneratedToken;
    }

    /**
     * 配置构建器
     */
    public static class Builder {
        private String channelId;
        private String domain;
        private boolean fullPrivacyMode = false;
        private boolean enableSseNotification = true;
        private int initTimeoutMs = 30000; // 30秒
        private int webViewLoadTimeoutMs = 15000; // 15秒
        private Map<String, Object> customConfig = new HashMap<>();

        private boolean useDevApi = false;
        @Nullable
        private String companyId;
        @Nullable
        private String userId;
        @Nullable
        private String preGeneratedToken;

        /**
         * 设置 Channel ID（必填）
         */
        public Builder channelId(@NonNull String channelId) {
            this.channelId = channelId;
            return this;
        }

        /**
         * 设置域名（必填）
         */
        public Builder domain(@NonNull String domain) {
            this.domain = normalizeHttpsDomain(domain);
            return this;
        }

        /**
         * 设置完全隐私模式（默认 false）
         */
        public Builder fullPrivacyMode(boolean fullPrivacyMode) {
            this.fullPrivacyMode = fullPrivacyMode;
            return this;
        }

        /**
         * 设置是否启用 SSE 通知（默认 true）
         */
        public Builder enableSseNotification(boolean enable) {
            this.enableSseNotification = enable;
            return this;
        }

        /**
         * 设置初始化超时时间（默认 30000ms）
         */
        public Builder initTimeout(int timeoutMs) {
            this.initTimeoutMs = timeoutMs;
            return this;
        }

        /**
         * 设置 WebView 加载超时时间（默认 15000ms）
         */
        public Builder webViewLoadTimeout(int timeoutMs) {
            this.webViewLoadTimeoutMs = timeoutMs;
            return this;
        }

        /**
         * 添加自定义配置
         */
        public Builder addCustomConfig(@NonNull String key, @NonNull Object value) {
            this.customConfig.put(key, value);
            return this;
        }

        /**
         * 设置是否使用 Dev API 获取 token（仅测试环境）。
         *
         * 注意：生产环境请保持 false，并通过后端生成 preGeneratedToken。
         */
        public Builder useDevApi(final boolean useDevApi) {
            this.useDevApi = useDevApi;
            return this;
        }

        /**
         * 设置 companyId（仅 useDevApi=true 时需要）。
         */
        public Builder companyId(@NonNull final String companyId) {
            this.companyId = companyId;
            return this;
        }

        /**
         * 设置 userId（仅 useDevApi=true 时需要）。
         */
        public Builder userId(@NonNull final String userId) {
            this.userId = userId;
            return this;
        }

        /**
         * 预置生产环境 token（preGeneratedToken）。
         *
         * 推荐做法：由宿主后端生成 token，在调用 HelpBot.login(...) 时传入；
         * 该配置主要用于“安装阶段就已拿到 token”的场景。
         */
        public Builder preGeneratedToken(@NonNull final String preGeneratedToken) {
            this.preGeneratedToken = preGeneratedToken;
            return this;
        }

        /**
         * 构建配置对象
         */
        public HelpBotConfig build() {
            // 参数验证
            if (channelId == null || channelId.trim().isEmpty()) {
                throw new IllegalArgumentException("channelId 不能为空");
            }
            if (domain == null || domain.trim().isEmpty()) {
                throw new IllegalArgumentException("domain 不能为空");
            }

            // useDevApi 模式需要 companyId/userId
            if (useDevApi) {
                if (companyId == null || companyId.trim().isEmpty()) {
                    throw new IllegalArgumentException("useDevApi=true 时 companyId 不能为空");
                }
                if (userId == null || userId.trim().isEmpty()) {
                    throw new IllegalArgumentException("useDevApi=true 时 userId 不能为空");
                }
            }

            return new HelpBotConfig(this);
        }

        /**
         * 将 domain 规范化为 HTTPS URL（SDK 安全基线）：
         * - 支持传入 host（例如 example.com 或 example.com:8443），会自动补全为 https://
         * - 若传入非 https（例如 http://）直接抛异常，避免降级到明文传输
         * - 严格保留 scheme/host/port；默认去除 path/query/fragment，减少配置误用导致的跳转与白名单风险
         */
        @NonNull
        private static String normalizeHttpsDomain(@NonNull final String raw) {
            final String trimmed = (raw == null) ? "" : raw.trim();
            if (trimmed.isEmpty()) {
                throw new IllegalArgumentException("domain 不能为空");
            }

            String candidate = trimmed;
            if (!candidate.contains("://")) {
                candidate = "https://" + candidate;
            }

            final URI uri;
            try {
                uri = new URI(candidate);
            } catch (final URISyntaxException e) {
                throw new IllegalArgumentException("domain 格式非法: " + raw);
            }

            final String scheme = uri.getScheme();
            final String host = uri.getHost();
            final int port = uri.getPort();

            if (scheme == null || !"https".equalsIgnoreCase(scheme)) {
                throw new IllegalArgumentException("domain 仅支持 https: " + raw);
            }
            if (host == null || host.trim().isEmpty()) {
                throw new IllegalArgumentException("domain 缺少 host: " + raw);
            }

            // 严格去除 path/query/fragment（避免 baseURL 被拼成带路径的“半成品 URL”，引入白名单/跳转歧义）
            try {
                final URI normalized = new URI(
                        "https",
                        null,
                        host,
                        port,
                        null,
                        null,
                        null);
                return normalized.toString();
            } catch (final URISyntaxException e) {
                throw new IllegalArgumentException("domain 解析失败: " + raw);
            }
        }
    }

    @Override
    public String toString() {
        return "HelpBotConfig{" +
                "channelId='" + channelId + '\'' +
                ", domain='" + domain + '\'' +
                ", fullPrivacyMode=" + fullPrivacyMode +
                ", enableSseNotification=" + enableSseNotification +
                ", initTimeoutMs=" + initTimeoutMs +
                ", webViewLoadTimeoutMs=" + webViewLoadTimeoutMs +
                '}';
    }
}
