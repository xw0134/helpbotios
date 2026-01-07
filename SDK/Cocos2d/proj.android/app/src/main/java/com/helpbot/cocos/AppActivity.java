package com.helpbot.cocos;

import android.os.Bundle;
import org.cocos2dx.lib.Cocos2dxActivity;

/**
 * AppActivity - Cocos2d-x 主 Activity
 * 
 * 继承自 Cocos2dxActivity,提供 Cocos2d-x 运行环境
 * HelpBot SDK 通过 JNI 桥接在 C++ 层调用
 */
public class AppActivity extends Cocos2dxActivity {
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.setEnableVirtualButton(false);
        super.onCreate(savedInstanceState);
        
        // Cocos2d-x 会自动加载 C++ 库和初始化
        // HelpBot SDK 在 C++ 层通过 HelpBotBridge 初始化
    }
}
