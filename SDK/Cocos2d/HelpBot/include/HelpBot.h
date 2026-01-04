#ifndef HELPBOT_H
#define HELPBOT_H

#include "HelpBotConfig.h"
#include "HelpBotCallback.h"
#include "HelpBotResult.h"
#include "HelpBotEvent.h"
#include <string>
#include <vector>
#include <map>
#include <memory>

namespace helpbot {

/**
 * HelpBot SDK 主入口类
 * 
 * 提供所有公共 API,与 Android SDK 完全对齐
 * 
 * 设计要点:
 * 1. 仅提供异步 API(避免阻塞调用线程)
 * 2. 统一错误码与回调机制
 * 3. 线程安全与资源生命周期管理
 * 
 * 使用示例:
 * ```cpp
 * // 1. 初始化
 * HelpBotConfig config = HelpBotConfig::Builder()
 *     .channelId("your_channel_id")
 *     .domain("https://your-domain.com")
 *     .build();
 * 
 * HelpBot::install(config, callback);
 * 
 * // 2. 登录
 * HelpBot::login("your_jwt_token", nullptr, callback);
 * 
 * // 3. 显示对话界面
 * HelpBot::showConversation();
 * ```
 */
class HelpBot {
public:
    // ==================== 初始化相关 ====================

    /**
     * 初始化 HelpBot SDK(异步)
     * 
     * @param config SDK 配置(必须)
     * @param callback 初始化回调(可选,建议提供)
     */
    static void install(const HelpBotConfig& config, HelpBotInitCallback* callback = nullptr);

    /**
     * 初始化 HelpBot SDK(兼容需求文档签名)
     * 
     * @param channelId 渠道 ID(必填)
     * @param domain 业务域名(必填,必须 https)
     * @param configMap 配置 Map(可选)
     * @param callback 初始化回调(可选)
     */
    static void install(
        const std::string& channelId,
        const std::string& domain,
        const std::map<std::string, std::string>* configMap = nullptr,
        HelpBotInitCallback* callback = nullptr
    );

    /**
     * 检查 SDK 是否已初始化
     */
    static bool isInitialized();

    /**
     * 获取 SDK 版本号
     */
    static std::string getSDKVersion();

    // ==================== 登录相关 ====================

    /**
     * 用户登录(异步)
     * 
     * @param identitiesJWT WebSDK 预生成 Token(必须)
     * @param loginConfig 登录配置(可选)
     * @param callback 登录回调(可选)
     */
    static void login(
        const std::string& identitiesJWT,
        const std::map<std::string, std::string>* loginConfig = nullptr,
        HelpBotCallback<void>* callback = nullptr
    );

    /**
     * 用户登出
     */
    static HelpBotResult<void> logout();

    // ==================== UI 相关 ====================

    /**
     * 显示对话界面
     * 
     * @return 操作结果
     */
    static HelpBotResult<void> showConversation();

    /**
     * 显示对话界面（兼容 Android 签名：允许透传 configMap，但当前与 showConversation() 行为保持一致）
     *
     * @param configMap 可选配置（保留以对齐 Android；具体支持字段以 Android SDK 为准）
     * @return 操作结果
     */
    static HelpBotResult<void> showConversation(const std::map<std::string, std::string>* configMap);

    /**
     * 隐藏对话界面
     * 
     * @return 操作结果
     */
    static HelpBotResult<void> hideConversation();

    /**
     * 检查对话界面是否可见
     */
    static bool isConversationVisible();

    /**
     * 显示 FAQ 列表
     * 
     * @return 操作结果
     */
    static HelpBotResult<void> showFAQs();

    /**
     * 显示 FAQ 列表（带配置）
     *
     * @param configMap 配置 Map（可选）
     * @return 操作结果
     */
    static HelpBotResult<void> showFAQs(const std::map<std::string, std::string>* configMap);

    /**
     * 显示指定 FAQ 分类
     * 
     * @param sectionId 分类 ID
     * @return 操作结果
     */
    static HelpBotResult<void> showFAQSection(const std::string& sectionId);

    /**
     * 显示指定 FAQ 分类（带配置）
     *
     * @param sectionId 分类 ID
     * @param configMap 配置 Map（可选）
     * @return 操作结果
     */
    static HelpBotResult<void> showFAQSection(const std::string& sectionId,
                                             const std::map<std::string, std::string>* configMap);

    /**
     * 显示单个 FAQ 问题
     * 
     * @param questionId 问题 ID
     * @return 操作结果
     */
    static HelpBotResult<void> showSingleFAQ(const std::string& questionId);

    /**
     * 显示单个 FAQ（带配置）
     *
     * @param questionId 问题 ID
     * @param configMap 配置 Map（可选）
     * @return 操作结果
     */
    static HelpBotResult<void> showSingleFAQ(const std::string& questionId,
                                            const std::map<std::string, std::string>* configMap);

