package com.example.HelpBot.core;

public class HelpBotEvent {
    public static final String WIDGET_TOGGLE = "widgetToggle";
    public static final String DATA_SDK_VISIBLE = "visible";
    public static final String ACTION_CLICKED = "userClickOnAction";
    public static final String DATA_ACTION_TYPE = "actionType";
    public static final String DATA_ACTION_TYPE_CALL = "call";
    public static final String DATA_ACTION_TYPE_LINK = "link";
    public static final String DATA_ACTION = "actionData";
    public static final String CONVERSATION_START = "conversationStart";
    public static final String DATA_MESSAGE = "message";
    public static final String AGENT_MESSAGE_RECEIVED = "agentMessageReceived";
    public static final String DATA_PUBLISH_ID = "publishId";
    public static final String DATA_CREATED_TIME = "createdTs";
    public static final String DATA_ATTACHMENTS = "attachments";
    public static final String DATA_URL = "url";
    public static final String DATA_CONTENT_TYPE = "contentType";
    public static final String DATA_FILE_NAME = "fileName";
    public static final String DATA_SIZE = "size";
    public static final String DATA_MESSAGE_TYPE_APP_REVIEW_REQUEST = "app_review_request";
    public static final String DATA_MESSAGE_TYPE_SCREENSHOT_REQUEST = "screenshot_request";
    public static final String MESSAGE_ADD = "messageAdd";
    public static final String DATA_MESSAGE_TYPE = "type";
    public static final String DATA_MESSAGE_BODY = "body";
    public static final String DATA_MESSAGE_TYPE_ATTACHMENT = "attachment";
    public static final String DATA_MESSAGE_TYPE_TEXT = "text";
    public static final String CSAT_SUBMIT = "csatSubmit";
    public static final String DATA_CSAT_RATING = "rating";
    public static final String DATA_ADDITIONAL_FEEDBACK = "additionalFeedback";
    public static final String CONVERSATION_STATUS = "conversationStatus";
    public static final String DATA_LATEST_ISSUE_ID = "latestIssueId";
    public static final String DATA_LATEST_ISSUE_PUBLISH_ID = "latestIssuePublishId";
    public static final String DATA_IS_ISSUE_OPEN = "open";
    public static final String CONVERSATION_END = "conversationEnd";
    public static final String CONVERSATION_REJECTED = "conversationRejected";
    public static final String CONVERSATION_RESOLVED = "conversationResolved";
    public static final String CONVERSATION_REOPENED = "conversationReopened";
    public static final String SDK_SESSION_STARTED = "helpshiftSessionStarted";
    public static final String SDK_SESSION_ENDED = "helpshiftSessionEnded";
    public static final String RECEIVED_UNREAD_MESSAGE_COUNT = "receivedUnreadMessageCount";
    public static final String DATA_MESSAGE_COUNT = "count";
    public static final String DATA_MESSAGE_COUNT_FROM_CACHE = "fromCache";
    public static final String USER_SESSION_EXPIRED = "userSessionExpired";
    public static final String IDENTITY_FEATURE_NOT_ENABLED = "identityFeatureNotEnabled";
    public static final String REFRESH_USER_CREDENTIALS = "refreshUserCredentials";
    public static final String MASTER_ATTRIBUTES_VALIDATION_FAILED = "masterAttributesValidationFailed";
    public static final String MASTER_ATTRIBUTES_SYNC_FAILED = "masterAttributesSyncFailed";
    public static final String MASTER_ATTRIBUTES_LIMIT_EXCEEDED = "masterAttributesLimitExceeded";
    public static final String APP_ATTRIBUTES_VALIDATION_FAILED = "appAttributesValidationFailed";
    public static final String APP_ATTRIBUTES_LIMIT_EXCEEDED = "appAttributesLimitExceeded";
    public static final String APP_ATTRIBUTES_SYNC_FAILED = "appAttributesSyncFailed";
    public static final String IDENTITY_DATA_INVALID = "identityDataInvalid";
    public static final String IDENTITY_DATA_SYNC_FAILED = "identityDataSyncFailed";
    public static final String IDENTITY_DATA_LIMIT_EXCEEDED = "identityDataLimitExceeded";
    public static final String INVALID_IDENTITY_TOKEN = "identityTokenInvalid";
    public static final String IAT_IS_MANDATORY = "iatIsMandatory";

    private HelpBotEvent() {
        super();
    }
}
