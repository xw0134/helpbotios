#ifndef HELPBOT_BRIDGE_H
#define HELPBOT_BRIDGE_H

#import <Foundation/Foundation.h>
#include "../../include/HelpBot.h"
#include "../../include/HelpBotCallback.h"

namespace helpbot {
namespace platform {
namespace ios {

/**
 * iOS 平台 HelpBot 桥接类
 * 
 * 通过 Objective-C++ 调用 iOS SDK
 */
class HelpBotBridge {
public:
    /**
     * 初始化 SDK
     */
    static void install(const HelpBotConfig& config, HelpBotInitCallback* callback);

    /**
     * 用户登录
     */
    static void login(const std::string& token,
                     const std::map<std::string, std::string>* loginConfig,
                     HelpBotCallback<void>* callback);

    /**
     * 显示对话界面
     */
    static HelpBotResult<void> showConversation();

    /**
     * 隐藏对话界面
     */
    static HelpBotResult<void> hideConversation();

    /**
     * 检查是否已初始化
     */
    static bool isInitialized();

    /**
     * 检查对话界面是否可见
     */
    static bool isConversationVisible();

    /**
     * 获取 SDK 版本
     */
    static std::string getSDKVersion();

    /**
     * 显示 FAQ 列表
     */
    static HelpBotResult<void> showFAQs();

    /**
     * 显示 FAQ 分类
     */
    static HelpBotResult<void> showFAQSection(const std::string& sectionId);

    /**
     * 显示单个 FAQ
     */
    static HelpBotResult<void> showSingleFAQ(const std::string& questionId);

    /**
     * 更新 SDK 元数据
     */
    static HelpBotResult<void> updateSDKMeta(const std::map<std::string, std::string>& sdkMeta);

    /**
     * 更新自定义元数据
     */
    static HelpBotResult<void> updateCustomMeta(const std::map<std::string, std::string>& customMeta);

    /**
     * 添加问题标签
     */
    static HelpBotResult<void> addIssueTags(const std::vector<std::string>& tags);

    /**
     * 移除问题标签
     */
    static HelpBotResult<void> removeIssueTags(const std::vector<std::string>& tags);

    /**
     * 设置事件监听器
     */
    static void setHelpBotEventsListener(HelpBotEventsListener* listener);

    /**
     * 销毁 SDK
     */
    static void destroy();
};

} // namespace ios
} // namespace platform
} // namespace helpbot

#endif // HELPBOT_BRIDGE_H
