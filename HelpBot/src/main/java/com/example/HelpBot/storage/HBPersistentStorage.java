package com.example.HelpBot.storage;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.example.HelpBot.utils.Utils;
import com.example.HelpBot.log.HBlogger;
import com.example.HelpBot.utils.JsonUtils;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * HelpBot 持久化存储管理类。
 * 负责 SDK 配置、用户信息、设备 ID 等数据的持久化，支持敏感数据加密存储。
 */
public class HBPersistentStorage {
    private final ISharedPreferencesStore preferences;
    private final Context appContext;
    @Nullable
    private final EncryptedStorage encryptedStorage;
    private static final String ENC_PREFIX = "__enc__";
    public static final String TAG = "HBPerStore";
    public static final String FILE_NAME = "__hs_lite_sdk_store";
    public static final String CHAT_RESOURCE_CACHE_SHARED_PREF_NAME = "__hs_chat_resource_cache";
    public static final String HC_RESOURCE_CACHE_SHARED_PREF_NAME = "__hs_helpCenter_resource_cache";
    public static final String LEGACY_ANALYTICS_EVENTS_IDS = "legacy_event_ids";
    private static final String DOMAIN = "domain";
    private static final String HOST = "host";
    private static final String ACTIVE_USER = "active_user";
    private static final String CONFIG = "config";
    private static final String LOCAL_PROACTIVE_CONFIG = "localProactiveConfig";
    private static final String LANGUAGE = "language";
    private static final String LOCAL_STORAGE_DATA = "local_storage_data";
    private static final String ADDITIONAL_HC_DATA = "additional_hc_data";
    private static final String CURRENT_PUSH_TOKEN = "current_push_token";
    public static final String HB_DEVICE_ID = "hb_device_id";
    private static final String APP_LAUNCH_LAST_SYNC_TIMESTAMP = "app_launch_last_sync_timestamp";
    private static final String APP_LAUNCH_EVENTS = "app_launch_events";
    private static final String NOTIFICATION_SOUND_ID = "notificationSoundId";
    private static final String NOTIFICATION_CHANNEL_ID = "notificationChannelId";
    private static final String NOTIFICATION_ICON = "notificationIcon";
    private static final String NOTIFICATION_LARGE_ICON = "notificationLargeIcon";
    private static final String CLEAR_ANONYMOUS_USER = "clear_anonymous_user";
    private static final String WEBCHAT_UI_CONFIG_DATA = "ui_config_data";
    private static final String HELP_CENTER_UI_CONFIG_DATA = "help_center_ui_config_data";
    private static final String ENABLE_IN_APP_NOTIFICATION = "enable_in_app_notification";
    private static final String SCREEN_ORIENTATION = "screenOrientation";
    private static final String ANONYMOUS_USER_ID_MAP = "anon_user_id_map";
    private static final String NETWORK_HEADERS = "network_headers";
    private static final String POLLING_ROUTE = "polling_route";
    private static final String PUSH_TOKEN_SYNC_ROUTE = "push_token_sync_route";
    private static final String NOTIFICATION_CONTENT = "notification_content";
    private static final String USER_DATA_KEY_MAPPING = "user_data_key_mapping";
    private static final String BREADCRUMBS = "breadcrumbs";
    private static final String FAILED_ANALYTICS_EVENTS = "failed_analytics_events";
    private static final String LAST_REQUEST_UNREAD_COUNT_API_ACCESS = "last_unread_count_api_access";
    private static final String LAST_HELP_CENTER_CACHE_EVICTED_TIME = "last_help_center_cache_eviction_time";
    private String platform_id;
    private static final String ENABLE_LOGGING_VIA_WEBCHAT = "enableLoggingViaWebchat";
    static final String START_TIME = "startTime";
    private static final String USER_SESSION_EXPIRY_ALERTS_ALLOWED = "user_session_expiry_alerts_allowed";
    private static final String RETAINED_ANON_UID_FOR_IDENTITY_USER = "retained_anon_uid_for_identity_user";
    private static final String LAST_LOGGED_OUT_USER = "last_logged_out_user";

    public HBPersistentStorage(final Context context, final ISharedPreferencesStore preferences) {
        if (context == null) {
            throw new IllegalArgumentException("context 不能为空");
        }
        this.appContext = context.getApplicationContext();
        this.preferences = preferences;
        EncryptedStorage es = null;
        try {
            es = EncryptedStorage.getInstance(this.appContext);
            if (es == null || !es.isAvailable()) {
                es = null;
            }
        } catch (final Exception ignored) {
            es = null;
        }
        this.encryptedStorage = es;
    }

