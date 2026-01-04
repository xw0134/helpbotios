namespace HelpBot
{
    /// <summary>
    /// 用户认证失败原因
    /// </summary>
    public enum HelpBotAuthenticationFailureReason
    {
        /// <summary>
        /// 未知原因
        /// </summary>
        UNKNOWN,

        /// <summary>
        /// Token 无效
        /// </summary>
        INVALID_AUTH_TOKEN,

        /// <summary>
        /// Token 过期
        /// </summary>
        AUTH_TOKEN_EXPIRED
    }

    /// <summary>
    /// HelpBot SDK 统一回调接口
    /// 
    /// 用于所有异步操作的结果回调
    /// </summary>
    /// <typeparam name="T">成功时返回的数据类型</typeparam>
    public interface IHelpBotCallback<T>
    {
        /// <summary>
        /// 操作成功回调
        /// </summary>
        /// <param name="result">操作结果数据，可能为 null</param>
        void OnSuccess(T result);

        /// <summary>
        /// 操作失败回调
        /// </summary>
        /// <param name="errorCode">错误码</param>
        /// <param name="errorMessage">错误描述信息</param>
        void OnFailure(HelpBotErrorCode errorCode, string errorMessage);
    }

    /// <summary>
    /// HelpBot SDK 初始化回调接口
    /// 
    /// 用于监听 SDK 初始化过程的各个阶段
    /// </summary>
    public interface IHelpBotInitCallback
    {
        /// <summary>
        /// 初始化开始
        /// </summary>
        void OnInitStart();

        /// <summary>
        /// 初始化进度更新
        /// </summary>
        /// <param name="progress">进度百分比 (0-100)</param>
        /// <param name="message">当前步骤描述</param>
        void OnInitProgress(int progress, string message);

        /// <summary>
        /// 初始化成功
        /// </summary>
        void OnInitSuccess();

        /// <summary>
        /// 初始化失败
        /// </summary>
        /// <param name="errorCode">错误码</param>
        /// <param name="errorMessage">错误描述</param>
        void OnInitFailure(HelpBotErrorCode errorCode, string errorMessage);
    }

    /// <summary>
    /// HelpBot SDK 事件监听器接口
    /// 
    /// 用于监听 SDK 运行时的各种事件
    /// </summary>
    public interface IHelpBotEventsListener
    {
        /// <summary>
        /// 事件发生回调
        /// </summary>
        /// <param name="eventName">事件名称，参见 HelpBotEvent 常量</param>
        /// <param name="data">事件数据（JSON 字符串）</param>
        void OnEventOccurred(string eventName, string data);

        /// <summary>
        /// 用户认证失败回调
        /// </summary>
        /// <param name="reason">失败原因</param>
        void OnUserAuthenticationFailure(HelpBotAuthenticationFailureReason reason);
    }
}