    // ==================== 数据更新相关 ====================

    /**
     * 更新 SDK 元数据
     * 
     * @param sdkMeta SDK 元数据
     * @return 操作结果
     */
    static HelpBotResult<void> updateSDKMeta(const std::map<std::string, std::string>& sdkMeta);

    /**
     * 更新自定义元数据
     * 
     * @param customMeta 自定义元数据
     * @return 操作结果
     */
    static HelpBotResult<void> updateCustomMeta(const std::map<std::string, std::string>& customMeta);

    /**
     * 添加问题标签
     * 
     * @param tags 标签列表
     * @return 操作结果
     */
    static HelpBotResult<void> addIssueTags(const std::vector<std::string>& tags);

    /**
     * 移除问题标签
     * 
     * @param tags 标签列表
     * @return 操作结果
     */
    static HelpBotResult<void> removeIssueTags(const std::vector<std::string>& tags);

    /**
     * 上报系统信息到服务器
     * 
     * @return 操作结果
     */
    static HelpBotResult<void> reportSystemInfoToServer();

    // ==================== WebSDK 命令（异步返回 JSON） ====================

    /**
     * 发送文本消息（异步）。
     *
     * 对齐 Android：HelpBot.sendMessageAsync(message, callback)
     *
     * 注意：成功回调返回的是 JSON 字符串（用于保真承载 Map<String,Object>）。
     */
    static void sendMessageAsync(const std::string& message,
                                 HelpBotCallback<std::string>* callback = nullptr);

    /**
     * 获取历史消息（异步）。
     *
     * 对齐 Android：HelpBot.getHistoryMessagesAsync(callback)
     *
     * 注意：成功回调返回的是 JSON 字符串。
     */
    static void getHistoryMessagesAsync(HelpBotCallback<std::string>* callback = nullptr);

    /**
     * 分页加载更多历史消息（异步）。
     *
     * 对齐 Android：HelpBot.loadMoreMessagesAsync(limit, offset, callback)
     *
     * 注意：成功回调返回的是 JSON 字符串。
     */
    static void loadMoreMessagesAsync(int limit, int offset,
                                      HelpBotCallback<std::string>* callback = nullptr);

    // ==================== 事件监听 ====================

    /**
     * 设置事件监听器
     * 
     * @param listener 事件监听器(SDK 不持有所有权,调用方需保证生命周期)
     */
    static void setHelpBotEventsListener(HelpBotEventsListener* listener);

    /**
     * 移除事件监听器
     */
    static void removeHelpBotEventsListener();

    // ==================== 通知相关 ====================

    /**
     * 启用 SSE 通知（兼容旧 API）
     */
    static void enableSseNotification();

    /**
     * 禁用 SSE 通知（兼容旧 API）
     */
    static void disableSseNotification();

    /**
     * SSE 通知开关（对齐 Android：enableSseNotification(boolean)）
     */
    static void enableSseNotification(bool enable);

    /**
     * 查询 SSE 通知开关（对齐 Android：isSseNotificationEnabled()）
     */
    static bool isSseNotificationEnabled();

    /**
     * 设置通知小图标资源 id（对齐 Android：setNotificationSmallIconResId）
     */
    static void setNotificationSmallIconResId(int resId);

    /**
     * 设置通知渠道 id（对齐 Android：setNotificationChannelId）
     */
    static void setNotificationChannelId(const std::string& channelId);

    /**
     * 获取未读消息数
     */
    static int getUnreadCount();

    // ==================== 会话/状态相关 ====================

    /**
     * 关闭会话（对齐 Android：closeSession）
     */
    static HelpBotResult<void> closeSession();

    /**
     * 获取 WebSDK 健康快照（对齐 Android：getWebSdkHealthSnapshot）
     *
     * @return JSON 字符串（空对象返回 "{}"）
     */
    static std::string getWebSdkHealthSnapshotJson();

    /**
     * 从 Web 侧确认登录完成（对齐 Android：markLoginConfirmedFromWeb）
     */
    static void markLoginConfirmedFromWeb();

    /**
     * 获取/消费 pendingLoginToken（对齐 Android：getPendingLoginToken/consumePendingLoginToken）
     */
    static std::string getPendingLoginToken();
    static std::string consumePendingLoginToken();

    // ==================== 资源管理 ====================

    /**
     * 清理 WebView 数据
     * 
     * @return 操作结果
     */
    static HelpBotResult<void> clearWebViewData();

    /**
     * 销毁 SDK(释放所有资源)
     * 
     * 注意:销毁后需要重新 install 才能使用
     */
    static void destroy();

private:
    // 禁止实例化
    HelpBot() = delete;
    ~HelpBot() = delete;
    HelpBot(const HelpBot&) = delete;
    HelpBot& operator=(const HelpBot&) = delete;
};

} // namespace helpbot

#endif // HELPBOT_H