    /**
     * 读取敏感字符串（优先从 EncryptedStorage 读取；若只有历史明文，则返回明文并尝试迁移到加密存储）。
     */
    @NonNull
    private String getSensitiveString(@NonNull final String key) {
        try {
            final EncryptedStorage es = encryptedStorage;
            if (es != null) {
                final String enc = es.getEncryptedString(ENC_PREFIX + key);
                if (!Utils.isEmpty(enc)) {
                    return enc;
                }
            }
        } catch (final Exception ignored) {
        }

        // 兼容历史明文值
        final String plain = this.getString(key);
        if (!Utils.isEmpty(plain)) {
            try {
                final EncryptedStorage es = encryptedStorage;
                if (es != null) {
                    es.putEncryptedString(ENC_PREFIX + key, plain);
                    this.preferences.remove(key);
                }
            } catch (final Exception ignored) {
            }
        }
        return plain;
    }

    /**
     * 写入敏感字符串（优先加密存储，并清理历史明文字段）。
     */
    private void putSensitiveString(@NonNull final String key, @Nullable final String value) {
        try {
            final EncryptedStorage es = encryptedStorage;
            if (es != null) {
                es.putEncryptedString(ENC_PREFIX + key, value);
                // 防止“双写”导致明文残留
                this.preferences.remove(key);
                return;
            }
        } catch (final Exception ignored) {
        }
        this.putString(key, value);
    }

    public void setDomain(final String domain) {
        this.putString(DOMAIN, domain);
    }

    public String getDomain() {
        return this.getString(DOMAIN);
    }

    public void setHost(final String host) {
        this.putString(HOST, host);
    }

    public String getHost() {
        return this.getString(HOST);
    }

    public void setPlatformId(final String platformId) {
        this.platform_id = platformId;
    }

    public String getPlatformId() {
        return this.platform_id;
    }

    public void setActiveUser(final String userData) {
        // active_user 可能包含用户身份信息，按敏感数据处理
        this.putSensitiveString(ACTIVE_USER, userData);
    }

    public String getActiveUser() {
        return this.getSensitiveString(ACTIVE_USER);
    }

    public void removeActiveUser() {
        this.preferences.remove(ACTIVE_USER);
    }

    public void setConfig(final String config) {
        this.putString(CONFIG, config);
    }

    public String getConfig() {
        return this.getString(CONFIG);
    }

    public void setLocalProactiveConfig(final String localProactiveConfig) {
        this.putString(LOCAL_PROACTIVE_CONFIG, localProactiveConfig);
    }

    public String getLocalProactiveConfig() {
        return this.getString(LOCAL_PROACTIVE_CONFIG);
    }

    public void setLanguage(final String language) {
        this.putString(LANGUAGE, language);
    }

    public String getLanguage() {
        return this.getString(LANGUAGE);
    }

    public void saveLocalStorageData(final String data) {
        this.putString(LOCAL_STORAGE_DATA, data);
    }

    public String getLocalStorageData() {
        return this.getString(LOCAL_STORAGE_DATA);
    }

    public void saveAdditionalHelpCenterData(final String data) {
        this.putString(ADDITIONAL_HC_DATA, data);
    }

    public String getAdditionalHelpCenterData() {
        return this.getString(ADDITIONAL_HC_DATA);
    }

    public void setCurrentPushToken(final String token) {
        // push token 属于敏感标识符，按敏感数据处理
        this.putSensitiveString(CURRENT_PUSH_TOKEN, token);
    }

    public String getCurrentPushToken() {
        return this.getSensitiveString(CURRENT_PUSH_TOKEN);
    }

    public void setClearAnonymousUser(final boolean clearAnonymousUser) {
        this.putBoolean(CLEAR_ANONYMOUS_USER, clearAnonymousUser);
    }

    public boolean isClearAnonymousUser() {
        return this.getBoolean(CLEAR_ANONYMOUS_USER);
    }

    public int getNotificationSoundId() {
        return this.getInt(NOTIFICATION_SOUND_ID);
    }

    public String getNotificationChannelId() {
        return this.getString(NOTIFICATION_CHANNEL_ID);
    }

    public int getNotificationIcon() {
        return this.getInt(NOTIFICATION_ICON);
    }

    public int getNotificationLargeIcon() {
        return this.getInt(NOTIFICATION_LARGE_ICON);
    }

    public void setNotificationSoundId(final int soundId) {
        this.putInt(NOTIFICATION_SOUND_ID, soundId);
    }

    public void setNotificationChannelId(final String channelId) {
        this.putString(NOTIFICATION_CHANNEL_ID, channelId);
    }

