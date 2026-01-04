#ifndef HELPBOT_JNI_H
#define HELPBOT_JNI_H

#include <jni.h>
#include "../include/HelpBot.h"
#include "../include/HelpBotCallback.h"
#include <memory>
#include <mutex>

namespace helpbot {
namespace platform {
namespace android {

/**
 * JNI 工具类
 * 
 * 提供 JNI 常用功能的封装
 */
class JNIHelper {
public:
    /**
     * 初始化 JNI 环境(在 JNI_OnLoad 中调用)
     */
    static void init(JavaVM* vm);

    /**
     * 初始化 App ClassLoader（用于解决 native 线程 FindClass 失败问题）。
     *
     * 建议由 Java 侧在 App 启动时调用一次：HelpBotCocos2dBridge.initNativeClassLoader()
     */
    static void initClassLoader(JNIEnv* env, jobject classLoader);

    /**
     * 获取 JNIEnv(自动处理线程 attach/detach)
     */
    static JNIEnv* getEnv();

    /**
     * 获取 JNIEnv，并告知本次是否发生了 attach（调用方可在结束时 detach）。
     */
    static JNIEnv* getEnv(bool* didAttach);

    /**
     * 若 didAttach=true，则 detach 当前线程。
     */
    static void detachCurrentThreadIfNeeded(bool didAttach);

    /**
     * 获取 JavaVM
     */
    static JavaVM* getJavaVM();

    /**
     * 查找 class（优先使用 App ClassLoader）。
     *
     * @param className 兼容 "com/example/xxx" 或 "com.example.xxx"
     */
    static jclass findClass(JNIEnv* env, const char* className);

    /**
     * jstring 转 std::string
     */
    static std::string jstringToString(JNIEnv* env, jstring jstr);

    /**
     * std::string 转 jstring
     */
    static jstring stringToJstring(JNIEnv* env, const std::string& str);

    /**
     * jobject (Map) 转 std::map<std::string, std::string>
     */
    static std::map<std::string, std::string> jmapToMap(JNIEnv* env, jobject jmap);

    /**
     * std::map 转 jobject (HashMap)
     */
    static jobject mapToJmap(JNIEnv* env, const std::map<std::string, std::string>& map);

    /**
     * jobject (List) 转 std::vector<std::string>
     */
    static std::vector<std::string> jlistToVector(JNIEnv* env, jobject jlist);

    /**
     * std::vector 转 jobject (ArrayList)
     */
    static jobject vectorToJlist(JNIEnv* env, const std::vector<std::string>& vec);

    /**
     * 检查并清除 JNI 异常
     */
    static bool checkAndClearException(JNIEnv* env);

private:
    static JavaVM* s_javaVM;
    static std::mutex s_mutex;

    // App ClassLoader（用于 native 线程加载 App 内 class）
    static jobject s_classLoader;      // GlobalRef
    static jmethodID s_loadClassMethod;
};

} // namespace android
} // namespace platform
} // namespace helpbot

#endif // HELPBOT_JNI_H
