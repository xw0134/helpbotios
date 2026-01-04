#ifndef HBLOGGER_H
#define HBLOGGER_H

#include <string>
#include <cstdarg>

namespace helpbot {

/**
 * 日志级别
 */
enum class LogLevel {
    DEBUG = 0,
    INFO = 1,
    WARNING = 2,
    ERROR = 3,
    NONE = 4  // 禁用日志
};

/**
 * HelpBot 统一日志系统
 * 
 * 提供统一的日志输出接口,支持敏感信息脱敏
 */
class HBLogger {
public:
    /**
     * 设置日志级别
     */
    static void setLogLevel(LogLevel level);

    /**
     * 获取当前日志级别
     */
    static LogLevel getLogLevel();

    /**
     * Debug 日志
     */
    static void d(const std::string& tag, const std::string& message);

    /**
     * Info 日志
     */
    static void i(const std::string& tag, const std::string& message);

    /**
     * Warning 日志
     */
    static void w(const std::string& tag, const std::string& message);

    /**
     * Error 日志
     */
    static void e(const std::string& tag, const std::string& message);

    /**
     * 敏感信息脱敏(用于 Token 等)
     * 
     * 规则:保留前6位和后4位,中间用 *** 替代
     */
    static std::string sanitizeValue(const std::string& value);

private:
    static LogLevel s_logLevel;
    static void log(LogLevel level, const std::string& tag, const std::string& message);
};

} // namespace helpbot

#endif // HBLOGGER_H
