using UnityEngine;

namespace HelpBot
{
    /// <summary>
    /// HelpBot SDK 日志系统
    /// 
    /// 统一的日志记录接口，对应 Android SDK 的 HBlogger
    /// </summary>
    public static class HBLogger
    {
        private const string TAG_PREFIX = "[HelpBot]";
        private static bool debugEnabled = true;

        /// <summary>
        /// 启用或禁用调试日志
        /// </summary>
        public static bool DebugEnabled
        {
            get { return debugEnabled; }
            set { debugEnabled = value; }
        }

        /// <summary>
        /// 调试日志
        /// </summary>
        public static void D(string tag, string message)
        {
            if (debugEnabled)
            {
                Debug.Log($"{TAG_PREFIX}[{tag}] {message}");
            }
        }

        /// <summary>
        /// 信息日志
        /// </summary>
        public static void I(string tag, string message)
        {
            Debug.Log($"{TAG_PREFIX}[{tag}] {message}");
        }

        /// <summary>
        /// 警告日志
        /// </summary>
        public static void W(string tag, string message)
        {
            Debug.LogWarning($"{TAG_PREFIX}[{tag}] {message}");
        }

        /// <summary>
        /// 错误日志
        /// </summary>
        public static void E(string tag, string message)
        {
            Debug.LogError($"{TAG_PREFIX}[{tag}] {message}");
        }

        /// <summary>
        /// 错误日志（带异常）
        /// </summary>
        public static void E(string tag, string message, System.Exception exception)
        {
            Debug.LogError($"{TAG_PREFIX}[{tag}] {message}\n{exception}");
        }
    }
}
