namespace HelpBot
{
    /// <summary>
    /// HelpBot SDK 事件常量定义
    /// 
    /// 完全对应 Android SDK 的 HelpBotEvent 类
    /// </summary>
    public static class HelpBotEvent
    {
        // Widget 相关事件
        public const string WIDGET_TOGGLE = "widgetToggle";
        public const string DATA_SDK_VISIBLE = "visible";

        // 用户操作事件
        public const string ACTION_CLICKED = "userClickOnAction";
        public const string DATA_ACTION_TYPE = "actionType";
        public const string DATA_ACTION_TYPE_CALL = "call";
        public const string DATA_ACTION_TYPE_LINK = "link";
        public const string DATA_ACTION = "actionData";

        // 对话相关事件
        public const string CONVERSATION_START = "conversationStart";
        public const string DATA_MESSAGE = "message";
        public const string AGENT_MESSAGE_RECEIVED = "agentMessageReceived";
        public const string DATA_PUBLISH_ID = "publishId";
        public const string DATA_CREATED_TIME = "createdTs";
        public const string DATA_ATTACHMENTS = "attachments";
        public const string DATA_URL = "url";
        public const string DATA_CONTENT_TYPE = "contentType";
        public const string DATA_FILE_NAME = "fileName";
        public const string DATA_SIZE = "size";
        public const string DATA_MESSAGE_TYPE_APP_REVIEW_REQUEST = "app_review_request";
        public const string DATA_MESSAGE_TYPE_SCREENSHOT_REQUEST = "screenshot_request";

        // 消息相关事件
        public const string MESSAGE_ADD = "messageAdd";
        public const string DATA_MESSAGE_TYPE = "type";
        public const string DATA_MESSAGE_BODY = "body";
        public const string DATA_MESSAGE_TYPE_ATTACHMENT = "attachment";
        public const string DATA_MESSAGE_TYPE_TEXT = "text";

        // CSAT 相关事件
        public const string CSAT_SUBMIT = "csatSubmit";
        public const string DATA_CSAT_RATING = "rating";
        public const string DATA_ADDITIONAL_FEEDBACK = "additionalFeedback";

        // 对话状态事件
        public const string CONVERSATION_STATUS = "conversationStatus";
        public const string DATA_LATEST_ISSUE_ID = "latestIssueId";
        public const string DATA_LATEST_ISSUE_PUBLISH_ID = "latestIssuePublishId";
        public const string DATA_IS_ISSUE_OPEN = "open";
        public const string CONVERSATION_END = "conversationEnd";
        public const string CONVERSATION_REJECTED = "conversationRejected";
        public const string CONVERSATION_RESOLVED = "conversationResolved";
        public const string CONVERSATION_REOPENED = "conversationReopened";

        // SDK 会话事件
        public const string SDK_SESSION_STARTED = "helpshiftSessionStarted";
        public const string SDK_SESSION_ENDED = "helpshiftSessionEnded";

        // 未读消息计数事件
        public const string RECEIVED_UNREAD_MESSAGE_COUNT = "receivedUnreadMessageCount";
        public const string DATA_MESSAGE_COUNT = "count";
        public const string DATA_MESSAGE_COUNT_FROM_CACHE = "fromCache";

        // 认证相关事件
        public const string USER_SESSION_EXPIRED = "userSessionExpired";
        public const string IDENTITY_FEATURE_NOT_ENABLED = "identityFeatureNotEnabled";
        public const string REFRESH_USER_CREDENTIALS = "refreshUserCredentials";

        // 属性验证事件
        public const string MASTER_ATTRIBUTES_VALIDATION_FAILED = "masterAttributesValidationFailed";
        public const string MASTER_ATTRIBUTES_SYNC_FAILED = "masterAttributesSyncFailed";
        public const string MASTER_ATTRIBUTES_LIMIT_EXCEEDED = "masterAttributesLimitExceeded";
        public const string APP_ATTRIBUTES_VALIDATION_FAILED = "appAttributesValidationFailed";
        public const string APP_ATTRIBUTES_LIMIT_EXCEEDED = "appAttributesLimitExceeded";
        public const string APP_ATTRIBUTES_SYNC_FAILED = "appAttributesSyncFailed";

        // 身份数据事件
        public const string IDENTITY_DATA_INVALID = "identityDataInvalid";
        public const string IDENTITY_DATA_SYNC_FAILED = "identityDataSyncFailed";
        public const string IDENTITY_DATA_LIMIT_EXCEEDED = "identityDataLimitExceeded";
        public const string INVALID_IDENTITY_TOKEN = "identityTokenInvalid";
        public const string IAT_IS_MANDATORY = "iatIsMandatory";
    }
}
