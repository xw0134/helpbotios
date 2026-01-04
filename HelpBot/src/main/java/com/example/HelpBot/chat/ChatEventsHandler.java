package com.example.HelpBot.chat;

import com.example.HelpBot.core.HelpBotContext;
import com.example.HelpBot.log.HBlogger;
import com.example.HelpBot.storage.HBPersistentStorage;
import com.example.HelpBot.utils.JsonUtils;
import com.example.HelpBot.utils.Utils;

import org.json.JSONObject;

public class ChatEventsHandler {
    private static final String TAG = "ChatEventsHandler";

    public ChatEventsHandler() {
    }

    public void sdkxMigrationLogSynced(final boolean isSuccess) {
        HBlogger.d(TAG, "SDKX 迁移日志同步: " + isSuccess);
    }

    public void onSetLocalStorage(final String data) {
        if (Utils.isEmpty(data) || !JsonUtils.isValidJsonString(data)) {
            return;
        }
        try {
            final HelpBotContext hbContext = HelpBotContext.getInstance();
            if (hbContext == null) {
                return;
            }
            final HBPersistentStorage storage = hbContext.getPersistentStorage();
            if (storage == null) {
                return;
            }

            final String storedData = storage.getLocalStorageData();
            if (Utils.isNotEmpty(storedData) && JsonUtils.isValidJsonString(storedData)) {
                final JSONObject dataToStoreJson = new JSONObject(data);
                final JSONObject storedDataJson = new JSONObject(storedData);
                final java.util.Iterator<String> keysIterator = dataToStoreJson.keys();
                while (keysIterator.hasNext()) {
                    final String key = keysIterator.next();
                    storedDataJson.put(key, dataToStoreJson.get(key));
                }
                storage.saveLocalStorageData(storedDataJson.toString());
            } else {
                storage.saveLocalStorageData(data);
            }
        } catch (final Exception e) {
            HBlogger.e(TAG, "onSetLocalStorage 异常", e);
        }
    }

    public void onRemoveLocalStorage(final String data) {
        if (Utils.isEmpty(data) || !JsonUtils.isValidJsonString(data)) {
            return;
        }
        try {
            final HelpBotContext hbContext = HelpBotContext.getInstance();
            if (hbContext == null) {
                return;
            }
            final HBPersistentStorage storage = hbContext.getPersistentStorage();
            if (storage == null) {
                return;
            }
            final String locallyStoredData = storage.getLocalStorageData();
            if (Utils.isEmpty(locallyStoredData) || !JsonUtils.isValidJsonString(locallyStoredData)) {
                return;
            }

            final JSONObject dataToRemoveObject = new JSONObject(data);
            final org.json.JSONArray listOfKeysJson = dataToRemoveObject.optJSONArray("data");
            if (listOfKeysJson == null) {
                return;
            }
            final JSONObject localStoredDataJson = new JSONObject(locallyStoredData);
            for (int i = 0; i < listOfKeysJson.length(); ++i) {
                final String key = listOfKeysJson.optString(i, null);
                if (!Utils.isEmpty(key) && localStoredDataJson.has(key)) {
                    localStoredDataJson.remove(key);
                }
            }
            storage.saveLocalStorageData(localStoredDataJson.toString());
        } catch (final Exception e) {
            HBlogger.e(TAG, "onRemoveLocalStorage 异常", e);
        }
    }

    public void getHelpCenterData() {
    }

    public void onReceivePushTokenSyncRequestData(final String data) {
        try {
            if (Utils.isEmpty(data)) {
                return;
            }
            final HelpBotContext hbContext = HelpBotContext.getInstance();
            if (hbContext == null) {
                return;
            }
            final HBPersistentStorage storage = hbContext.getPersistentStorage();
            if (storage == null) {
                return;
            }
            final JSONObject obj = new JSONObject(data);
            final String token = obj.optString("pushToken", "");
            if (!Utils.isEmpty(token)) {
                storage.setCurrentPushToken(token);
            }
        } catch (final Exception e) {
            HBlogger.e(TAG, "onReceivePushTokenSyncRequestData 异常", e);
        }
    }

    public void onRemoveAnonymousUser() {
    }

    void setPollingStatus(final String data) {
        try {
            final JSONObject pollingStatusData = new JSONObject(data);
            final boolean pollingStatus = pollingStatusData.optBoolean("shouldPoll", false);
            HBlogger.d(TAG, "设置轮询状态: shouldPoll=" + pollingStatus);
        } catch (final Exception e) {
            HBlogger.e(TAG, "setPollingStatus 异常", e);
        }
    }

    void setGenericSdkData(final String data) {
    }

    void setIssueExistsForUser(final String data) {
    }

    void onWebchatClosed() {
        HBlogger.d(TAG, "WebChat 已关闭");
    }

    void onWebchatLoaded() {
        HBlogger.d(TAG, "WebChat 已加载");
    }

    void onWebchatError(final String errorMessage) {
        HBlogger.w(TAG, "WebChat 错误: " + errorMessage);
    }

    void onUserAuthenticationFailure() {
        HBlogger.w(TAG, "用户认证失败");
    }

    void onUiConfigChange(final String data) {
    }

    void requestConversationMetadata(final String data) {
    }

    void webchatJsFileLoaded() {
        HBlogger.d(TAG, "WebChat JS 文件加载完成");
    }

    void wcActionSync(final String data) {
    }
}
