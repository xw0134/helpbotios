/**
 * HelpBotBridge.cpp
 * HelpBot SDK C++ 桥接层实现
 * 
 * 根据编译平台选择对应的实现：
 * - Android: 通过 JNI 调用 Java SDK
 * - iOS: 通过 Objective-C++ 调用 Swift/Objective-C SDK
 */

#include "HelpBotBridge.h"
#include "cocos2d.h"

USING_NS_CC;

// 平台特定头文件
#if (CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID)
    #include "platform/android/jni/JniHelper.h"
    #include <jni.h>
#elif (CC_TARGET_PLATFORM == CC_PLATFORM_IOS)
    #include "platform/ios/CCEAGLView-ios.h"
    // iOS 实现在 HelpBotBridge_iOS.mm 中
    extern "C" {
        void HelpBot_iOS_Install(const char* channelId, const char* domain, void* callback);
        void HelpBot_iOS_Login(const char* jwtToken, void* callback);
        void HelpBot_iOS_ShowConversation(void* callback);
        void HelpBot_iOS_ShowFAQs(void* callback);
        void HelpBot_iOS_ShowFAQSection(const char* sectionId, void* callback);
        void HelpBot_iOS_ShowSingleFAQ(const char* questionId, void* callback);
        void HelpBot_iOS_UpdateSDKMeta(const char** keys, const char** values, int count);
        void HelpBot_iOS_UpdateCustomMeta(const char** keys, const char** values, int count);
        bool HelpBot_iOS_IsInitialized();
        bool HelpBot_iOS_IsConversationVisible();
        const char* HelpBot_iOS_GetSDKVersion();
    }
#endif

// 静态成员初始化
HelpBotBridge* HelpBotBridge::s_instance = nullptr;

// ==================== 平台特定实现类 ====================

class HelpBotBridge::Impl {
public:
    Impl() : eventListener(nullptr), initialized(false) {}
    
    ~Impl() {
        eventListener = nullptr;
    }
    
    // 事件监听器
    HelpBotEventListener eventListener;
    
    // 初始化状态
    bool initialized;
    
#if (CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID)
    // Android JNI 辅助方法
    
    /**
     * 调用 HelpBot Java 静态方法
     */
    bool callStaticVoidMethod(const char* methodName, const char* signature, ...) {
        try {
            JniMethodInfo methodInfo;
            if (!JniHelper::getStaticMethodInfo(methodInfo, 
                                                "com/example/HelpBot/HelpBot",
                                                methodName, 
                                                signature)) {
                CCLOG("[HelpBot] 找不到方法: %s", methodName);
                return false;
            }
            
            va_list args;
            va_start(args, signature);
            methodInfo.env->CallStaticVoidMethodV(methodInfo.classID, methodInfo.methodID, args);
            va_end(args);
            
            methodInfo.env->DeleteLocalRef(methodInfo.classID);
            return true;
        } catch (const std::exception& e) {
            CCLOG("[HelpBot] 调用方法异常: %s - %s", methodName, e.what());
            return false;
        }
    }
    
