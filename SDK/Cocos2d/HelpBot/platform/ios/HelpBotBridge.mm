#import "HelpBotBridge.h"
#include "../../include/HBLogger.h"

// 注意:这里假设 iOS SDK 已经存在,实际使用时需要导入 iOS SDK 的头文件
// #import <HelpBotSDK/HelpBotSDK.h>

namespace helpbot {
namespace platform {
namespace ios {

// ==================== Objective-C++ 辅助函数 ====================

/**
 * std::string 转 NSString
 */
static NSString* stringToNSString(const std::string& str) {
    return [NSString stringWithUTF8String:str.c_str()];
}

/**
 * NSString 转 std::string
 */
static std::string nsStringToString(NSString* nsstr) {
    if (!nsstr) {
        return "";
    }
    return std::string([nsstr UTF8String]);
}

/**
 * std::map 转 NSDictionary
 */
static NSDictionary* mapToNSDictionary(const std::map<std::string, std::string>& map) {
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    for (const auto& pair : map) {
        NSString* key = stringToNSString(pair.first);
        NSString* value = stringToNSString(pair.second);
        [dict setObject:value forKey:key];
    }
    return dict;
}

/**
 * NSDictionary 转 std::map
 */
static std::map<std::string, std::string> nsDictionaryToMap(NSDictionary* dict) {
    std::map<std::string, std::string> result;
    if (!dict) {
        return result;
    }
    
    for (NSString* key in dict) {
        id value = [dict objectForKey:key];
        if ([value isKindOfClass:[NSString class]]) {
            result[nsStringToString(key)] = nsStringToString((NSString*)value);
        }
    }
    return result;
}

/**
 * std::vector 转 NSArray
 */
static NSArray* vectorToNSArray(const std::vector<std::string>& vec) {
    NSMutableArray* array = [NSMutableArray array];
    for (const auto& str : vec) {
        [array addObject:stringToNSString(str)];
    }
    return array;
}

// ==================== 回调代理类 ====================

/**
 * 初始化回调代理(C++ -> Objective-C)
 */
@interface HBInitCallbackProxy : NSObject
@property (nonatomic, assign) HelpBotInitCallback* cppCallback;
@end

@implementation HBInitCallbackProxy

- (void)onInitStart {
    if (_cppCallback) {
        _cppCallback->onInitStart();
    }
}

- (void)onInitProgress:(int)progress message:(NSString*)message {
    if (_cppCallback) {
        _cppCallback->onInitProgress(progress, nsStringToString(message));
    }
}

- (void)onInitSuccess {
    if (_cppCallback) {
        _cppCallback->onInitSuccess();
    }
}

- (void)onInitFailure:(int)errorCode message:(NSString*)message {
    if (_cppCallback) {
        HelpBotErrorCode code = static_cast<HelpBotErrorCode>(errorCode);
        _cppCallback->onInitFailure(code, nsStringToString(message));
    }
}

@end

/**
 * 通用回调代理
 */
@interface HBCallbackProxy : NSObject
@property (nonatomic, assign) HelpBotCallback<void>* cppCallback;
@end

@implementation HBCallbackProxy

- (void)onSuccess {
    if (_cppCallback) {
        _cppCallback->onSuccess();
    }
}

- (void)onFailure:(int)errorCode message:(NSString*)message {
    if (_cppCallback) {
        HelpBotErrorCode code = static_cast<HelpBotErrorCode>(errorCode);
        _cppCallback->onFailure(code, nsStringToString(message));
    }
}

@end

// ==================== HelpBotBridge 实现 ====================

void HelpBotBridge::install(const HelpBotConfig& config, HelpBotInitCallback* callback) {
    @autoreleasepool {
        HBLogger::i("HelpBotBridge", "iOS install 开始");
        
        // 注意:这里是示例代码,实际需要调用 iOS SDK
        // 由于 iOS SDK 可能还未实现,这里提供框架代码
        
        /*
        // 创建配置
        HBConfig* iosConfig = [[HBConfig alloc] init];
        iosConfig.channelId = stringToNSString(config.getChannelId());
        iosConfig.domain = stringToNSString(config.getDomain());
        iosConfig.fullPrivacyMode = config.isFullPrivacyMode();
        iosConfig.enableSseNotification = config.isEnableSseNotification();
        
        // 创建回调代理
        HBInitCallbackProxy* proxy = nil;
        if (callback) {
            proxy = [[HBInitCallbackProxy alloc] init];
            proxy.cppCallback = callback;
        }
        
        // 调用 iOS SDK
        [HelpBot installWithConfig:iosConfig callback:^(BOOL success, NSError* error) {
            if (success) {
                [proxy onInitSuccess];
            } else {
                [proxy onInitFailure:error.code message:error.localizedDescription];
            }
        }];
        */
        
        // 临时实现:直接回调成功(用于编译通过)
        if (callback) {
            callback->onInitStart();
            callback->onInitProgress(50, "iOS SDK 初始化中...");
            callback->onInitSuccess();
        }
    }
}

void HelpBotBridge::login(const std::string& token,
                         const std::map<std::string, std::string>* loginConfig,
                         HelpBotCallback<void>* callback) {
    @autoreleasepool {
        HBLogger::i("HelpBotBridge", "iOS login 开始");
        
        /*
        NSString* nsToken = stringToNSString(token);
        NSDictionary* nsConfig = loginConfig ? mapToNSDictionary(*loginConfig) : nil;
        
        HBCallbackProxy* proxy = nil;
        if (callback) {
            proxy = [[HBCallbackProxy alloc] init];
            proxy.cppCallback = callback;
        }
        
        [HelpBot loginWithToken:nsToken config:nsConfig callback:^(BOOL success, NSError* error) {
            if (success) {
                [proxy onSuccess];
            } else {
                [proxy onFailure:error.code message:error.localizedDescription];
            }
        }];
        */
        
        // 临时实现
        if (callback) {
            callback->onSuccess();
        }
    }
}

HelpBotResult<void> HelpBotBridge::showConversation() {
    @autoreleasepool {
        HBLogger::i("HelpBotBridge", "iOS showConversation");
        
        /*
        BOOL success = [HelpBot showConversation];
        if (success) {
            return HelpBotResult<void>::success();
        } else {
            return HelpBotResult<void>::failure(HelpBotErrorCode::INTERNAL_ERROR, "显示对话失败");
        }
        */
        
        return HelpBotResult<void>::success();
    }
}

HelpBotResult<void> HelpBotBridge::hideConversation() {
    @autoreleasepool {
        return HelpBotResult<void>::success();
    }
}

bool HelpBotBridge::isInitialized() {
    @autoreleasepool {
        // return [HelpBot isInitialized];
        return true;
    }
}

bool HelpBotBridge::isConversationVisible() {
    @autoreleasepool {
        // return [HelpBot isConversationVisible];
        return false;
    }
}

std::string HelpBotBridge::getSDKVersion() {
    @autoreleasepool {
        // NSString* version = [HelpBot getSDKVersion];
        // return nsStringToString(version);
        return "1.0.0-cocos2d";
    }
}

HelpBotResult<void> HelpBotBridge::showFAQs() {
    @autoreleasepool {
        return HelpBotResult<void>::success();
    }
}

HelpBotResult<void> HelpBotBridge::showFAQSection(const std::string& sectionId) {
    @autoreleasepool {
        return HelpBotResult<void>::success();
    }
}

HelpBotResult<void> HelpBotBridge::showSingleFAQ(const std::string& questionId) {
    @autoreleasepool {
        return HelpBotResult<void>::success();
    }
}

HelpBotResult<void> HelpBotBridge::updateSDKMeta(const std::map<std::string, std::string>& sdkMeta) {
    @autoreleasepool {
        return HelpBotResult<void>::success();
    }
}

HelpBotResult<void> HelpBotBridge::updateCustomMeta(const std::map<std::string, std::string>& customMeta) {
    @autoreleasepool {
        return HelpBotResult<void>::success();
    }
}

HelpBotResult<void> HelpBotBridge::addIssueTags(const std::vector<std::string>& tags) {
    @autoreleasepool {
        return HelpBotResult<void>::success();
    }
}

HelpBotResult<void> HelpBotBridge::removeIssueTags(const std::vector<std::string>& tags) {
    @autoreleasepool {
        return HelpBotResult<void>::success();
    }
}

void HelpBotBridge::setHelpBotEventsListener(HelpBotEventsListener* listener) {
    @autoreleasepool {
        // 实现事件监听器设置
    }
}

void HelpBotBridge::destroy() {
    @autoreleasepool {
        // [HelpBot destroy];
    }
}

} // namespace ios
} // namespace platform

// ==================== HelpBot 公共 API 实现(iOS 平台) ====================

#if defined(__APPLE__) && !defined(__ANDROID__)

void HelpBot::install(const HelpBotConfig& config, HelpBotInitCallback* callback) {
    platform::ios::HelpBotBridge::install(config, callback);
}

void HelpBot::install(const std::string& channelId, const std::string& domain,
                     const std::map<std::string, std::string>* configMap,
                     HelpBotInitCallback* callback) {
    HelpBotConfig::Builder builder;
    builder.channelId(channelId).domain(domain);
    
    if (configMap) {
        for (const auto& pair : *configMap) {
            builder.addCustomConfig(pair.first, pair.second);
        }
    }
    
    install(builder.build(), callback);
}

bool HelpBot::isInitialized() {
    return platform::ios::HelpBotBridge::isInitialized();
}

std::string HelpBot::getSDKVersion() {
    return platform::ios::HelpBotBridge::getSDKVersion();
}

void HelpBot::login(const std::string& identitiesJWT,
                   const std::map<std::string, std::string>* loginConfig,
                   HelpBotCallback<void>* callback) {
    platform::ios::HelpBotBridge::login(identitiesJWT, loginConfig, callback);
}

HelpBotResult<void> HelpBot::showConversation() {
    return platform::ios::HelpBotBridge::showConversation();
}

HelpBotResult<void> HelpBot::hideConversation() {
    return platform::ios::HelpBotBridge::hideConversation();
}

bool HelpBot::isConversationVisible() {
    return platform::ios::HelpBotBridge::isConversationVisible();
}

HelpBotResult<void> HelpBot::showFAQs() {
    return platform::ios::HelpBotBridge::showFAQs();
}

HelpBotResult<void> HelpBot::showFAQSection(const std::string& sectionId) {
    return platform::ios::HelpBotBridge::showFAQSection(sectionId);
}

HelpBotResult<void> HelpBot::showSingleFAQ(const std::string& questionId) {
    return platform::ios::HelpBotBridge::showSingleFAQ(questionId);
}

HelpBotResult<void> HelpBot::updateSDKMeta(const std::map<std::string, std::string>& sdkMeta) {
    return platform::ios::HelpBotBridge::updateSDKMeta(sdkMeta);
}

HelpBotResult<void> HelpBot::updateCustomMeta(const std::map<std::string, std::string>& customMeta) {
    return platform::ios::HelpBotBridge::updateCustomMeta(customMeta);
}

HelpBotResult<void> HelpBot::addIssueTags(const std::vector<std::string>& tags) {
    return platform::ios::HelpBotBridge::addIssueTags(tags);
}

HelpBotResult<void> HelpBot::removeIssueTags(const std::vector<std::string>& tags) {
    return platform::ios::HelpBotBridge::removeIssueTags(tags);
}

void HelpBot::setHelpBotEventsListener(HelpBotEventsListener* listener) {
    platform::ios::HelpBotBridge::setHelpBotEventsListener(listener);
}

void HelpBot::destroy() {
    platform::ios::HelpBotBridge::destroy();
}

#endif // __APPLE__

} // namespace helpbot