    public void setNotificationIcon(final int icon) {
        this.putInt(NOTIFICATION_ICON, icon);
    }

    public void setNotificationLargeIcon(final int largeIcon) {
        this.putInt(NOTIFICATION_LARGE_ICON, largeIcon);
    }

    public void setEnableInAppNotification(final boolean enableInAppNotification) {
        this.putBoolean(ENABLE_IN_APP_NOTIFICATION, enableInAppNotification);
    }

    public boolean getEnableInAppNotification() {
        return this.getBoolean(ENABLE_IN_APP_NOTIFICATION);
    }

    public void setRequestedScreenOrientation(final int screenOrientation) {
        this.putInt(SCREEN_ORIENTATION, screenOrientation);
    }

    public int getRequestedScreenOrientation() {
        return this.getInt(SCREEN_ORIENTATION);
    }

    public void setWebchatUiConfigData(final String data) {
        this.putString(WEBCHAT_UI_CONFIG_DATA, data);
    }

    public String getWebchatUiConfigData() {
        return this.getString(WEBCHAT_UI_CONFIG_DATA);
    }

    public void setHelpCenterUiConfigData(final String data) {
        this.putString(HELP_CENTER_UI_CONFIG_DATA, data);
    }

    public String getHelpCenterUiConfigData() {
        return this.getString(HELP_CENTER_UI_CONFIG_DATA);
    }

    public String getHsDeviceId() {
        return this.getString(HB_DEVICE_ID);
    }

    public void setHsDeviceId(final String did) {
        this.putString(HB_DEVICE_ID, did);
    }

    public long getLastSuccessfulAppLaunchEventSyncTime() {
        return this.getLong(APP_LAUNCH_LAST_SYNC_TIMESTAMP);
    }

    public void setLastAppLaunchEventSyncTime(final long timestamp) {
        this.putLong(APP_LAUNCH_LAST_SYNC_TIMESTAMP, timestamp);
    }

    public String getAppLaunchEvents() {
        return this.getString(APP_LAUNCH_EVENTS);
    }

    public void storeAppLaunchEvents(final String appLaunchEventsJson) {
        this.putString(APP_LAUNCH_EVENTS, appLaunchEventsJson);
    }

    public void clearAppLaunchEvents() {
        this.preferences.remove(APP_LAUNCH_EVENTS);
    }

    public void storeUserDataKeyMapping(final String userDataMap) {
        this.putString(USER_DATA_KEY_MAPPING, userDataMap);
    }

    public void storeNotificationContent(final String notificationContent) {
        this.putString(NOTIFICATION_CONTENT, notificationContent);
    }

    public void storeNetworkHeaders(final String networkHeaders) {
        // network_headers 可能包含 Authorization/Cookie 等敏感信息，必须加密存储
        this.putSensitiveString(NETWORK_HEADERS, networkHeaders);
    }

    public void storePushTokenRoute(final String pushTokenRoute) {
        this.putString(PUSH_TOKEN_SYNC_ROUTE, pushTokenRoute);
    }

    public void storePollingRoute(final String pollingRoute) {
        this.putString(POLLING_ROUTE, pollingRoute);
    }

    public void storeAnonymousUserIdMap(final String anonymousUserIdMap) {
        this.putString(ANONYMOUS_USER_ID_MAP, anonymousUserIdMap);
    }

    public String getAnonymousUserIdMap() {
        return this.getString(ANONYMOUS_USER_ID_MAP);
    }

    public void removeAnonymousUserIdMap() {
        this.preferences.remove(ANONYMOUS_USER_ID_MAP);
    }

    public String getNetworkHeaders() {
        return this.getSensitiveString(NETWORK_HEADERS);
    }

    public String getPollingRoute() {
        return this.getString(POLLING_ROUTE);
    }

    public String getPushTokenSyncRoute() {
        return this.getString(PUSH_TOKEN_SYNC_ROUTE);
    }

    public String getNotificationContent() {
        return this.getString(NOTIFICATION_CONTENT);
    }

    public String getUserDataKeyMapping() {
        return this.getString(USER_DATA_KEY_MAPPING);
    }

    public void setFailedAnalyticsEvents(JSONArray events) {
        if (events == null) {
            events = new JSONArray();
        }
        this.putString(FAILED_ANALYTICS_EVENTS, events.toString());
    }

    public void setLastRequestUnreadCountApiAccess(final long timestamp) {
        this.putLong(LAST_REQUEST_UNREAD_COUNT_API_ACCESS, timestamp);
    }

