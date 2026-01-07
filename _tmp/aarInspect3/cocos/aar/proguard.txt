## HelpBot SDK - consumer proguard rules
## 说明：
## - WebView 的 JSBridge 通过方法名反射调用（@JavascriptInterface）。
## - 宿主 App 开启 R8/混淆时，若方法名被重命名会导致 JS 调用失败。
## - 这些规则会自动应用到使用此SDK的宿主应用中

# ==================== JavascriptInterface保护 ====================
# 保留所有 @JavascriptInterface 标注的方法名
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# 额外保守：保留 JSBridge 类本身（避免被错误优化）
-keep class com.example.HelpBot.chat.ChatToNativeBridge { *; }

# ==================== SDK公共API保护 ====================
# 保留HelpBot主入口类的所有公共方法(SDK对外API)
-keep public class com.example.HelpBot.HelpBot {
    public *;
}

# 保留所有回调接口(宿主应用需要实现)
-keep public interface com.example.HelpBot.core.HelpBotCallback { *; }
-keep public interface com.example.HelpBot.core.HelpBotInitCallback { *; }
-keep public interface com.example.HelpBot.core.HelpBotEventsListener { *; }
-keep public interface com.example.HelpBot.core.HelpBotUserLoginEventsListener { *; }

# 保留回调接口中使用的类型
-keep public enum com.example.HelpBot.core.HelpBotErrorCode {
    public *;
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
-keep public class com.example.HelpBot.core.HelpBotAuthenticationFailureReason { *; }
-keep public class com.example.HelpBot.core.HelpBotEvent { *; }

# 保留配置类(宿主应用需要使用Builder构建)
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

# ==================== Activity保护 ====================
# 保留HelpBotActivity,防止Intent启动失败
-keep public class com.example.HelpBot.activity.HelpBotActivity { *; }

# ==================== 注解保护 ====================
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes SourceFile,LineNumberTable
