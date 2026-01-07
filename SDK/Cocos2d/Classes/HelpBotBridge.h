/**
 * HelpBotBridge.h
 * HelpBot SDK C++ 桥接层
 * 
 * 提供统一的 C++ 接口，内部根据平台调用 Android JNI 或 iOS Objective-C++ 实现
 * 
 * 设计原则：
 * - 线程安全：所有回调在主线程执行
 * - 异常处理：完整的 try-catch 包裹
 * - 内存管理：智能指针管理生命周期
 * - 平台隔离：平台特定代码通过条件编译隔离
 */

#ifndef __HELPBOT_BRIDGE_H__
#define __HELPBOT_BRIDGE_H__

#include <string>
#include <map>
#include <functional>
#include <memory>

/**
 * HelpBot SDK 回调函数类型
 * @param success 操作是否成功
 * @param message 成功或失败的消息
 */
using HelpBotCallback = std::function<void(bool success, const std::string& message)>;

/**
 * HelpBot SDK 事件监听器类型
 * @param eventName 事件名称
 * @param data 事件数据
 */
using HelpBotEventListener = std::function<void(const std::string& eventName, 
                                                 const std::map<std::string, std::string>& data)>;

/**
 * HelpBot SDK 配置
 */
struct HelpBotConfig {
    std::string channelId;              // 渠道 ID
    std::string domain;                 // 域名（必须 HTTPS）
    bool fullPrivacyMode;               // 完全隐私模式
    bool enableSseNotification;         // 启用 SSE 通知
    int initTimeout;                    // 初始化超时（毫秒）
    int webViewLoadTimeout;             // WebView 加载超时（毫秒）
    std::map<std::string, std::string> customConfig;  // 自定义配置
    
    HelpBotConfig() 
        : fullPrivacyMode(false)
        , enableSseNotification(true)
        , initTimeout(30000)
        , webViewLoadTimeout(15000) {}
};

/**
 * HelpBot SDK 桥接类（单例模式）
 */
class HelpBotBridge {
public:
    /**
     * 获取单例实例
     */
    static HelpBotBridge* getInstance();
    
    /**
     * 销毁单例实例
     */
    static void destroyInstance();
    
    /**
     * 初始化 HelpBot SDK
     * @param channelId 渠道 ID
     * @param domain 域名（必须以 https:// 开头）
     * @param callback 初始化回调
     */
    void install(const std::string& channelId, 
                 const std::string& domain,
                 HelpBotCallback callback = nullptr);
    
    /**
     * 初始化 HelpBot SDK（使用配置对象）
     * @param config SDK 配置
     * @param callback 初始化回调
     */
    void install(const HelpBotConfig& config, HelpBotCallback callback = nullptr);
    
    /**
     * 用户登录
     * @param jwtToken JWT 令牌
     * @param callback 登录回调
     */
    void login(const std::string& jwtToken, HelpBotCallback callback = nullptr);
    
    /**
     * 显示对话界面
     * @param callback 操作回调
     */
    void showConversation(HelpBotCallback callback = nullptr);
    
    /**
     * 显示 FAQ 列表
     * @param callback 操作回调
     */
    void showFAQs(HelpBotCallback callback = nullptr);
    
    /**
     * 显示指定 FAQ 分组
     * @param sectionId FAQ 分组 ID
     * @param callback 操作回调
     */
    void showFAQSection(const std::string& sectionId, HelpBotCallback callback = nullptr);
    
    /**
     * 显示单个 FAQ
     * @param questionId FAQ 问题 ID
     * @param callback 操作回调
     */
    void showSingleFAQ(const std::string& questionId, HelpBotCallback callback = nullptr);
    
    /**
     * 更新 SDK 元数据
     * @param sdkMeta SDK 元数据（如系统版本、设备型号等）
     */
    void updateSDKMeta(const std::map<std::string, std::string>& sdkMeta);
    
    /**
     * 更新自定义元数据
     * @param customMeta 自定义元数据（如用户等级、服务器 ID 等）
     */
    void updateCustomMeta(const std::map<std::string, std::string>& customMeta);
    
    /**
     * 添加 Issue 标签
     * @param tags 标签列表
     */
    void addIssueTags(const std::vector<std::string>& tags);
    
    /**
     * 移除 Issue 标签
     * @param tags 标签列表
     */
    void removeIssueTags(const std::vector<std::string>& tags);
    
    /**
     * 设置事件监听器
     * @param listener 事件监听器
     */
    void setEventListener(HelpBotEventListener listener);
    
    /**
     * 移除事件监听器
     */
    void removeEventListener();
    
    /**
     * 检查 SDK 是否已初始化
     * @return true 如果已初始化
     */
    bool isInitialized() const;
    
    /**
     * 检查对话界面是否可见
     * @return true 如果对话界面可见
     */
    bool isConversationVisible() const;
    
    /**
     * 获取 SDK 版本
     * @return SDK 版本字符串
     */
    std::string getSDKVersion() const;
    
    /**
     * 清理 WebView 数据
     */
    void clearWebViewData();
    
private:
    HelpBotBridge();
    ~HelpBotBridge();
    
    // 禁止拷贝和赋值
    HelpBotBridge(const HelpBotBridge&) = delete;
    HelpBotBridge& operator=(const HelpBotBridge&) = delete;
    
    // 平台特定实现
    class Impl;
    std::unique_ptr<Impl> pImpl;
    
    static HelpBotBridge* s_instance;
};

#endif // __HELPBOT_BRIDGE_H__