    /**
     * 创建 Java HashMap
     */
    jobject createJavaHashMap(JNIEnv* env, const std::map<std::string, std::string>& map) {
        try {
            jclass hashMapClass = env->FindClass("java/util/HashMap");
            jmethodID hashMapInit = env->GetMethodID(hashMapClass, "<init>", "()V");
            jobject hashMapObj = env->NewObject(hashMapClass, hashMapInit);
            
            jmethodID putMethod = env->GetMethodID(hashMapClass, "put",
                "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
            
            for (const auto& pair : map) {
                jstring key = env->NewStringUTF(pair.first.c_str());
                jstring value = env->NewStringUTF(pair.second.c_str());
                env->CallObjectMethod(hashMapObj, putMethod, key, value);
                env->DeleteLocalRef(key);
                env->DeleteLocalRef(value);
            }
            
            env->DeleteLocalRef(hashMapClass);
            return hashMapObj;
        } catch (const std::exception& e) {
            CCLOG("[HelpBot] 创建 HashMap 异常: %s", e.what());
            return nullptr;
        }
    }
    
    /**
     * 创建 Java ArrayList
     */
    jobject createJavaArrayList(JNIEnv* env, const std::vector<std::string>& list) {
        try {
            jclass arrayListClass = env->FindClass("java/util/ArrayList");
            jmethodID arrayListInit = env->GetMethodID(arrayListClass, "<init>", "()V");
            jobject arrayListObj = env->NewObject(arrayListClass, arrayListInit);
            
            jmethodID addMethod = env->GetMethodID(arrayListClass, "add", "(Ljava/lang/Object;)Z");
            
            for (const auto& item : list) {
                jstring jItem = env->NewStringUTF(item.c_str());
                env->CallBooleanMethod(arrayListObj, addMethod, jItem);
                env->DeleteLocalRef(jItem);
            }
            
            env->DeleteLocalRef(arrayListClass);
            return arrayListObj;
        } catch (const std::exception& e) {
            CCLOG("[HelpBot] 创建 ArrayList 异常: %s", e.what());
            return nullptr;
        }
    }
    
#endif // CC_PLATFORM_ANDROID
};

// ==================== 公共接口实现 ====================

HelpBotBridge::HelpBotBridge() : pImpl(new Impl()) {
    CCLOG("[HelpBot] HelpBotBridge 已创建");
}

HelpBotBridge::~HelpBotBridge() {
    CCLOG("[HelpBot] HelpBotBridge 已销毁");
}

HelpBotBridge* HelpBotBridge::getInstance() {
    if (s_instance == nullptr) {
        s_instance = new HelpBotBridge();
    }
    return s_instance;
}

void HelpBotBridge::destroyInstance() {
    if (s_instance != nullptr) {
        delete s_instance;
        s_instance = nullptr;
    }
}

void HelpBotBridge::install(const std::string& channelId, 
                            const std::string& domain,
                            HelpBotCallback callback) {
    HelpBotConfig config;
    config.channelId = channelId;
    config.domain = domain;

    // 对齐 Android Demo：默认开启标题栏（可由上层通过 customConfig 覆盖）
    try {
        config.customConfig["showTitleBar"] = "true";
    } catch (const std::exception& e) {
        CCLOG("[HelpBot] 设置默认 customConfig 异常: %s", e.what());
    }
    install(config, callback);
}

void HelpBotBridge::install(const HelpBotConfig& config, HelpBotCallback callback) {
    CCLOG("[HelpBot] 开始初始化 SDK - channelId: %s, domain: %s", 
          config.channelId.c_str(), config.domain.c_str());
    
#if (CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID)
    try {
        JniMethodInfo methodInfo;
        if (!JniHelper::getStaticMethodInfo(methodInfo, 
                                            "com/example/HelpBot/HelpBot",
                                            "install", 
                                            "(Landroid/app/Activity;Ljava/lang/String;Ljava/lang/String;Ljava/util/Map;)V")) {
            CCLOG("[HelpBot] 找不到 install 方法");
            if (callback) {
                callback(false, "找不到 install 方法");
            }
            return;
        }
        
        // 获取当前 Activity
        jobject activity = cocos2d::JniHelper::getActivity();
        
        // 创建参数
        jstring jChannelId = methodInfo.env->NewStringUTF(config.channelId.c_str());
        jstring jDomain = methodInfo.env->NewStringUTF(config.domain.c_str());
        
        // 创建配置 Map
        std::map<std::string, std::string> configMap;
        configMap["fullPrivacyMode"] = config.fullPrivacyMode ? "true" : "false";
        configMap["enableSseNotification"] = config.enableSseNotification ? "true" : "false";
        configMap["initTimeout"] = std::to_string(config.initTimeout);
        configMap["webViewLoadTimeout"] = std::to_string(config.webViewLoadTimeout);
        
        // 添加自定义配置
        for (const auto& pair : config.customConfig) {
            configMap[pair.first] = pair.second;
        }
        
        jobject jConfigMap = pImpl->createJavaHashMap(methodInfo.env, configMap);
        
        // 调用 Java 方法
        methodInfo.env->CallStaticVoidMethod(methodInfo.classID, methodInfo.methodID,
                                             activity, jChannelId, jDomain, jConfigMap);
        
        // 清理
        methodInfo.env->DeleteLocalRef(jChannelId);
        methodInfo.env->DeleteLocalRef(jDomain);
        methodInfo.env->DeleteLocalRef(jConfigMap);
        methodInfo.env->DeleteLocalRef(methodInfo.classID);
        
        pImpl->initialized = true;
        CCLOG("[HelpBot] SDK 初始化成功");
        
        if (callback) {
            // 在主线程回调
            Director::getInstance()->getScheduler()->performFunctionInCocosThread([callback]() {
                callback(true, "SDK 初始化成功");
            });
        }
    } catch (const std::exception& e) {
        CCLOG("[HelpBot] SDK 初始化异常: %s", e.what());
        if (callback) {
            std::string errorMsg = std::string("SDK 初始化异常: ") + e.what();
            Director::getInstance()->getScheduler()->performFunctionInCocosThread([callback, errorMsg]() {
                callback(false, errorMsg);
            });
        }
    }
    
#elif (CC_TARGET_PLATFORM == CC_PLATFORM_IOS)
    // iOS 实现
    HelpBot_iOS_Install(config.channelId.c_str(), config.domain.c_str(), 
                       callback ? new HelpBotCallback(callback) : nullptr);
    pImpl->initialized = true;
    
#else
    CCLOG("[HelpBot] 不支持的平台");
    if (callback) {
        callback(false, "不支持的平台");
    }
#endif
}

void HelpBotBridge::login(const std::string& jwtToken, HelpBotCallback callback) {
    CCLOG("[HelpBot] 开始登录");
    
#if (CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID)
    try {
        JniMethodInfo methodInfo;
        if (!JniHelper::getStaticMethodInfo(methodInfo, 
                                            "com/example/HelpBot/HelpBot",
                                            "login", 
                                            "(Ljava/lang/String;Ljava/util/Map;)V")) {
            CCLOG("[HelpBot] 找不到 login 方法");
            if (callback) callback(false, "找不到 login 方法");
            return;
        }
        
        jstring jToken = methodInfo.env->NewStringUTF(jwtToken.c_str());
        
        // 创建登录配置
        std::map<std::string, std::string> loginConfig;
        loginConfig["full_privacy_enabled"] = "false";
        jobject jLoginConfig = pImpl->createJavaHashMap(methodInfo.env, loginConfig);
        
        methodInfo.env->CallStaticVoidMethod(methodInfo.classID, methodInfo.methodID,
                                             jToken, jLoginConfig);
        
        methodInfo.env->DeleteLocalRef(jToken);
        methodInfo.env->DeleteLocalRef(jLoginConfig);
        methodInfo.env->DeleteLocalRef(methodInfo.classID);
        
        CCLOG("[HelpBot] 登录成功");
        if (callback) {
            Director::getInstance()->getScheduler()->performFunctionInCocosThread([callback]() {
                callback(true, "登录成功");
            });
        }
    } catch (const std::exception& e) {
        CCLOG("[HelpBot] 登录异常: %s", e.what());
        if (callback) {
            std::string errorMsg = std::string("登录异常: ") + e.what();
            Director::getInstance()->getScheduler()->performFunctionInCocosThread([callback, errorMsg]() {
                callback(false, errorMsg);
            });
        }
    }
    
#elif (CC_TARGET_PLATFORM == CC_PLATFORM_IOS)
    HelpBot_iOS_Login(jwtToken.c_str(), callback ? new HelpBotCallback(callback) : nullptr);
    
#else
    if (callback) callback(false, "不支持的平台");
#endif
}

void HelpBotBridge::showConversation(HelpBotCallback callback) {
    CCLOG("[HelpBot] 显示对话界面");
    
#if (CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID)
    try {
        JniMethodInfo methodInfo;
        if (!JniHelper::getStaticMethodInfo(methodInfo, 
                                            "com/example/HelpBot/HelpBot",
                                            "showConversation", 
                                            "(Landroid/app/Activity;)V")) {
            CCLOG("[HelpBot] 找不到 showConversation 方法");
            if (callback) callback(false, "找不到 showConversation 方法");
            return;
        }
        
        jobject activity = cocos2d::JniHelper::getActivity();
        methodInfo.env->CallStaticVoidMethod(methodInfo.classID, methodInfo.methodID, activity);
        methodInfo.env->DeleteLocalRef(methodInfo.classID);
        
        CCLOG("[HelpBot] 对话界面已打开");
        if (callback) {
            Director::getInstance()->getScheduler()->performFunctionInCocosThread([callback]() {
                callback(true, "对话界面已打开");
            });
        }
    } catch (const std::exception& e) {
        CCLOG("[HelpBot] 打开对话界面异常: %s", e.what());
        if (callback) {
            std::string errorMsg = std::string("打开对话界面异常: ") + e.what();
            Director::getInstance()->getScheduler()->performFunctionInCocosThread([callback, errorMsg]() {
                callback(false, errorMsg);
            });
        }
    }
    
#elif (CC_TARGET_PLATFORM == CC_PLATFORM_IOS)
    HelpBot_iOS_ShowConversation(callback ? new HelpBotCallback(callback) : nullptr);
    
#else
    if (callback) callback(false, "不支持的平台");
#endif
}

void HelpBotBridge::showFAQs(HelpBotCallback callback) {
    CCLOG("[HelpBot] 显示 FAQ 列表");
    
#if (CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID)
    pImpl->callStaticVoidMethod("showFAQs", "(Landroid/app/Activity;)V", 
                                cocos2d::JniHelper::getActivity());
    if (callback) callback(true, "FAQ 列表已打开");
    
#elif (CC_TARGET_PLATFORM == CC_PLATFORM_IOS)
    HelpBot_iOS_ShowFAQs(callback ? new HelpBotCallback(callback) : nullptr);
    
#else
    if (callback) callback(false, "不支持的平台");
#endif
}

void HelpBotBridge::showFAQSection(const std::string& sectionId, HelpBotCallback callback) {
    CCLOG("[HelpBot] 显示 FAQ 分组: %s", sectionId.c_str());
    
#if (CC_TARGET_PLATFORM == CC_PLATFORM_IOS)
    HelpBot_iOS_ShowFAQSection(sectionId.c_str(), callback ? new HelpBotCallback(callback) : nullptr);
#else
    if (callback) callback(false, "暂未实现");
#endif
}

void HelpBotBridge::showSingleFAQ(const std::string& questionId, HelpBotCallback callback) {
    CCLOG("[HelpBot] 显示单个 FAQ: %s", questionId.c_str());
    
#if (CC_TARGET_PLATFORM == CC_PLATFORM_IOS)
    HelpBot_iOS_ShowSingleFAQ(questionId.c_str(), callback ? new HelpBotCallback(callback) : nullptr);
#else
    if (callback) callback(false, "暂未实现");
#endif
}

void HelpBotBridge::updateSDKMeta(const std::map<std::string, std::string>& sdkMeta) {
    CCLOG("[HelpBot] 更新 SDK Meta");
    
#if (CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID)
    try {
        JniMethodInfo methodInfo;
        if (!JniHelper::getStaticMethodInfo(methodInfo, 
                                            "com/example/HelpBot/HelpBot",
                                            "updateSDKMeta", 
                                            "(Ljava/util/Map;)V")) {
            CCLOG("[HelpBot] 找不到 updateSDKMeta 方法");
            return;
        }
        
        jobject jSdkMeta = pImpl->createJavaHashMap(methodInfo.env, sdkMeta);
        methodInfo.env->CallStaticVoidMethod(methodInfo.classID, methodInfo.methodID, jSdkMeta);
        
        methodInfo.env->DeleteLocalRef(jSdkMeta);
        methodInfo.env->DeleteLocalRef(methodInfo.classID);
    } catch (const std::exception& e) {
        CCLOG("[HelpBot] 更新 SDK Meta 异常: %s", e.what());
    }
    
#elif (CC_TARGET_PLATFORM == CC_PLATFORM_IOS)
    std::vector<const char*> keys, values;
    for (const auto& pair : sdkMeta) {
        keys.push_back(pair.first.c_str());
        values.push_back(pair.second.c_str());
    }
    HelpBot_iOS_UpdateSDKMeta(keys.data(), values.data(), (int)keys.size());
#endif
}

void HelpBotBridge::updateCustomMeta(const std::map<std::string, std::string>& customMeta) {
    CCLOG("[HelpBot] 更新 Custom Meta");
    
#if (CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID)
    try {
        JniMethodInfo methodInfo;
        if (!JniHelper::getStaticMethodInfo(methodInfo, 
                                            "com/example/HelpBot/HelpBot",
                                            "updateCustomMeta", 
                                            "(Ljava/util/Map;)V")) {
            CCLOG("[HelpBot] 找不到 updateCustomMeta 方法");
            return;
        }
        
        jobject jCustomMeta = pImpl->createJavaHashMap(methodInfo.env, customMeta);
        methodInfo.env->CallStaticVoidMethod(methodInfo.classID, methodInfo.methodID, jCustomMeta);
        
        methodInfo.env->DeleteLocalRef(jCustomMeta);
        methodInfo.env->DeleteLocalRef(methodInfo.classID);
    } catch (const std::exception& e) {
        CCLOG("[HelpBot] 更新 Custom Meta 异常: %s", e.what());
    }
    
#elif (CC_TARGET_PLATFORM == CC_PLATFORM_IOS)
    std::vector<const char*> keys, values;
    for (const auto& pair : customMeta) {
        keys.push_back(pair.first.c_str());
        values.push_back(pair.second.c_str());
    }
    HelpBot_iOS_UpdateCustomMeta(keys.data(), values.data(), (int)keys.size());
#endif
}

void HelpBotBridge::addIssueTags(const std::vector<std::string>& tags) {
    CCLOG("[HelpBot] 添加 Issue 标签");
    // 实现类似 updateSDKMeta
}

void HelpBotBridge::removeIssueTags(const std::vector<std::string>& tags) {
    CCLOG("[HelpBot] 移除 Issue 标签");
    // 实现类似 updateSDKMeta
}

void HelpBotBridge::setEventListener(HelpBotEventListener listener) {
    pImpl->eventListener = listener;
    CCLOG("[HelpBot] 事件监听器已设置");
}

void HelpBotBridge::removeEventListener() {
    pImpl->eventListener = nullptr;
    CCLOG("[HelpBot] 事件监听器已移除");
}

bool HelpBotBridge::isInitialized() const {
#if (CC_TARGET_PLATFORM == CC_PLATFORM_IOS)
    return HelpBot_iOS_IsInitialized();
#else
    return pImpl->initialized;
#endif
}

bool HelpBotBridge::isConversationVisible() const {
#if (CC_TARGET_PLATFORM == CC_PLATFORM_IOS)
    return HelpBot_iOS_IsConversationVisible();
#else
    return false; // Android 需要通过 JNI 查询
#endif
}

std::string HelpBotBridge::getSDKVersion() const {
#if (CC_TARGET_PLATFORM == CC_PLATFORM_IOS)
    const char* version = HelpBot_iOS_GetSDKVersion();
    return version ? std::string(version) : "Unknown";
#else
    return "0.1.13"; // Android 版本
#endif
}

void HelpBotBridge::clearWebViewData() {
    CCLOG("[HelpBot] 清理 WebView 数据");
    // 实现 WebView 数据清理
}
