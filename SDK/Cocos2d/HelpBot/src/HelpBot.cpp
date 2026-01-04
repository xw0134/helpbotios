#include "../include/HelpBot.h"
#include "../include/HBLogger.h"

#if defined(__ANDROID__)
namespace helpbot {
namespace platform {
namespace android {

// Android 平台实现（定义在 platform/android/HelpBotAndroid.cpp）
void install(const HelpBotConfig& config, HelpBotInitCallback* callback);
void login(const std::string& token, const std::map<std::string, std::string>* loginConfig, HelpBotCallback<void>* callback);
bool isInitialized();
std::string getSDKVersion();
HelpBotResult<void> logout();

HelpBotResult<void> showConversation();
HelpBotResult<void> showConversation(const std::map<std::string, std::string>* configMap);
HelpBotResult<void> hideConversation();
bool isConversationVisible();

HelpBotResult<void> showFAQs();
HelpBotResult<void> showFAQs(const std::map<std::string, std::string>* configMap);
HelpBotResult<void> showFAQSection(const std::string& sectionId);
HelpBotResult<void> showFAQSection(const std::string& sectionId, const std::map<std::string, std::string>* configMap);
HelpBotResult<void> showSingleFAQ(const std::string& questionId);
HelpBotResult<void> showSingleFAQ(const std::string& questionId, const std::map<std::string, std::string>* configMap);

HelpBotResult<void> updateSDKMeta(const std::map<std::string, std::string>& sdkMeta);
HelpBotResult<void> updateCustomMeta(const std::map<std::string, std::string>& customMeta);
HelpBotResult<void> addIssueTags(const std::vector<std::string>& tags);
HelpBotResult<void> removeIssueTags(const std::vector<std::string>& tags);
HelpBotResult<void> reportSystemInfoToServer();

void sendMessageAsync(const std::string& message, HelpBotCallback<std::string>* callback);
void getHistoryMessagesAsync(HelpBotCallback<std::string>* callback);
void loadMoreMessagesAsync(int limit, int offset, HelpBotCallback<std::string>* callback);

void setHelpBotEventsListener(HelpBotEventsListener* listener);
void removeHelpBotEventsListener();

void enableSseNotification(bool enable);
bool isSseNotificationEnabled();
void setNotificationSmallIconResId(int resId);
void setNotificationChannelId(const std::string& channelId);

HelpBotResult<void> closeSession();
std::string getWebSdkHealthSnapshotJson();
void markLoginConfirmedFromWeb();
std::string getPendingLoginToken();
std::string consumePendingLoginToken();
void destroy();

} // namespace android
} // namespace platform
} // namespace helpbot
#endif

#if defined(__APPLE__)
#include "../platform/ios/HelpBotBridge.h"
#endif

