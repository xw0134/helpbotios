#import "HelpBotUnityBridge.h"
#import <HelpBot/HelpBot.h>

// 辅助函数：将 C 字符串转换为 NSString
static NSString* CreateNSString(const char* string) {
    if (string != NULL) {
        return [NSString stringWithUTF8String:string];
    }
    return @"";
}

// 辅助函数：将 NSString 转换为 C 字符串（需要调用者释放）
static char* MakeStringCopy(NSString* nstring) {
    if (nstring == NULL || [nstring length] == 0) {
        return NULL;
    }
    
    const char* string = [nstring UTF8String];
    if (string == NULL) {
        return NULL;
    }
    
    char* res = (char*)malloc(strlen(string) + 1);
    strcpy(res, string);
    return res;
}

// 辅助函数：解析 JSON 字符串为 NSDictionary
static NSDictionary* ParseJsonToDictionary(const char* jsonString) {
    if (jsonString == NULL) {
        return @{};
    }
    
    NSString* jsonStr = CreateNSString(jsonString);
    NSData* jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    
    if (jsonData == nil) {
        return @{};
    }
    
    NSError* error = nil;
    NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    
    if (error != nil || dict == nil) {
        NSLog(@"[HelpBotUnityBridge] JSON 解析失败: %@", error);
        return @{};
    }
    
    return dict;
}

