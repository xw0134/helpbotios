-dontwarn com.example.HelpBot.**
-keep class com.example.HelpBot.** { *; }
-keep interface com.example.HelpBot.** { *; }

# Keep WebView related classes
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
