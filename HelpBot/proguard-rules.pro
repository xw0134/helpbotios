# HelpBot SDK ProGuard 混淆规则
# 用于保护SDK代码安全，防止逆向工程

# ==================== 基础配置 ====================
# 保留源文件名和行号信息，便于调试崩溃堆栈
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# ==================== SDK公共API保护 ====================
# 保留HelpBot主入口类的所有公共方法(SDK对外API)
-keep public class com.example.HelpBot.HelpBot {
    public *;
    # 保留内部使用的包级方法（供HelpBotActivity调用）
    static void setCurrentActivity(...);
    static void clearCurrentActivity();
    public static java.lang.String getPendingLoginToken();
    public static synchronized java.lang.String consumePendingLoginToken();
}

# 保留所有回调接口（宿主应用需要实现）
-keep public interface com.example.HelpBot.core.HelpBotCallback { *; }
-keep public interface com.example.HelpBot.core.HelpBotInitCallback { *; }
-keep public interface com.example.HelpBot.core.HelpBotEventsListener { *; }
-keep public interface com.example.HelpBot.core.HelpBotUserLoginEventsListener { *; }

# 保留错误码枚举
-keep public enum com.example.HelpBot.core.HelpBotErrorCode {
    public *;
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# 保留配置类（Builder模式）
-keep public class com.example.HelpBot.core.HelpBotConfig {
    public *;
}
-keep public class com.example.HelpBot.core.HelpBotConfig$Builder {
    public *;
}

# 保留结果封装类
-keep public class com.example.HelpBot.core.HelpBotResult {
    public *;
}

# 保留认证失败原因枚举
-keep public class com.example.HelpBot.core.HelpBotAuthenticationFailureReason { *; }

# 保留事件类
-keep public class com.example.HelpBot.core.HelpBotEvent { *; }

# ==================== JavascriptInterface保护 ====================
# 关键:保护所有@JavascriptInterface注解的方法,防止WebView调用失败
-keepclassmembers class com.example.HelpBot.chat.ChatToNativeBridge {
    @android.webkit.JavascriptInterface public *;
}

# 保留WebView相关的JavaScript接口
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# ==================== Activity保护 ====================
# 保留HelpBotActivity,防止Intent启动失败
-keep public class com.example.HelpBot.activity.HelpBotActivity {
    public <init>(...);
    # webView 已改为 package-private，不需要在 ProGuard 中保留
}

# ==================== 序列化和反射保护 ====================
# 保留Serializable类的必要方法
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ==================== 枚举类保护 ====================
# 保留枚举类的values()和valueOf()方法
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ==================== 异常处理 ====================
# 保留异常类,便于调试
-keep public class * extends java.lang.Exception

# ==================== 日志优化 ====================
# 移除Log.d和Log.v调用,减小包体积(保留Log.e和Log.w)
-assumenosideeffects class android.util.Log {
    public static int d(...);
    public static int v(...);
}

# 移除 HBlogger 的低级别日志（保留 warn/error，便于线上排障）
-assumenosideeffects class com.example.HelpBot.log.HBlogger {
    public static void d(...);
    public static void v(...);
}

# ==================== AndroidX和第三方库 ====================
# AndroidX
-keep class androidx.** { *; }
-dontwarn androidx.**

# ==================== WebView相关 ====================
# 保留WebView相关类
-keep class android.webkit.** { *; }
-dontwarn android.webkit.**

# 保留WebChromeClient和WebViewClient
-keep class * extends android.webkit.WebChromeClient { *; }
-keep class * extends android.webkit.WebViewClient { *; }

# ==================== 加密存储相关 ====================
# 保留加密存储类（使用反射）
-keep class com.example.HelpBot.storage.EncryptedStorage {
    public *;
}

# 保留KeyStore相关
-keep class javax.crypto.** { *; }
-keep class java.security.** { *; }
-dontwarn javax.crypto.**
-dontwarn java.security.**

# ==================== JSON相关 ====================
# 保留JSON类（可能被反射使用）
-keepclassmembers class * {
    @org.json.** *;
}
-keep class org.json.** { *; }

# ==================== 优化配置 ====================
# 启用优化
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify

# ==================== 混淆配置 ====================
# 不混淆包名(保持SDK包结构清晰)
-keeppackagenames com.example.HelpBot

# 重命名源文件名
-renamesourcefileattribute SourceFile

# ==================== 警告处理 ====================
# 忽略警告(谨慎使用)
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# ==================== 移除未使用代码 ====================
# 移除未使用的类和方法
-dontshrink  # SDK不移除代码，由宿主控制

# ==================== 内部类保护 ====================
# 保留内部类的外部类引用
-keepattributes InnerClasses

# ==================== Parcelable保护 ====================
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}



# ==================== 自定义规则 ====================
# 保留HelpBotContext（单例模式）
-keep class com.example.HelpBot.core.HelpBotContext {
    public *;
    public static ** getInstance();
    public static synchronized void initInstance(...);
    public static synchronized void destroy();
}

# 保留Device接口
-keep interface com.example.HelpBot.core.Device { *; }
-keep class com.example.HelpBot.core.AndroidDevice { *; }

# 保留日志接口
-keep interface com.example.HelpBot.log.IHBLogger { *; }
-keep class com.example.HelpBot.log.HBlogger { *; }
-keep class com.example.HelpBot.log.HelpBotLogger { *; }

# 保留线程池
-keep class com.example.HelpBot.thread.HelpBotThreadPool {
    public *;
    public static ** getInstance();
}

# 保留WebView会话管理
-keep class com.example.HelpBot.web.HelpBotWebViewSession {
    public *;
    public static ** getInstance();
}

# ==================== 通知相关 ====================
-keep class com.example.HelpBot.notification.** { *; }

# ==================== 存储相关 ====================
-keep class com.example.HelpBot.storage.** { *; }

# ==================== 工具类 ====================
-keep class com.example.HelpBot.utils.** { *; }

# ==================== 配置管理 ====================
-keep class com.example.HelpBot.config.** { *; }

# ==================== 用户管理 ====================
-keep class com.example.HelpBot.user.** { *; }

# ==================== 聊天相关 ====================
-keep class com.example.HelpBot.chat.** { *; }

# ==================== Web相关 ====================
-keep class com.example.HelpBot.web.** { *; }