// 辅助函数：将 NSDictionary 转换为 JSON 字符串
static NSString* DictionaryToJson(NSDictionary* dictionary) {
    if (dictionary == nil || [dictionary count] == 0) {
        return @"{}";
    }
    
    NSError* error = nil;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
    
    if (error != nil || jsonData == nil) {
        NSLog(@"[HelpBotUnityBridge] JSON 序列化失败: %@", error);
        return @"{}";
    }
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

// 全局变量：保存事件监听器信息
static NSString* g_eventsGameObjectName = nil;
static NSString* g_eventsMethodName = nil;
static NSString* g_authFailureMethodName = nil;

#ifdef __cplusplus
extern "C" {
#endif

// 初始化 HelpBot SDK
void HelpBot_Install(const char* configJson, const char* gameObjectName, const char* callbackMethod) {
    NSLog(@"[HelpBotUnityBridge] Install");
    
    @try {
        NSDictionary* configDict = ParseJsonToDictionary(configJson);
        NSString* gameObjName = CreateNSString(gameObjectName);
        NSString* cbMethod = CreateNSString(callbackMethod);
        
        // 解析配置
        NSString* channelId = configDict[@"channelId"];
        NSString* domain = configDict[@"domain"];
        
        if (channelId == nil || domain == nil) {
            NSString* errorMsg = [NSString stringWithFormat:@"%@|%d|配置参数缺失", cbMethod, 1002];
            UnitySendMessage([gameObjName UTF8String], "OnInitFailure", [errorMsg UTF8String]);
            return;
        }
        
        // 创建配置对象
        HelpBotConfig* config = [[HelpBotConfig alloc] init];
        config.channelId = channelId;
        config.domain = domain;
        
        if (configDict[@"fullPrivacyMode"] != nil) {
            config.fullPrivacyMode = [configDict[@"fullPrivacyMode"] boolValue];
        }
        if (configDict[@"enableSseNotification"] != nil) {
            config.enableSseNotification = [configDict[@"enableSseNotification"] boolValue];
        }
        if (configDict[@"useDevApi"] != nil) {
            config.useDevApi = [configDict[@"useDevApi"] boolValue];
        }
        if (configDict[@"companyId"] != nil) {
            config.companyId = configDict[@"companyId"];
        }
        if (configDict[@"userId"] != nil) {
            config.userId = configDict[@"userId"];
        }
        if (configDict[@"preGeneratedToken"] != nil) {
            config.preGeneratedToken = configDict[@"preGeneratedToken"];
        }
        
        // 调用 iOS SDK
        [HelpBot installWithConfig:config callback:^(BOOL success, NSInteger errorCode, NSString* errorMessage) {
            if (success) {
                UnitySendMessage([gameObjName UTF8String], "OnInitSuccess", [cbMethod UTF8String]);
            } else {
                NSString* errorMsg = [NSString stringWithFormat:@"%@|%ld|%@", cbMethod, (long)errorCode, errorMessage ?: @"初始化失败"];
                UnitySendMessage([gameObjName UTF8String], "OnInitFailure", [errorMsg UTF8String]);
            }
        }];
        
    } @catch (NSException* exception) {
        NSLog(@"[HelpBotUnityBridge] Install 异常: %@", exception);
    }
}

// 用户登录
void HelpBot_Login(const char* token, const char* loginConfigJson, const char* gameObjectName, const char* callbackMethod) {
    NSLog(@"[HelpBotUnityBridge] Login");
    
    @try {
        NSString* tokenStr = CreateNSString(token);
        NSDictionary* loginConfig = ParseJsonToDictionary(loginConfigJson);
        NSString* gameObjName = CreateNSString(gameObjectName);
        NSString* cbMethod = CreateNSString(callbackMethod);
        
        [HelpBot loginWithToken:tokenStr config:loginConfig callback:^(BOOL success, NSInteger errorCode, NSString* errorMessage) {
            if (success) {
                UnitySendMessage([gameObjName UTF8String], "OnSuccess", [cbMethod UTF8String]);
            } else {
                NSString* errorMsg = [NSString stringWithFormat:@"%@|%ld|%@", cbMethod, (long)errorCode, errorMessage ?: @"登录失败"];
                UnitySendMessage([gameObjName UTF8String], "OnFailure", [errorMsg UTF8String]);
            }
        }];
        
    } @catch (NSException* exception) {
        NSLog(@"[HelpBotUnityBridge] Login 异常: %@", exception);
    }
}

// 显示对话窗口
void HelpBot_ShowConversation(void) {
    NSLog(@"[HelpBotUnityBridge] ShowConversation");
    
    @try {
        [HelpBot showConversation];
    } @catch (NSException* exception) {
        NSLog(@"[HelpBotUnityBridge] ShowConversation 异常: %@", exception);
    }
}

// 显示 FAQ
void HelpBot_ShowFAQs(const char* configJson) {
    NSLog(@"[HelpBotUnityBridge] ShowFAQs");
    
    @try {
        NSDictionary* config = ParseJsonToDictionary(configJson);
        [HelpBot showFAQsWithConfig:config];
    } @catch (NSException* exception) {
        NSLog(@"[HelpBotUnityBridge] ShowFAQs 异常: %@", exception);
    }
}

// 用户登出
void HelpBot_Logout(const char* gameObjectName, const char* callbackMethod) {
    NSLog(@"[HelpBotUnityBridge] Logout");
    
    @try {
        NSString* gameObjName = CreateNSString(gameObjectName);
        NSString* cbMethod = CreateNSString(callbackMethod);
        
        [HelpBot logoutWithCallback:^(BOOL success, NSInteger errorCode, NSString* errorMessage) {
            if (success) {
                UnitySendMessage([gameObjName UTF8String], "OnSuccess", [cbMethod UTF8String]);
            } else {
                NSString* errorMsg = [NSString stringWithFormat:@"%@|%ld|%@", cbMethod, (long)errorCode, errorMessage ?: @"登出失败"];
                UnitySendMessage([gameObjName UTF8String], "OnFailure", [errorMsg UTF8String]);
            }
        }];
        
    } @catch (NSException* exception) {
        NSLog(@"[HelpBotUnityBridge] Logout 异常: %@", exception);
    }
}

// 销毁 SDK
void HelpBot_Destroy(void) {
    NSLog(@"[HelpBotUnityBridge] Destroy");
    
    @try {
        [HelpBot destroy];
        g_eventsGameObjectName = nil;
        g_eventsMethodName = nil;
        g_authFailureMethodName = nil;
    } @catch (NSException* exception) {
        NSLog(@"[HelpBotUnityBridge] Destroy 异常: %@", exception);
    }
}

// 设置事件监听器
void HelpBot_SetEventsListener(const char* gameObjectName, const char* eventMethod, const char* authFailureMethod) {
    NSLog(@"[HelpBotUnityBridge] SetEventsListener");
    
    @try {
        g_eventsGameObjectName = CreateNSString(gameObjectName);
        g_eventsMethodName = CreateNSString(eventMethod);
        g_authFailureMethodName = CreateNSString(authFailureMethod);
        
        [HelpBot setEventsListener:^(NSString* eventName, NSDictionary* data) {
            @try {
                NSString* dataJson = DictionaryToJson(data);
                NSString* message = [NSString stringWithFormat:@"%@|%@", eventName, dataJson];
                UnitySendMessage([g_eventsGameObjectName UTF8String], [g_eventsMethodName UTF8String], [message UTF8String]);
            } @catch (NSException* exception) {
                NSLog(@"[HelpBotUnityBridge] OnEventOccurred 异常: %@", exception);
            }
        } authFailureCallback:^(NSInteger reason) {
            @try {
                NSString* reasonStr = @"UNKNOWN";
                if (reason == 1) {
                    reasonStr = @"INVALID_AUTH_TOKEN";
                } else if (reason == 2) {
                    reasonStr = @"AUTH_TOKEN_EXPIRED";
                }
                UnitySendMessage([g_eventsGameObjectName UTF8String], [g_authFailureMethodName UTF8String], [reasonStr UTF8String]);
            } @catch (NSException* exception) {
                NSLog(@"[HelpBotUnityBridge] OnAuthFailure 异常: %@", exception);
            }
        }];
        
    } @catch (NSException* exception) {
        NSLog(@"[HelpBotUnityBridge] SetEventsListener 异常: %@", exception);
    }
}

// 清除事件监听器
void HelpBot_ClearEventsListener(void) {
    NSLog(@"[HelpBotUnityBridge] ClearEventsListener");
    
    @try {
        [HelpBot setEventsListener:nil authFailureCallback:nil];
        g_eventsGameObjectName = nil;
        g_eventsMethodName = nil;
        g_authFailureMethodName = nil;
    } @catch (NSException* exception) {
        NSLog(@"[HelpBotUnityBridge] ClearEventsListener 异常: %@", exception);
    }
}

// 更新主属性
void HelpBot_UpdateMasterAttributes(const char* attributesJson, const char* gameObjectName, const char* callbackMethod) {
    NSLog(@"[HelpBotUnityBridge] UpdateMasterAttributes");
    
    @try {
        NSDictionary* attributes = ParseJsonToDictionary(attributesJson);
        NSString* gameObjName = CreateNSString(gameObjectName);
        NSString* cbMethod = CreateNSString(callbackMethod);
        
        [HelpBot updateMasterAttributes:attributes callback:^(BOOL success, NSInteger errorCode, NSString* errorMessage) {
            if (success) {
                UnitySendMessage([gameObjName UTF8String], "OnSuccess", [cbMethod UTF8String]);
            } else {
                NSString* errorMsg = [NSString stringWithFormat:@"%@|%ld|%@", cbMethod, (long)errorCode, errorMessage ?: @"更新属性失败"];
                UnitySendMessage([gameObjName UTF8String], "OnFailure", [errorMsg UTF8String]);
            }
        }];
        
    } @catch (NSException* exception) {
        NSLog(@"[HelpBotUnityBridge] UpdateMasterAttributes 异常: %@", exception);
    }
}

// 更新应用属性
void HelpBot_UpdateAppAttributes(const char* attributesJson, const char* gameObjectName, const char* callbackMethod) {
    NSLog(@"[HelpBotUnityBridge] UpdateAppAttributes");
    
    @try {
        NSDictionary* attributes = ParseJsonToDictionary(attributesJson);
        NSString* gameObjName = CreateNSString(gameObjectName);
        NSString* cbMethod = CreateNSString(callbackMethod);
        
        [HelpBot updateAppAttributes:attributes callback:^(BOOL success, NSInteger errorCode, NSString* errorMessage) {
            if (success) {
                UnitySendMessage([gameObjName UTF8String], "OnSuccess", [cbMethod UTF8String]);
            } else {
                NSString* errorMsg = [NSString stringWithFormat:@"%@|%ld|%@", cbMethod, (long)errorCode, errorMessage ?: @"更新属性失败"];
                UnitySendMessage([gameObjName UTF8String], "OnFailure", [errorMsg UTF8String]);
            }
        }];
        
    } @catch (NSException* exception) {
        NSLog(@"[HelpBotUnityBridge] UpdateAppAttributes 异常: %@", exception);
    }
}

// 获取 SDK 版本
const char* HelpBot_GetSDKVersion(void) {
    return "1.0.0";
}

#ifdef __cplusplus
}
#endif
