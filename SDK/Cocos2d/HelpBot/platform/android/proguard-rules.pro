# HelpBot Cocos2d SDK ProGuard Rules

# Keep HelpBot Cocos2d Bridge
-keep class com.helpbot.sdk.cocos2d.HelpBotCocos2dBridge { *; }
-keepclassmembers class com.helpbot.sdk.cocos2d.HelpBotCocos2dBridge {
    native <methods>;
}

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep HelpBot SDK core classes (如果AAR未包含规则)
-keep class com.helpbot.sdk.** { *; }
-keep interface com.helpbot.sdk.** { *; }

# Keep callback interfaces
-keep class * implements com.helpbot.sdk.core.HelpBotInitCallback { *; }
-keep class * implements com.helpbot.sdk.core.HelpBotCallback { *; }
-keep class * implements com.helpbot.sdk.core.HelpBotEventsListener { *; }

# Keep error codes and enums
-keepclassmembers enum com.helpbot.sdk.core.** {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

# Keep line numbers for debugging
-keepattributes SourceFile,LineNumberTable
