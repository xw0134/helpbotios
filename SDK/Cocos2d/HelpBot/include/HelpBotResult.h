#ifndef HELPBOT_RESULT_H
#define HELPBOT_RESULT_H

#include "HelpBotErrorCode.h"
#include <string>
#include <memory>

namespace helpbot {

/**
 * HelpBot SDK 操作结果封装类
 * 
 * 用于封装同步操作的返回结果,包含成功/失败状态、错误码和数据
 */
template<typename T>
class HelpBotResult {
public:
    /**
     * 创建成功结果
     */
    static HelpBotResult<T> success(const T& data) {
        HelpBotResult<T> result;
        result.m_success = true;
        result.m_data = std::make_shared<T>(data);
        return result;
    }

    /**
     * 创建成功结果(无数据)
     */
    static HelpBotResult<T> success() {
        HelpBotResult<T> result;
        result.m_success = true;
        return result;
    }

    /**
     * 创建失败结果
     */
    static HelpBotResult<T> failure(HelpBotErrorCode errorCode, const std::string& errorMessage) {
        HelpBotResult<T> result;
        result.m_success = false;
        result.m_errorCode = errorCode;
        result.m_errorMessage = errorMessage;
        return result;
    }

    /**
     * 创建失败结果(使用默认错误信息)
     */
    static HelpBotResult<T> failure(HelpBotErrorCode errorCode) {
        return failure(errorCode, getErrorMessage(errorCode));
    }

    /**
     * 判断操作是否成功
     */
    bool isSuccess() const {
        return m_success;
    }

    /**
     * 判断操作是否失败
     */
    bool isFailure() const {
        return !m_success;
    }

    /**
     * 获取错误码
     */
    HelpBotErrorCode getErrorCode() const {
        return m_errorCode;
    }

    /**
     * 获取错误信息
     */
    std::string getErrorMessage() const {
        return m_errorMessage;
    }

    /**
     * 获取数据(如果有)
     */
    std::shared_ptr<T> getData() const {
        return m_data;
    }

    /**
     * 获取数据引用(如果没有数据会抛出异常)
     */
    const T& getDataRef() const {
        if (!m_data) {
            throw std::runtime_error("Result has no data");
        }
        return *m_data;
    }

private:
    HelpBotResult() 
        : m_success(false)
        , m_errorCode(HelpBotErrorCode::UNKNOWN_ERROR)
        , m_errorMessage("")
        , m_data(nullptr) {
    }

    bool m_success;
    HelpBotErrorCode m_errorCode;
    std::string m_errorMessage;
    std::shared_ptr<T> m_data;
};

/**
 * Void 类型特化(用于无返回值的操作)
 */
template<>
class HelpBotResult<void> {
public:
    static HelpBotResult<void> success() {
        HelpBotResult<void> result;
        result.m_success = true;
        return result;
    }

    static HelpBotResult<void> failure(HelpBotErrorCode errorCode, const std::string& errorMessage) {
        HelpBotResult<void> result;
        result.m_success = false;
        result.m_errorCode = errorCode;
        result.m_errorMessage = errorMessage;
        return result;
    }

    static HelpBotResult<void> failure(HelpBotErrorCode errorCode) {
        return failure(errorCode, getErrorMessage(errorCode));
    }

    bool isSuccess() const {
        return m_success;
    }

    bool isFailure() const {
        return !m_success;
    }

    HelpBotErrorCode getErrorCode() const {
        return m_errorCode;
    }

    std::string getErrorMessage() const {
        return m_errorMessage;
    }

private:
    HelpBotResult() 
        : m_success(false)
        , m_errorCode(HelpBotErrorCode::UNKNOWN_ERROR)
        , m_errorMessage("") {
    }

    bool m_success;
    HelpBotErrorCode m_errorCode;
    std::string m_errorMessage;
};

} // namespace helpbot

#endif // HELPBOT_RESULT_H
