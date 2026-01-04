#ifndef HELPBOT_EVENT_H
#define HELPBOT_EVENT_H

#include <string>
#include <map>

namespace helpbot {

/**
 * 认证失败原因枚举
 */
enum class HelpBotAuthenticationFailureReason {
    TOKEN_EXPIRED,           // Token过期
    TOKEN_INVALID,           // Token无效
    NETWORK_ERROR,           // 网络错误
    SERVER_ERROR,            // 服务器错误
    UNKNOWN                  // 未知原因
};

/**
 * 获取认证失败原因的字符串描述
 */
inline std::string getAuthenticationFailureReasonString(HelpBotAuthenticationFailureReason reason) {
    switch (reason) {
        case HelpBotAuthenticationFailureReason::TOKEN_EXPIRED:
            return "TOKEN_EXPIRED";
        case HelpBotAuthenticationFailureReason::TOKEN_INVALID:
            return "TOKEN_INVALID";
        case HelpBotAuthenticationFailureReason::NETWORK_ERROR:
            return "NETWORK_ERROR";
        case HelpBotAuthenticationFailureReason::SERVER_ERROR:
            return "SERVER_ERROR";
        case HelpBotAuthenticationFailureReason::UNKNOWN:
        default:
            return "UNKNOWN";
    }
}

/**
 * 事件数据类型(支持常见类型)
 */
class EventValue {
public:
    enum Type {
        TYPE_NULL,
        TYPE_BOOL,
        TYPE_INT,
        TYPE_DOUBLE,
        TYPE_STRING
    };

    EventValue() : m_type(TYPE_NULL), m_intValue(0) {}
    EventValue(bool value) : m_type(TYPE_BOOL), m_intValue(value ? 1 : 0) {}
    EventValue(int value) : m_type(TYPE_INT), m_intValue(value) {}
    EventValue(double value) : m_type(TYPE_DOUBLE), m_doubleValue(value) {}
    EventValue(const std::string& value) : m_type(TYPE_STRING), m_stringValue(value) {}
    EventValue(const char* value) : m_type(TYPE_STRING), m_stringValue(value) {}

    Type getType() const { return m_type; }
    bool asBool() const { return m_intValue != 0; }
    int asInt() const { return m_intValue; }
    double asDouble() const { return m_type == TYPE_DOUBLE ? m_doubleValue : static_cast<double>(m_intValue); }
    std::string asString() const { return m_stringValue; }

private:
    Type m_type;
    int m_intValue;
    double m_doubleValue;
    std::string m_stringValue;
};

/**
 * 事件数据Map
 */
using EventData = std::map<std::string, EventValue>;

} // namespace helpbot

#endif // HELPBOT_EVENT_H
