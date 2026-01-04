using System;
using System.Collections.Generic;

namespace HelpBot
{
    /// <summary>
    /// HelpBot SDK 配置类
    /// 
    /// 使用 Builder 模式构建配置，完全对应 Android SDK 的 HelpBotConfig
    /// </summary>
    public class HelpBotConfig
    {
        // 必填字段
        private readonly string channelId;
        private readonly string domain;

        // 可选字段
        private readonly bool fullPrivacyMode;
        private readonly bool enableSseNotification;
        private readonly int initTimeoutMs;
        private readonly int webViewLoadTimeoutMs;
        private readonly Dictionary<string, object> customConfig;
        private readonly bool useDevApi;
        private readonly string companyId;
        private readonly string userId;
        private readonly string preGeneratedToken;

        private HelpBotConfig(Builder builder)
        {
            this.channelId = builder.channelId;
            this.domain = builder.domain;
            this.fullPrivacyMode = builder.fullPrivacyMode;
            this.enableSseNotification = builder.enableSseNotification;
            this.initTimeoutMs = builder.initTimeoutMs;
            this.webViewLoadTimeoutMs = builder.webViewLoadTimeoutMs;
            this.customConfig = new Dictionary<string, object>(builder.customConfig);
            this.useDevApi = builder.useDevApi;
            this.companyId = builder.companyId;
            this.userId = builder.userId;
            this.preGeneratedToken = builder.preGeneratedToken;
        }

        // Getters
        public string ChannelId { get { return channelId; } }
        public string Domain { get { return domain; } }
        public bool FullPrivacyMode { get { return fullPrivacyMode; } }
        public bool EnableSseNotification { get { return enableSseNotification; } }
        public int InitTimeoutMs { get { return initTimeoutMs; } }
        public int WebViewLoadTimeoutMs { get { return webViewLoadTimeoutMs; } }
        public Dictionary<string, object> CustomConfig { get { return new Dictionary<string, object>(customConfig); } }
        public bool UseDevApi { get { return useDevApi; } }
        public string CompanyId { get { return companyId; } }
        public string UserId { get { return userId; } }
        public string PreGeneratedToken { get { return preGeneratedToken; } }

        /// <summary>
        /// 配置构建器
        /// </summary>
        public class Builder
        {
            internal string channelId;
            internal string domain;
            internal bool fullPrivacyMode = false;
            internal bool enableSseNotification = true;
            internal int initTimeoutMs = 30000;
            internal int webViewLoadTimeoutMs = 15000;
            internal Dictionary<string, object> customConfig = new Dictionary<string, object>();
            internal bool useDevApi = false;
            internal string companyId;
            internal string userId;
            internal string preGeneratedToken;

            /// <summary>
            /// 设置 Channel ID（必填）
            /// </summary>
            public Builder SetChannelId(string channelId)
            {
                this.channelId = channelId;
                return this;
            }

            /// <summary>
            /// 设置域名（必填，必须 https）
            /// </summary>
            public Builder SetDomain(string domain)
            {
                this.domain = domain;
                return this;
            }

            /// <summary>
            /// 设置完全隐私模式（默认 false）
            /// </summary>
            public Builder SetFullPrivacyMode(bool fullPrivacyMode)
            {
                this.fullPrivacyMode = fullPrivacyMode;
                return this;
            }

            /// <summary>
            /// 设置是否启用 SSE 通知（默认 true）
            /// </summary>
            public Builder SetEnableSseNotification(bool enable)
            {
                this.enableSseNotification = enable;
                return this;
            }

            /// <summary>
            /// 设置初始化超时时间（默认 30000ms）
            /// </summary>
            public Builder SetInitTimeout(int timeoutMs)
            {
                this.initTimeoutMs = timeoutMs;
                return this;
            }

            /// <summary>
            /// 设置 WebView 加载超时时间（默认 15000ms）
            /// </summary>
            public Builder SetWebViewLoadTimeout(int timeoutMs)
            {
                this.webViewLoadTimeoutMs = timeoutMs;
                return this;
            }

            /// <summary>
            /// 添加自定义配置
            /// </summary>
            public Builder AddCustomConfig(string key, object value)
            {
                if (!string.IsNullOrEmpty(key) && value != null)
                {
                    this.customConfig[key] = value;
                }
                return this;
            }

            /// <summary>
            /// 设置是否使用 Dev API 获取 token（仅测试环境）
            /// 
            /// 注意：生产环境请保持 false，并通过后端生成 preGeneratedToken
            /// </summary>
            public Builder SetUseDevApi(bool useDevApi)
            {
                this.useDevApi = useDevApi;
                return this;
            }

            /// <summary>
            /// 设置 companyId（仅 useDevApi=true 时需要）
            /// </summary>
            public Builder SetCompanyId(string companyId)
            {
                this.companyId = companyId;
                return this;
            }

            /// <summary>
            /// 设置 userId（仅 useDevApi=true 时需要）
            /// </summary>
            public Builder SetUserId(string userId)
            {
                this.userId = userId;
                return this;
            }

            /// <summary>
            /// 预置生产环境 token（preGeneratedToken）
            /// 
            /// 推荐做法：由宿主后端生成 token，在调用 HelpBot.Login(...) 时传入；
            /// 该配置主要用于"安装阶段就已拿到 token"的场景
            /// </summary>
            public Builder SetPreGeneratedToken(string preGeneratedToken)
            {
                this.preGeneratedToken = preGeneratedToken;
                return this;
            }

            /// <summary>
            /// 构建配置对象
            /// </summary>
            public HelpBotConfig Build()
            {
                // 验证必填字段
                if (string.IsNullOrEmpty(channelId))
                {
                    throw new ArgumentException("ChannelId 不能为空");
                }

                if (string.IsNullOrEmpty(domain))
                {
                    throw new ArgumentException("Domain 不能为空");
                }

                // 验证 domain 格式（必须 https）
                if (!domain.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
                {
                    throw new ArgumentException("Domain 必须以 https:// 开头");
                }

                // 验证 useDevApi 相关配置
                if (useDevApi)
                {
                    if (string.IsNullOrEmpty(companyId))
                    {
                        throw new ArgumentException("useDevApi=true 时，companyId 不能为空");
                    }
                    if (string.IsNullOrEmpty(userId))
                    {
                        throw new ArgumentException("useDevApi=true 时，userId 不能为空");
                    }
                }

                return new HelpBotConfig(this);
            }
        }

        public override string ToString()
        {
            return $"HelpBotConfig{{channelId='{channelId}', domain='{domain}', fullPrivacyMode={fullPrivacyMode}, " +
                   $"enableSseNotification={enableSseNotification}, useDevApi={useDevApi}}}";
        }
    }
}
