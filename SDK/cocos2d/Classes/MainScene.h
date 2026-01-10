/**
 * MainScene.h
 * HelpBot Demo 主场景
 * 
 * 实现与 Android Demo 相同的功能界面
 */

#ifndef __MAIN_SCENE_H__
#define __MAIN_SCENE_H__

#include "cocos2d.h"
#include "ui/CocosGUI.h"
#include "network/HttpClient.h"
#include "HelpBotBridge.h"

class MainScene : public cocos2d::Scene
{
public:
    static cocos2d::Scene* createScene();

    virtual bool init();
    
    // 实现 "create()" 方法
    CREATE_FUNC(MainScene);

private:
    // UI 组件
    cocos2d::ui::TextField* editChannelId;
    cocos2d::ui::TextField* editDomain;
    cocos2d::ui::TextField* editTokenUrl;
    cocos2d::ui::TextField* editIdentifier;
    cocos2d::ui::TextField* editValue;
    
    cocos2d::ui::Text* textToken;
    cocos2d::ui::Text* textStatus;
    cocos2d::ui::Text* textLog;
    
    cocos2d::ui::ScrollView* scrollViewLog;
    
    // 状态
    std::string rawToken;
    std::string logBuffer;
    
    // 压力测试状态
    bool stressTestRunning = false;
    int stressLoopCount = 0;
    int stressSuccessCount = 0;
    int stressFailureCount = 0;
    
    // UI 创建方法
    void createUI();
    void createInputFields();
    void createButtons();
    void createStatusArea();
    void createLogArea();
    
    // 按钮回调
    void onInstallClicked(cocos2d::Ref* sender);
    void onGenerateTokenClicked(cocos2d::Ref* sender);
    void onLoginClicked(cocos2d::Ref* sender);
    void onShowConversationClicked(cocos2d::Ref* sender);
    void onShowFAQsClicked(cocos2d::Ref* sender);
    void onUpdateMetaClicked(cocos2d::Ref* sender);
    void onClearLogClicked(cocos2d::Ref* sender);
    void onCopyTokenClicked(cocos2d::Ref* sender);
    
    // 高级功能回调
    void onSelfCheckClicked(cocos2d::Ref* sender);
    void onStressTestStartClicked(cocos2d::Ref* sender);
    void onStressTestStopClicked(cocos2d::Ref* sender);
    void onNegativeTestsClicked(cocos2d::Ref* sender);
    
    // 辅助方法
    void appendLog(const std::string& message);
    void updateStatus(const std::string& status);
    void showToast(const std::string& message);
    
    // 压力测试定时器
    void stressTestTick(float dt);
    
    // HTTP 请求回调
    void onHttpRequestCompleted(cocos2d::network::HttpClient* sender, 
                               cocos2d::network::HttpResponse* response);

    // 工具：脱敏与解析
    static std::string maskToken(const std::string& token);
    static std::string extractTokenFromJson(const std::string& json);
};

#endif // __MAIN_SCENE_H__
