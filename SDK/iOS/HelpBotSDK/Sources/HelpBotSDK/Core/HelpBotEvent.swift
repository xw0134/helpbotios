import Foundation

/**
 HelpBot SDK 事件常量定义（iOS）。
 
 与 Android HelpBotEvent.java 完全对齐，定义所有 WebSDK 事件名称和数据字段常量。
 */
public final class HelpBotEvent {
    
    // MARK: - Widget Events
    
    /// Widget 显示/隐藏切换事件
    public static let WIDGET_TOGGLE = "widgetToggle"
    public static let DATA_SDK_VISIBLE = "visible"
    
    // MARK: - Action Events
    
    /// 用户点击操作事件
    public static let ACTION_CLICKED = "userClickOnAction"
    public static let DATA_ACTION_TYPE = "actionType"
    public static let DATA_ACTION_TYPE_CALL = "call"
    public static let DATA_ACTION_TYPE_LINK = "link"
    public static let DATA_ACTION = "actionData"
    
    // MARK: - Conversation Events
    
    /// 对话开始事件
    public static let CONVERSATION_START = "conversationStart"
    public static let DATA_MESSAGE = "message"
    
    /// 收到客服消息事件
    public static let AGENT_MESSAGE_RECEIVED = "agentMessageReceived"
    public static let DATA_PUBLISH_ID = "publishId"
    public static let DATA_CREATED_TIME = "createdTs"
    public static let DATA_ATTACHMENTS = "attachments"
    public static let DATA_URL = "url"
    public static let DATA_CONTENT_TYPE = "contentType"
    public static let DATA_FILE_NAME = "fileName"
    public static let DATA_SIZE = "size"
    public static let DATA_MESSAGE_TYPE_APP_REVIEW_REQUEST = "app_review_request"
    public static let DATA_MESSAGE_TYPE_SCREENSHOT_REQUEST = "screenshot_request"
    
    /// 消息添加事件
    public static let MESSAGE_ADD = "messageAdd"
    public static let DATA_MESSAGE_TYPE = "type"
    public static let DATA_MESSAGE_BODY = "body"
    public static let DATA_MESSAGE_TYPE_ATTACHMENT = "attachment"
    public static let DATA_MESSAGE_TYPE_TEXT = "text"
    
    /// CSAT 提交事件
    public static let CSAT_SUBMIT = "csatSubmit"
    public static let DATA_CSAT_RATING = "rating"
    public static let DATA_ADDITIONAL_FEEDBACK = "additionalFeedback"
    
    /// 对话状态事件
    public static let CONVERSATION_STATUS = "conversationStatus"
    public static let DATA_LATEST_ISSUE_ID = "latestIssueId"
    public static let DATA_LATEST_ISSUE_PUBLISH_ID = "latestIssuePublishId"
    public static let DATA_IS_ISSUE_OPEN = "open"
    
    /// 对话结束事件
    public static let CONVERSATION_END = "conversationEnd"
    
    /// 对话被拒绝事件
    public static let CONVERSATION_REJECTED = "conversationRejected"
    
    /// 对话已解决事件
    public static let CONVERSATION_RESOLVED = "conversationResolved"
    
    /// 对话重新打开事件
    public static let CONVERSATION_REOPENED = "conversationReopened"
    
    // MARK: - SDK Session Events
    
    /// SDK 会话开始事件
    public static let SDK_SESSION_STARTED = "helpshiftSessionStarted"
    
    /// SDK 会话结束事件
    public static let SDK_SESSION_ENDED = "helpshiftSessionEnded"
    
    // MARK: - Unread Message Events
    
    /// 收到未读消息数量事件
    public static let RECEIVED_UNREAD_MESSAGE_COUNT = "receivedUnreadMessageCount"
    public static let DATA_MESSAGE_COUNT = "count"
    public static let DATA_MESSAGE_COUNT_FROM_CACHE = "fromCache"
    
    // MARK: - Authentication Events
    
    /// 用户会话过期事件
    public static let USER_SESSION_EXPIRED = "userSessionExpired"
    
    /// Identity 功能未启用事件
    public static let IDENTITY_FEATURE_NOT_ENABLED = "identityFeatureNotEnabled"
    
    /// 刷新用户凭证事件
    public static let REFRESH_USER_CREDENTIALS = "refreshUserCredentials"
    
    // MARK: - Master Attributes Events
    
    /// Master Attributes 验证失败事件
    public static let MASTER_ATTRIBUTES_VALIDATION_FAILED = "masterAttributesValidationFailed"
    
    /// Master Attributes 同步失败事件
    public static let MASTER_ATTRIBUTES_SYNC_FAILED = "masterAttributesSyncFailed"
    
    /// Master Attributes 超出限制事件
    public static let MASTER_ATTRIBUTES_LIMIT_EXCEEDED = "masterAttributesLimitExceeded"
    
    // MARK: - App Attributes Events
    
    /// App Attributes 验证失败事件
    public static let APP_ATTRIBUTES_VALIDATION_FAILED = "appAttributesValidationFailed"
    
    /// App Attributes 超出限制事件
    public static let APP_ATTRIBUTES_LIMIT_EXCEEDED = "appAttributesLimitExceeded"
    
    /// App Attributes 同步失败事件
    public static let APP_ATTRIBUTES_SYNC_FAILED = "appAttributesSyncFailed"
    
    // MARK: - Identity Data Events
    
    /// Identity Data 无效事件
    public static let IDENTITY_DATA_INVALID = "identityDataInvalid"
    
    /// Identity Data 同步失败事件
    public static let IDENTITY_DATA_SYNC_FAILED = "identityDataSyncFailed"
    
    /// Identity Data 超出限制事件
    public static let IDENTITY_DATA_LIMIT_EXCEEDED = "identityDataLimitExceeded"
    
    // MARK: - Token Events
    
    /// Identity Token 无效事件
    public static let INVALID_IDENTITY_TOKEN = "identityTokenInvalid"
    
    /// IAT 是必需的事件
    public static let IAT_IS_MANDATORY = "iatIsMandatory"
    
    // MARK: - Private Constructor
    
    private init() {
        fatalError("HelpBotEvent 不能被实例化")
    }
}