    public long getLastRequestUnreadCountApiAccess() {
        return this.getLong(LAST_REQUEST_UNREAD_COUNT_API_ACCESS);
    }

    public JSONArray getFailedAnalyticsEvents() {
        try {
            final String failedEventJsonStr = this.getString(FAILED_ANALYTICS_EVENTS);
            if (Utils.isEmpty(failedEventJsonStr)) {
                return new JSONArray();
            }
            return new JSONArray(failedEventJsonStr);
        } catch (final Exception e) {
            HBlogger.e(TAG, "获取失败的分析事件时出错", e);
            return new JSONArray();
        }
    }

    public void setBreadCrumbs(String jsonifiedBreadCrumbs) {
        if (Utils.isEmpty(jsonifiedBreadCrumbs)) {
            jsonifiedBreadCrumbs = new JSONArray().toString();
        }
        this.putString(BREADCRUMBS, jsonifiedBreadCrumbs);
    }

    public JSONArray getBreadCrumbs() throws JSONException {
        try {
            final String jsonBreadCrumbs = this.getString(BREADCRUMBS);
            if (!Utils.isEmpty(jsonBreadCrumbs)) {
                return new JSONArray(jsonBreadCrumbs);
            }
        } catch (final Exception e) {
            HBlogger.e(TAG, "获取面包屑导航数据时出错", e);
        }
        return new JSONArray();
    }

    public void setLastHCCacheEvictedTime(final long time) {
        this.putLong(LAST_HELP_CENTER_CACHE_EVICTED_TIME, time);
    }

    public long getLastHCCacheEvictedTime() {
        return this.getLong(LAST_HELP_CENTER_CACHE_EVICTED_TIME);
    }

    void setEnableLoggingViaWebchat(final String enableLoggingViaWebchatJson) {
        this.putString(ENABLE_LOGGING_VIA_WEBCHAT, enableLoggingViaWebchatJson);
    }

    public boolean getEnableLoggingViaWebchat() {
        try {
            final String enableLoggingJSONStr = this.preferences.getString(ENABLE_LOGGING_VIA_WEBCHAT);
            if (Utils.isEmpty(enableLoggingJSONStr) || !JsonUtils.isValidJsonString(enableLoggingJSONStr)) {
                return false;
            }
            final JSONObject enableLoggingJSON = new JSONObject(enableLoggingJSONStr);
            final boolean enableLoggingFlag = enableLoggingJSON.optBoolean("enable", false);
            final long startTime = enableLoggingJSON.optLong(START_TIME, 0L);
            final long ttl = enableLoggingJSON.optLong("ttl", 0L);
            if (System.currentTimeMillis() - startTime < ttl) {
                return enableLoggingFlag;
            }
            this.preferences.remove(ENABLE_LOGGING_VIA_WEBCHAT);
        } catch (final Exception e) {
            HBlogger.e(TAG, "从 WebChat 评估日志开启 JSON 时出错", e);
        }
        return false;
    }

    public boolean isUserSessionExpiryAlertsAllowed() {
        return this.getBoolean(USER_SESSION_EXPIRY_ALERTS_ALLOWED);
    }

    public void shouldAllowUserSessionExpiryAlerts(final boolean value) {
        this.putBoolean(USER_SESSION_EXPIRY_ALERTS_ALLOWED, value);
    }

    public void saveLoggedOutUser(final String userType) {
        this.putString(LAST_LOGGED_OUT_USER, userType);
    }

    public String getLastLoggedOutUser() {
        return this.getString(LAST_LOGGED_OUT_USER);
    }

    public void retainAnonUidForIdentityUser(final String anonUid) {
        this.putString(RETAINED_ANON_UID_FOR_IDENTITY_USER, anonUid);
    }

    public String getRetainedAnonUidForIdentityUser() {
        return this.getString(RETAINED_ANON_UID_FOR_IDENTITY_USER);
    }

    private void putLong(final String key, final long value) {
        this.preferences.putLong(key, value);
    }

    private long getLong(final String key) {
        return this.preferences.getLong(key);
    }

    private void putInt(final String key, final int value) {
        this.preferences.putInt(key, value);
    }

    private int getInt(final String key) {
        return this.preferences.getInt(key);
    }

    private void putBoolean(final String key, final boolean value) {
        this.preferences.putBoolean(key, value);
    }

    private boolean getBoolean(final String key) {
        return this.preferences.getBoolean(key);
    }

    public void putString(final String key, final String value) {
        this.preferences.putString(key, value);
    }

    public String getString(final String key) {
        return this.preferences.getString(key);
    }
}
