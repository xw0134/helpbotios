#ifndef HELPBOT_CALLBACK_H
#define HELPBOT_CALLBACK_H

#include "HelpBotErrorCode.h"
#include "HelpBotEvent.h"
#include <string>
#include <functional>

namespace helpbot {

/**
 * SDK 初始化回调接口
 */
class HelpBotInitCallback {
public:
    virtual ~HelpBotInitCallback() = default;

    /**
     * 初始化开始
     */
    virtual void onInitStart() = 0;

    /**
     * 初始化进度更新
     * 
     * @param progress 进度百分比 (0-100)
     * @param message 进度描述信息
     */
    virtual void onInitProgress(int progress, const std::string& message) = 0;

    /**
     * 初始化成功
     */
    virtual void onInitSuccess() = 0;

    /**
     * 初始化失败
     * 
     * @param errorCode 错误码
     * @param errorMessage 错误信息
     */
    virtual void onInitFailure(HelpBotErrorCode errorCode, const std::string& errorMessage) = 0;
};

/**
 * 通用操作回调接口(泛型)
 */
template<typename T>
class HelpBotCallback {
public:
    virtual ~HelpBotCallback() = default;

    /**
     * 操作成功
     * 
     * @param result 操作结果数据
     */
    virtual void onSuccess(const T& result) = 0;

    /**
     * 操作失败
     * 
     * @param errorCode 错误码
     * @param errorMessage 错误信息
     */
    virtual void onFailure(HelpBotErrorCode errorCode, const std::string& errorMessage) = 0;
};

/**
 * Void 类型特化(用于无返回值的操作)
 */
template<>
class HelpBotCallback<void> {
public:
    virtual ~HelpBotCallback() = default;

    /**
     * 操作成功
     */
    virtual void onSuccess() = 0;

    /**
     * 操作失败
     * 
     * @param errorCode 错误码
     * @param errorMessage 错误信息
     */
    virtual void onFailure(HelpBotErrorCode errorCode, const std::string& errorMessage) = 0;
};

/**
 * SDK 事件监听器接口
 */
class HelpBotEventsListener {
public:
    virtual ~HelpBotEventsListener() = default;

    /**
     * SDK 事件发生
     * 
     * @param eventName 事件名称
     * @param data 事件数据
     */
    virtual void onEventOccurred(const std::string& eventName, const EventData& data) = 0;

    /**
     * 用户认证失败
     * 
     * @param reason 失败原因
     */
    virtual void onUserAuthenticationFailure(HelpBotAuthenticationFailureReason reason) = 0;
};

// ==================== 函数式回调(便捷使用) ====================

/**
 * 初始化回调函数类型
 */
using InitStartFunc = std::function<void()>;
using InitProgressFunc = std::function<void(int, const std::string&)>;
using InitSuccessFunc = std::function<void()>;
using InitFailureFunc = std::function<void(HelpBotErrorCode, const std::string&)>;

/**
 * 通用回调函数类型
 */
template<typename T>
using SuccessFunc = std::function<void(const T&)>;

template<>
using SuccessFunc<void> = std::function<void()>;

using FailureFunc = std::function<void(HelpBotErrorCode, const std::string&)>;

/**
 * 事件监听函数类型
 */
using EventOccurredFunc = std::function<void(const std::string&, const EventData&)>;
using AuthenticationFailureFunc = std::function<void(HelpBotAuthenticationFailureReason)>;

} // namespace helpbot

#endif // HELPBOT_CALLBACK_H
