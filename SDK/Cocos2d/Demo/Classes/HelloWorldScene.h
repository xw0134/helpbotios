#ifndef __HELLOWORLD_SCENE_H__
#define __HELLOWORLD_SCENE_H__

#include "cocos2d.h"
#include "HelpBot.h"
#include "ui/CocosGUI.h"
#include <memory>

/**
 * HelpBot Cocos2d Demo 主场景
 * 
 * 功能:
 * - SDK 初始化测试
 * - Token 生成测试
 * - 登录测试
 * - 对话界面测试
 * - FAQ 接口测试
 * - 元数据更新测试
 * - 事件监听测试
 */
class HelloWorld : public cocos2d::Scene {
public:
    static cocos2d::Scene* createScene();

    virtual bool init();
    
    CREATE_FUNC(HelloWorld);

private:
    // UI 组件
    cocos2d::ui::TextField* m_channelIdInput;
    cocos2d::ui::TextField* m_domainInput;
    cocos2d::ui::TextField* m_tokenUrlInput;
    cocos2d::ui::TextField* m_identifierInput;
    cocos2d::ui::TextField* m_valueInput;
    
    cocos2d::ui::Button* m_installBtn;
    cocos2d::ui::Button* m_genTokenBtn;
    cocos2d::ui::Button* m_loginBtn;
    cocos2d::ui::Button* m_showConversationBtn;
    cocos2d::ui::Button* m_testFAQBtn;
    cocos2d::ui::Button* m_testMetaBtn;
    
    cocos2d::ui::Text* m_statusLabel;
    cocos2d::ui::Text* m_tokenLabel;
    cocos2d::ui::ScrollView* m_logScrollView;
    cocos2d::ui::Text* m_logText;
    
    // 数据
    std::string m_rawToken;
    std::shared_ptr<helpbot::HelpBotInitCallback> m_initCallback;
    std::shared_ptr<helpbot::HelpBotCallback<void>> m_loginCallback;
    std::shared_ptr<helpbot::HelpBotEventsListener> m_eventsListener;
    
    // UI 创建
    void createUI();
    void createInputFields();
    void createButtons();
    void createStatusArea();
    void createLogArea();
    
    // 按钮回调
    void onInstallClicked(cocos2d::Ref* sender);
    void onGenTokenClicked(cocos2d::Ref* sender);
    void onLoginClicked(cocos2d::Ref* sender);
    void onShowConversationClicked(cocos2d::Ref* sender);
    void onTestFAQClicked(cocos2d::Ref* sender);
    void onTestMetaClicked(cocos2d::Ref* sender);
    
    // 辅助方法
    void appendLog(const std::string& message);
    void updateStatus(const std::string& status);
    void generateToken();
    void onTokenGenerated(const std::string& token);
    void onTokenGenerationFailed(const std::string& error);
};

/**
 * 初始化回调实现
 */
class DemoInitCallback : public helpbot::HelpBotInitCallback {
public:
    DemoInitCallback(HelloWorld* scene) : m_scene(scene) {}
    
    void onInitStart() override;
    void onInitProgress(int progress, const std::string& message) override;
    void onInitSuccess() override;
    void onInitFailure(helpbot::HelpBotErrorCode errorCode, const std::string& errorMessage) override;
    
private:
    HelloWorld* m_scene;
};

/**
 * 登录回调实现
 */
class DemoLoginCallback : public helpbot::HelpBotCallback<void> {
public:
    DemoLoginCallback(HelloWorld* scene) : m_scene(scene) {}
    
    void onSuccess() override;
    void onFailure(helpbot::HelpBotErrorCode errorCode, const std::string& errorMessage) override;
    
private:
    HelloWorld* m_scene;
};

/**
 * 事件监听器实现
 */
class DemoEventsListener : public helpbot::HelpBotEventsListener {
public:
    DemoEventsListener(HelloWorld* scene) : m_scene(scene) {}
    
    void onEventOccurred(const std::string& eventName, const helpbot::EventData& data) override;
    void onUserAuthenticationFailure(helpbot::HelpBotAuthenticationFailureReason reason) override;
    
private:
    HelloWorld* m_scene;
};

#endif // __HELLOWORLD_SCENE_H__
