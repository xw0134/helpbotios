/**
 * HelpBotBridge_iOS.mm
 * HelpBot SDK iOS Objective-C++ 实现
 */

#include "HelpBotBridge.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <HelpBotSDK/HelpBotSDK-Swift.h> // 假设 Swift Framework 导出头文件

// C 接口导出
extern "C" {

void HelpBot_iOS_Install(const char* channelId, const char* domain, void* callback) {
    NSString* nsChannelId = [NSString stringWithUTF8String:channelId];
    NSString* nsDomain = [NSString stringWithUTF8String:domain];
    HelpBotCallback* cppCallback = (HelpBotCallback*)callback;
    
    // HelpBotConfig 构建
    HelpBotConfig* config = [[HelpBotConfig alloc] initWithChannelId:nsChannelId domain:nsDomain];
    
    // 调用 SDK install
    [HelpBot installWithConfig:config completion:^(BOOL success, NSString * _Nullable message) {
        if (cppCallback) {
            std::string msg = message ? [message UTF8String] : "";
            (*cppCallback)(success, msg);
            delete cppCallback;
        }
    }];
}

void HelpBot_iOS_Login(const char* jwtToken, void* callback) {
    NSString* nsToken = [NSString stringWithUTF8String:jwtToken];
    HelpBotCallback* cppCallback = (HelpBotCallback*)callback;
    
    [HelpBot loginWithJwt:nsToken completion:^(BOOL success, NSString * _Nullable message) {
        if (cppCallback) {
            std::string msg = message ? [message UTF8String] : "";
            (*cppCallback)(success, msg);
            delete cppCallback;
        }
    }];
}

void HelpBot_iOS_ShowConversation(void* callback) {
    HelpBotCallback* cppCallback = (HelpBotCallback*)callback;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController* rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        
        [HelpBot showConversationFrom:rootVC completion:^(BOOL success, NSString * _Nullable message) {
            if (cppCallback) {
                std::string msg = message ? [message UTF8String] : "";
                (*cppCallback)(success, msg);
                delete cppCallback;
            }
        }];
    });
}

void HelpBot_iOS_ShowFAQs(void* callback) {
    HelpBotCallback* cppCallback = (HelpBotCallback*)callback;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController* rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        [HelpBot showFAQsFrom:rootVC completion:nil];
        if (cppCallback) {
            (*cppCallback)(true, "FAQs opened");
            delete cppCallback;
        }
    });
}

void HelpBot_iOS_ShowFAQSection(const char* sectionId, void* callback) {
    NSString* nsSectionId = [NSString stringWithUTF8String:sectionId];
    HelpBotCallback* cppCallback = (HelpBotCallback*)callback;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController* rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        [HelpBot showFAQSection:nsSectionId from:rootVC completion:nil];
        if (cppCallback) {
            (*cppCallback)(true, "FAQ Section opened");
            delete cppCallback;
        }
    });
}

void HelpBot_iOS_ShowSingleFAQ(const char* questionId, void* callback) {
    NSString* nsQuestionId = [NSString stringWithUTF8String:questionId];
    HelpBotCallback* cppCallback = (HelpBotCallback*)callback;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController* rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        [HelpBot showSingleFAQ:nsQuestionId from:rootVC completion:nil];
        if (cppCallback) {
            (*cppCallback)(true, "Single FAQ opened");
            delete cppCallback;
        }
    });
}

void HelpBot_iOS_UpdateSDKMeta(const char** keys, const char** values, int count) {
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:count];
    for (int i = 0; i < count; i++) {
        NSString* key = [NSString stringWithUTF8String:keys[i]];
        NSString* val = [NSString stringWithUTF8String:values[i]];
        [dict setObject:val forKey:key];
    }
    [HelpBot updateSDKMeta:dict];
}

void HelpBot_iOS_UpdateCustomMeta(const char** keys, const char** values, int count) {
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:count];
    for (int i = 0; i < count; i++) {
        NSString* key = [NSString stringWithUTF8String:keys[i]];
        NSString* val = [NSString stringWithUTF8String:values[i]];
        [dict setObject:val forKey:key];
    }
    [HelpBot updateCustomMeta:dict];
}

bool HelpBot_iOS_IsInitialized() {
    return [HelpBot isInitialized];
}

bool HelpBot_iOS_IsConversationVisible() {
    // 假设 SDK 提供此接口，如果没有通过 UIViewController 层级判断
    return NO;
}

const char* HelpBot_iOS_GetSDKVersion() {
    // return [[HelpBot sdkVersion] UTF8String];
    return "0.1.13";
}

} // extern "C"
