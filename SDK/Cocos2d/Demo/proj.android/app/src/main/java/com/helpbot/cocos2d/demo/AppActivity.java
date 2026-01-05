package com.helpbot.cocos2d.demo;

import android.os.Bundle;
import android.util.Log;
import androidx.appcompat.app.AppCompatActivity;

/**
 * HelpBot Cocos2d Demo 主 Activity
 * 
 * 用于测试 HelpBot SDK 的 Cocos2d-x 集成
 */
public class AppActivity extends AppCompatActivity {
    
    private static final String TAG = "HelpBotCocos2dDemo";
    
    static {
        // 加载 Native 库
        System.loadLibrary("cocos2dcpp");
        Log.d(TAG, "Native library loaded successfully");
    }
    
    // Native 方法声明
    public native String getSDKVersion();
    public native boolean isSDKInitialized();
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        Log.d(TAG, "=== HelpBot Cocos2d Demo Started ===");
        
        // 测试 Native 调用
        try {
            String version = getSDKVersion();
            boolean initialized = isSDKInitialized();
            
            Log.d(TAG, "HelpBot SDK Version: " + version);
            Log.d(TAG, "HelpBot SDK Initialized: " + initialized);
        } catch (Exception e) {
            Log.e(TAG, "Error calling native methods", e);
        }
        
        // 显示简单的文本视图用于测试
        android.widget.TextView textView = new android.widget.TextView(this);
        textView.setText("HelpBot Cocos2d Demo\n\n" +
                "Check logcat for SDK information:\n" +
                "adb logcat | grep HelpBotCocos2dDemo");
        textView.setPadding(50, 50, 50, 50);
        textView.setTextSize(16);
        setContentView(textView);
    }
    
    @Override
    public void onBackPressed() {
        // 处理返回键
        super.onBackPressed();
    }
}
