#include "HBLogger.h"
#include <iostream>
#include <sstream>
#include <ctime>

#if defined(__ANDROID__)
#include <android/log.h>
#define LOG_TAG "HelpBot"
#endif

namespace helpbot {

// 静态成员初始化
LogLevel HBLogger::s_logLevel = LogLevel::DEBUG;

void HBLogger::setLogLevel(LogLevel level) {
    s_logLevel = level;
}

LogLevel HBLogger::getLogLevel() {
    return s_logLevel;
}

void HBLogger::d(const std::string& tag, const std::string& message) {
    log(LogLevel::DEBUG, tag, message);
}

void HBLogger::i(const std::string& tag, const std::string& message) {
    log(LogLevel::INFO, tag, message);
}

void HBLogger::w(const std::string& tag, const std::string& message) {
    log(LogLevel::WARNING, tag, message);
}

void HBLogger::e(const std::string& tag, const std::string& message) {
    log(LogLevel::ERROR, tag, message);
}

std::string HBLogger::sanitizeValue(const std::string& value) {
    if (value.empty()) {
        return "";
    }

    const size_t len = value.length();
    
    // 如果长度小于等于10,全部脱敏
    if (len <= 10) {
        return "***";
    }

    // 保留前6位和后4位,中间用 *** 替代
    const size_t prefixLen = 6;
    const size_t suffixLen = 4;
    
    std::string prefix = value.substr(0, prefixLen);
    std::string suffix = value.substr(len - suffixLen);
    
    return prefix + "***" + suffix;
}

void HBLogger::log(LogLevel level, const std::string& tag, const std::string& message) {
    // 检查日志级别
    if (level < s_logLevel) {
        return;
    }

    // 获取当前时间
    time_t now = time(nullptr);
    char timeStr[32];
    strftime(timeStr, sizeof(timeStr), "%Y-%m-%d %H:%M:%S", localtime(&now));

    // 级别字符串
    const char* levelStr = "";
    switch (level) {
        case LogLevel::DEBUG:   levelStr = "D"; break;
        case LogLevel::INFO:    levelStr = "I"; break;
        case LogLevel::WARNING: levelStr = "W"; break;
        case LogLevel::ERROR:   levelStr = "E"; break;
        default:                levelStr = "?"; break;
    }

    // 格式化日志
    std::ostringstream oss;
    oss << timeStr << " " << levelStr << "/" << tag << ": " << message;
    std::string logMsg = oss.str();

#if defined(__ANDROID__)
    // Android 平台使用 __android_log_print
    int androidPriority;
    switch (level) {
        case LogLevel::DEBUG:   androidPriority = ANDROID_LOG_DEBUG; break;
        case LogLevel::INFO:    androidPriority = ANDROID_LOG_INFO; break;
        case LogLevel::WARNING: androidPriority = ANDROID_LOG_WARN; break;
        case LogLevel::ERROR:   androidPriority = ANDROID_LOG_ERROR; break;
        default:                androidPriority = ANDROID_LOG_VERBOSE; break;
    }
    __android_log_print(androidPriority, LOG_TAG, "%s", logMsg.c_str());
#elif defined(__APPLE__)
    // iOS 平台使用 NSLog (需要在 .mm 文件中实现)
    std::cout << logMsg << std::endl;
#else
    // 其他平台使用标准输出
    std::cout << logMsg << std::endl;
#endif
}

} // namespace helpbot
