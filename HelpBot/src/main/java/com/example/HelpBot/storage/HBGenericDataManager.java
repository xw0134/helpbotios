package com.example.HelpBot.storage;

import com.example.HelpBot.utils.JsonUtils;
import com.example.HelpBot.utils.Utils;
import com.example.HelpBot.log.HBlogger;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.Map;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/**
 * 通用 SDK 数据管理器。
 * 负责解析和持久化由 WebSDK 下发的各种配置数据（如路由、请求头、通知文案等）。
 */
public class HBGenericDataManager {
    private static final String TAG = "HBGenericDataManager";
    private static final String NETWORK_HEADERS = "network_headers";
    private static final String POLLING_ROUTE = "polling_route";
    private static final String PUSH_TOKEN_SYNC_ROUTE = "push_token_sync_route";
    private static final String NOTIFICATION_CONTENT = "notification_content";
    private static final String USER_DATA_KEY_MAPPING = "user_data_key_mapping";
    private static final String FALLBACK_NOTIFICATION_STRING = "您有新消息";
    private static final String ENABLE_LOGGING = "enableLogging";
    private final HBPersistentStorage persistentStorage;

    public HBGenericDataManager(@NonNull final HBPersistentStorage persistentStorage) {
        super();
        this.persistentStorage = persistentStorage;
    }

    /**
     * 保存从 WebSDK 下发的通用配置数据。
     *
     * @param genericDataJsonString JSON 格式的配置字符串
     */
    public void saveGenericSdkData(@Nullable final String genericDataJsonString) {
        if (Utils.isEmpty(genericDataJsonString) || !JsonUtils.isValidJsonString(genericDataJsonString)) {
            HBlogger.w(TAG, "通用数据为空或无效 JSON，跳过保存");
            return;
        }
        try {
            final JSONObject genericDataJson = new JSONObject(genericDataJsonString);
            this.savePollingRoute(this.extractString(POLLING_ROUTE, genericDataJson));
            this.savePushTokenRoute(this.extractString(PUSH_TOKEN_SYNC_ROUTE, genericDataJson));
            this.saveNetworkHeaders(this.extractJsonObject(NETWORK_HEADERS, genericDataJson));
            this.saveNotificationContent(this.extractJsonObject(NOTIFICATION_CONTENT, genericDataJson));
            this.saveUserDataKeyMapping(this.extractJsonObject(USER_DATA_KEY_MAPPING, genericDataJson));
            this.saveEnableLoggingData(this.extractJsonObject(ENABLE_LOGGING, genericDataJson));
        } catch (final Exception e) {
            HBlogger.e(TAG, "解析通用 SDK 数据异常", e);
        }
    }

    private void saveEnableLoggingData(final JSONObject enableLoggingJSON) throws JSONException {
        if (enableLoggingJSON != null) {
            enableLoggingJSON.put("startTime", System.currentTimeMillis());
            this.persistentStorage.setEnableLoggingViaWebchat(enableLoggingJSON.toString());
        }
    }

    private void saveUserDataKeyMapping(final JSONObject userDataKeyMap) {
        if (userDataKeyMap != null) {
            this.persistentStorage.storeUserDataKeyMapping(userDataKeyMap.toString());
        }
    }

    private void saveNotificationContent(final JSONObject notificationContent) {
        if (notificationContent != null) {
            this.persistentStorage.storeNotificationContent(notificationContent.toString());
        }
    }

    private void saveNetworkHeaders(final JSONObject networkHeaders) {
        if (networkHeaders != null) {
            this.persistentStorage.storeNetworkHeaders(networkHeaders.toString());
        }
    }

    private void savePushTokenRoute(final String pushTokenRoute) {
        if (Utils.isNotEmpty(pushTokenRoute)) {
            this.persistentStorage.storePushTokenRoute(pushTokenRoute);
        }
    }

    private void savePollingRoute(final String pollingRoute) {
        if (Utils.isNotEmpty(pollingRoute)) {
            this.persistentStorage.storePollingRoute(pollingRoute);
        }
    }

    private String extractString(final String key, final JSONObject jsonObject) {
        try {
            if (jsonObject.has(key)) {
                return jsonObject.getString(key);
            }
        } catch (final JSONException e) {
            HBlogger.e(TAG, "读取 JSON 字符串字段异常: " + key, (Throwable) e);
        }
        return "";
    }

    private JSONObject extractJsonObject(final String key, final JSONObject jsonObject) {
        try {
            if (jsonObject.has(key)) {
                return jsonObject.getJSONObject(key);
            }
        } catch (final JSONException e) {
            HBlogger.e(TAG, "读取 JSON 对象字段异常: " + key, (Throwable) e);
        }
        return null;
    }

    public Map<String, String> getNetworkHeaders() {
        final String networkHeaders = this.persistentStorage.getNetworkHeaders();
        return JsonUtils.jsonStringToStringMap(networkHeaders);
    }

    public String getPollingRoute() {
        return this.persistentStorage.getPollingRoute();
    }

    public String getPushTokenSyncRoute() {
        return this.persistentStorage.getPushTokenSyncRoute();
    }

    public Map<String, String> getUserDataKeyMapping() {
        final String userDataKeyMap = this.persistentStorage.getUserDataKeyMapping();
        return JsonUtils.jsonStringToStringMap(userDataKeyMap);
    }

    public String getNotificationStringForCount(final int unreadCount) {
        if (unreadCount > 1) {
            return this.getNotificationString(unreadCount, "plural_message");
        }
        return this.getNotificationString(unreadCount, "single_message");
    }

    private String getNotificationString(final int unreadCount, final String messageKey) {
        final JSONObject notificationContent = this.getNotificationContent();
        if (notificationContent == null) {
            return FALLBACK_NOTIFICATION_STRING;
        }
        try {
            final String singleMessage = notificationContent.getString(messageKey);
            final String placeHolder = notificationContent.getString("placeholder");
            return singleMessage.replace(placeHolder, String.valueOf(unreadCount));
        } catch (final Exception e) {
            HBlogger.e(TAG, "构造未读数通知文案异常", e);
            return FALLBACK_NOTIFICATION_STRING;
        }
    }

    private JSONObject getNotificationContent() {
        final String notificationContent = this.persistentStorage.getNotificationContent();
        if (Utils.isEmpty(notificationContent)) {
            return null;
        }
        try {
            return new JSONObject(notificationContent);
        } catch (final Exception e) {
            HBlogger.e(TAG, "读取未读数通知内容异常", e);
            return null;
        }
    }
}
