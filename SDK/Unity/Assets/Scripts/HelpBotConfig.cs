using System;

namespace HelpBot
{
    /// <summary>
    /// HelpBot SDK 配置类
    /// </summary>
    [Serializable]
    public class HelpBotConfig
    {
        /// <summary>
        /// 渠道 ID（必填）
        /// </summary>
        public string ChannelId = "";
        
        /// <summary>
        /// 域名（必填，必须以 https:// 开头）
        /// </summary>
        public string Domain = "";
        
        /// <summary>
        /// 完全隐私模式
        /// </summary>
        public bool FullPrivacyMode = false;
        
        /// <summary>
        /// 启用 SSE 通知
        /// </summary>
        public bool EnableSseNotification = true;
        
        /// <summary>
        /// 初始化超时（毫秒）
        /// </summary>
        public int InitTimeout = 30000;
        
        /// <summary>
        /// WebView 加载超时（毫秒）
        /// </summary>
        public int WebViewLoadTimeout = 15000;
        
        public HelpBotConfig()
        {
        }
        
        public HelpBotConfig(string channelId, string domain)
        {
            ChannelId = channelId;
            Domain = domain;
        }
        
        /// <summary>
        /// 验证配置是否有效
        /// </summary>
        public bool IsValid(out string errorMessage)
        {
            if (string.IsNullOrEmpty(ChannelId))
            {
                errorMessage = "ChannelId 不能为空";
                return false;
            }
            
            if (string.IsNullOrEmpty(Domain))
            {
                errorMessage = "Domain 不能为空";
                return false;
            }

            // 对齐 Android Demo：允许直接传 host（例如 dev-bot-server.yuedongcs.com），由 Native SDK 统一补全为 https://
            // 安全基线：禁止 http 明文
            string d = Domain.Trim();
            if (d.StartsWith("http://", StringComparison.OrdinalIgnoreCase))
            {
                errorMessage = "Domain 不允许使用 http://（必须 https）";
                return false;
            }
            if (d.Contains("://") && !d.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
            {
                errorMessage = "Domain 仅支持 https://";
                return false;
            }
            
            errorMessage = "";
            return true;
        }
    }
}