namespace helpbot {

static const char* TAG = "HelpBot";

void HelpBot::install(const HelpBotConfig& config, HelpBotInitCallback* callback) {
    try {
#if defined(__ANDROID__)
        platform::android::install(config, callback);
#elif defined(__APPLE__)
        platform::ios::HelpBotBridge::install(config, callback);
#else
        if (callback) {
            callback->onInitFailure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
        }
#endif
    } catch (...) {
        if (callback) {
            callback->onInitFailure(HelpBotErrorCode::INTERNAL_ERROR, "install 异常");
        }
    }
}

void HelpBot::install(const std::string& channelId,
                      const std::string& domain,
                      const std::map<std::string, std::string>* configMap,
                      HelpBotInitCallback* callback) {
    try {
        HelpBotConfig::Builder builder;
        builder.channelId(channelId).domain(domain);
        if (configMap) {
            for (const auto& pair : *configMap) {
                builder.addCustomConfig(pair.first, pair.second);
            }
        }
        install(builder.build(), callback);
    } catch (const std::exception& e) {
        if (callback) {
            callback->onInitFailure(HelpBotErrorCode::INVALID_PARAMETER, e.what());
        }
    } catch (...) {
        if (callback) {
            callback->onInitFailure(HelpBotErrorCode::INTERNAL_ERROR, "install 参数异常");
        }
    }
}

bool HelpBot::isInitialized() {
#if defined(__ANDROID__)
    return platform::android::isInitialized();
#elif defined(__APPLE__)
    return platform::ios::HelpBotBridge::isInitialized();
#else
    return false;
#endif
}

std::string HelpBot::getSDKVersion() {
#if defined(__ANDROID__)
    return platform::android::getSDKVersion();
#elif defined(__APPLE__)
    return platform::ios::HelpBotBridge::getSDKVersion();
#else
    return "unknown";
#endif
}

void HelpBot::login(const std::string& identitiesJWT,
                    const std::map<std::string, std::string>* loginConfig,
                    HelpBotCallback<void>* callback) {
    try {
#if defined(__ANDROID__)
        platform::android::login(identitiesJWT, loginConfig, callback);
#elif defined(__APPLE__)
        platform::ios::HelpBotBridge::login(identitiesJWT, loginConfig, callback);
#else
        if (callback) {
            callback->onFailure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
        }
#endif
    } catch (...) {
        if (callback) {
            callback->onFailure(HelpBotErrorCode::INTERNAL_ERROR, "login 异常");
        }
    }
}

HelpBotResult<void> HelpBot::logout() {
#if defined(__ANDROID__)
    return platform::android::logout();
#elif defined(__APPLE__)
    // iOS SDK 未完整接入时，保守返回 success（避免宿主崩溃）；后续应替换为真实实现
    return HelpBotResult<void>::success();
#else
    return HelpBotResult<void>::failure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
#endif
}

HelpBotResult<void> HelpBot::showConversation() {
#if defined(__ANDROID__)
    return platform::android::showConversation();
#elif defined(__APPLE__)
    return platform::ios::HelpBotBridge::showConversation();
#else
    return HelpBotResult<void>::failure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
#endif
}

HelpBotResult<void> HelpBot::showConversation(const std::map<std::string, std::string>* configMap) {
#if defined(__ANDROID__)
    return platform::android::showConversation(configMap);
#elif defined(__APPLE__)
    (void)configMap;
    return platform::ios::HelpBotBridge::showConversation();
#else
    (void)configMap;
    return HelpBotResult<void>::failure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
#endif
}

HelpBotResult<void> HelpBot::hideConversation() {
#if defined(__ANDROID__)
    return platform::android::hideConversation();
#elif defined(__APPLE__)
    return platform::ios::HelpBotBridge::hideConversation();
#else
    return HelpBotResult<void>::failure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
#endif
}

bool HelpBot::isConversationVisible() {
#if defined(__ANDROID__)
    return platform::android::isConversationVisible();
#elif defined(__APPLE__)
    return platform::ios::HelpBotBridge::isConversationVisible();
#else
    return false;
#endif
}

HelpBotResult<void> HelpBot::showFAQs() {
#if defined(__ANDROID__)
    return platform::android::showFAQs();
#elif defined(__APPLE__)
    return platform::ios::HelpBotBridge::showFAQs();
#else
    return HelpBotResult<void>::failure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
#endif
}

HelpBotResult<void> HelpBot::showFAQs(const std::map<std::string, std::string>* configMap) {
#if defined(__ANDROID__)
    return platform::android::showFAQs(configMap);
#elif defined(__APPLE__)
    (void)configMap;
    return platform::ios::HelpBotBridge::showFAQs();
#else
    (void)configMap;
    return HelpBotResult<void>::failure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
#endif
}

HelpBotResult<void> HelpBot::showFAQSection(const std::string& sectionId) {
#if defined(__ANDROID__)
    return platform::android::showFAQSection(sectionId);
#elif defined(__APPLE__)
    return platform::ios::HelpBotBridge::showFAQSection(sectionId);
#else
    (void)sectionId;
    return HelpBotResult<void>::failure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
#endif
}

HelpBotResult<void> HelpBot::showFAQSection(const std::string& sectionId,
                                            const std::map<std::string, std::string>* configMap) {
#if defined(__ANDROID__)
    return platform::android::showFAQSection(sectionId, configMap);
#elif defined(__APPLE__)
    (void)configMap;
    return platform::ios::HelpBotBridge::showFAQSection(sectionId);
#else
    (void)sectionId;
    (void)configMap;
    return HelpBotResult<void>::failure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
#endif
}

HelpBotResult<void> HelpBot::showSingleFAQ(const std::string& questionId) {
#if defined(__ANDROID__)
    return platform::android::showSingleFAQ(questionId);
#elif defined(__APPLE__)
    return platform::ios::HelpBotBridge::showSingleFAQ(questionId);
#else
    (void)questionId;
    return HelpBotResult<void>::failure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
#endif
}

HelpBotResult<void> HelpBot::showSingleFAQ(const std::string& questionId,
                                           const std::map<std::string, std::string>* configMap) {
#if defined(__ANDROID__)
    return platform::android::showSingleFAQ(questionId, configMap);
#elif defined(__APPLE__)
    (void)configMap;
    return platform::ios::HelpBotBridge::showSingleFAQ(questionId);
#else
    (void)questionId;
    (void)configMap;
    return HelpBotResult<void>::failure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
#endif
}

HelpBotResult<void> HelpBot::updateSDKMeta(const std::map<std::string, std::string>& sdkMeta) {
#if defined(__ANDROID__)
    return platform::android::updateSDKMeta(sdkMeta);
#elif defined(__APPLE__)
    return platform::ios::HelpBotBridge::updateSDKMeta(sdkMeta);
#else
    (void)sdkMeta;
    return HelpBotResult<void>::failure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
#endif
}

HelpBotResult<void> HelpBot::updateCustomMeta(const std::map<std::string, std::string>& customMeta) {
#if defined(__ANDROID__)
    return platform::android::updateCustomMeta(customMeta);
#elif defined(__APPLE__)
    return platform::ios::HelpBotBridge::updateCustomMeta(customMeta);
#else
    (void)customMeta;
    return HelpBotResult<void>::failure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
#endif
}

HelpBotResult<void> HelpBot::addIssueTags(const std::vector<std::string>& tags) {
#if defined(__ANDROID__)
    return platform::android::addIssueTags(tags);
#elif defined(__APPLE__)
    return platform::ios::HelpBotBridge::addIssueTags(tags);
#else
    (void)tags;
    return HelpBotResult<void>::failure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
#endif
}

HelpBotResult<void> HelpBot::removeIssueTags(const std::vector<std::string>& tags) {
#if defined(__ANDROID__)
    return platform::android::removeIssueTags(tags);
#elif defined(__APPLE__)
    return platform::ios::HelpBotBridge::removeIssueTags(tags);
#else
    (void)tags;
    return HelpBotResult<void>::failure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
#endif
}

HelpBotResult<void> HelpBot::reportSystemInfoToServer() {
#if defined(__ANDROID__)
    return platform::android::reportSystemInfoToServer();
#elif defined(__APPLE__)
    // iOS 侧待补齐真实上报，这里先返回 success
    return HelpBotResult<void>::success();
#else
    return HelpBotResult<void>::failure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
#endif
}

void HelpBot::sendMessageAsync(const std::string& message, HelpBotCallback<std::string>* callback) {
    try {
#if defined(__ANDROID__)
        platform::android::sendMessageAsync(message, callback);
#else
        if (callback) {
            callback->onFailure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
        }
#endif
    } catch (...) {
        if (callback) {
            callback->onFailure(HelpBotErrorCode::INTERNAL_ERROR, "sendMessageAsync 异常");
        }
    }
}

void HelpBot::getHistoryMessagesAsync(HelpBotCallback<std::string>* callback) {
    try {
#if defined(__ANDROID__)
        platform::android::getHistoryMessagesAsync(callback);
#else
        if (callback) {
            callback->onFailure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
        }
#endif
    } catch (...) {
        if (callback) {
            callback->onFailure(HelpBotErrorCode::INTERNAL_ERROR, "getHistoryMessagesAsync 异常");
        }
    }
}

void HelpBot::loadMoreMessagesAsync(int limit, int offset, HelpBotCallback<std::string>* callback) {
    try {
#if defined(__ANDROID__)
        platform::android::loadMoreMessagesAsync(limit, offset, callback);
#else
        (void)limit;
        (void)offset;
        if (callback) {
            callback->onFailure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
        }
#endif
    } catch (...) {
        if (callback) {
            callback->onFailure(HelpBotErrorCode::INTERNAL_ERROR, "loadMoreMessagesAsync 异常");
        }
    }
}

void HelpBot::setHelpBotEventsListener(HelpBotEventsListener* listener) {
#if defined(__ANDROID__)
    platform::android::setHelpBotEventsListener(listener);
#elif defined(__APPLE__)
    platform::ios::HelpBotBridge::setHelpBotEventsListener(listener);
#else
    (void)listener;
#endif
}

void HelpBot::removeHelpBotEventsListener() {
#if defined(__ANDROID__)
    platform::android::removeHelpBotEventsListener();
#elif defined(__APPLE__)
    platform::ios::HelpBotBridge::setHelpBotEventsListener(nullptr);
#endif
}

void HelpBot::enableSseNotification() {
    enableSseNotification(true);
}

void HelpBot::disableSseNotification() {
    enableSseNotification(false);
}

void HelpBot::enableSseNotification(bool enable) {
#if defined(__ANDROID__)
    platform::android::enableSseNotification(enable);
#else
    (void)enable;
#endif
}

bool HelpBot::isSseNotificationEnabled() {
#if defined(__ANDROID__)
    return platform::android::isSseNotificationEnabled();
#else
    return false;
#endif
}

void HelpBot::setNotificationSmallIconResId(int resId) {
#if defined(__ANDROID__)
    platform::android::setNotificationSmallIconResId(resId);
#else
    (void)resId;
#endif
}

void HelpBot::setNotificationChannelId(const std::string& channelId) {
#if defined(__ANDROID__)
    platform::android::setNotificationChannelId(channelId);
#else
    (void)channelId;
#endif
}

int HelpBot::getUnreadCount() {
    // Android SDK 当前不提供 getUnreadCount 的同步 API；未读数以事件回调为准。
    return 0;
}

HelpBotResult<void> HelpBot::closeSession() {
#if defined(__ANDROID__)
    return platform::android::closeSession();
#else
    return HelpBotResult<void>::failure(HelpBotErrorCode::NOT_SUPPORTED, "当前平台不支持");
#endif
}

std::string HelpBot::getWebSdkHealthSnapshotJson() {
#if defined(__ANDROID__)
    return platform::android::getWebSdkHealthSnapshotJson();
#else
    return "{}";
#endif
}

void HelpBot::markLoginConfirmedFromWeb() {
#if defined(__ANDROID__)
    platform::android::markLoginConfirmedFromWeb();
#endif
}

std::string HelpBot::getPendingLoginToken() {
#if defined(__ANDROID__)
    return platform::android::getPendingLoginToken();
#else
    return "";
#endif
}

std::string HelpBot::consumePendingLoginToken() {
#if defined(__ANDROID__)
    return platform::android::consumePendingLoginToken();
#else
    return "";
#endif
}

HelpBotResult<void> HelpBot::clearWebViewData() {
    // Android SDK 当前无 clearWebViewData 对外 API；保留以兼容旧文档，返回 NOT_SUPPORTED。
    return HelpBotResult<void>::failure(HelpBotErrorCode::NOT_SUPPORTED, "clearWebViewData 暂不支持");
}

void HelpBot::destroy() {
    try {
#if defined(__ANDROID__)
        platform::android::destroy();
#elif defined(__APPLE__)
        platform::ios::HelpBotBridge::destroy();
#endif
    } catch (...) {
        HBLogger::e(TAG, "destroy 异常");
    }
}

} // namespace helpbot


