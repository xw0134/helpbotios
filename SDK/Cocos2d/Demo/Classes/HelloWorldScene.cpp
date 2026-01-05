#include "HelloWorldScene.h"
#include <sstream>
#include <iomanip>

USING_NS_CC;
using namespace helpbot;

// ==================== HelloWorld Scene ====================

Scene* HelloWorld::createScene() {
    return HelloWorld::create();
}

bool HelloWorld::init() {
    if (!Scene::init()) {
        return false;
    }
    
    // 创建 UI
    createUI();
    
    // 创建回调对象
    m_initCallback = std::make_shared<DemoInitCallback>(this);
    m_loginCallback = std::make_shared<DemoLoginCallback>(this);
    m_eventsListener = std::make_shared<DemoEventsListener>(this);
    
    // 设置事件监听器
    HelpBot::setHelpBotEventsListener(m_eventsListener.get());
    
    // 初始日志
    appendLog("HelpBot Cocos2d Demo 已启动");
    appendLog("SDK 版本: " + HelpBot::getSDKVersion());
    
    return true;
}

void HelloWorld::createUI() {
    createInputFields();
    createButtons();
    createStatusArea();
    createLogArea();
}

void HelloWorld::createInputFields() {
    auto visibleSize = Director::getInstance()->getVisibleSize();
    Vec2 origin = Director::getInstance()->getVisibleOrigin();
    
    float startY = origin.y + visibleSize.height - 50;
    float inputWidth = 300;
    float inputHeight = 40;
    
    // Channel ID 输入
    auto channelLabel = ui::Text::create("Channel ID:", "Arial", 20);
    channelLabel->setPosition(Vec2(origin.x + 100, startY));
    this->addChild(channelLabel);
    
    m_channelIdInput = ui::TextField::create("your_channel_id", "Arial", 20);
    m_channelIdInput->setMaxLength(50);
    m_channelIdInput->setPosition(Vec2(origin.x + 250, startY));
    m_channelIdInput->setContentSize(Size(inputWidth, inputHeight));
    this->addChild(m_channelIdInput);
    
    // Domain 输入
    startY -= 50;
    auto domainLabel = ui::Text::create("Domain:", "Arial", 20);
    domainLabel->setPosition(Vec2(origin.x + 100, startY));
    this->addChild(domainLabel);
    
    m_domainInput = ui::TextField::create("https://your-domain.com", "Arial", 20);
    m_domainInput->setMaxLength(100);
    m_domainInput->setPosition(Vec2(origin.x + 250, startY));
    m_domainInput->setContentSize(Size(inputWidth, inputHeight));
    this->addChild(m_domainInput);
    
    // Token URL 输入
    startY -= 50;
    auto tokenUrlLabel = ui::Text::create("Token URL:", "Arial", 20);
    tokenUrlLabel->setPosition(Vec2(origin.x + 100, startY));
    this->addChild(tokenUrlLabel);
    
    m_tokenUrlInput = ui::TextField::create("https://api.example.com/token", "Arial", 20);
    m_tokenUrlInput->setMaxLength(100);
    m_tokenUrlInput->setPosition(Vec2(origin.x + 250, startY));
    m_tokenUrlInput->setContentSize(Size(inputWidth, inputHeight));
    this->addChild(m_tokenUrlInput);
}

void HelloWorld::createButtons() {
    auto visibleSize = Director::getInstance()->getVisibleSize();
    Vec2 origin = Director::getInstance()->getVisibleOrigin();
    
    float startY = origin.y + visibleSize.height - 200;
    float buttonWidth = 150;
    float buttonHeight = 50;
    float spacing = 20;
    
    // Install 按钮
    m_installBtn = ui::Button::create();
    m_installBtn->setTitleText("Install SDK");
    m_installBtn->setTitleFontSize(18);
    m_installBtn->setContentSize(Size(buttonWidth, buttonHeight));
    m_installBtn->setPosition(Vec2(origin.x + 100, startY));
    m_installBtn->addClickEventListener(CC_CALLBACK_1(HelloWorld::onInstallClicked, this));
    this->addChild(m_installBtn);
    
    // Generate Token 按钮
    m_genTokenBtn = ui::Button::create();
    m_genTokenBtn->setTitleText("Gen Token");
    m_genTokenBtn->setTitleFontSize(18);
    m_genTokenBtn->setContentSize(Size(buttonWidth, buttonHeight));
    m_genTokenBtn->setPosition(Vec2(origin.x + 100 + buttonWidth + spacing, startY));
    m_genTokenBtn->addClickEventListener(CC_CALLBACK_1(HelloWorld::onGenTokenClicked, this));
    m_genTokenBtn->setEnabled(false);
    this->addChild(m_genTokenBtn);
    
    // Login 按钮
    startY -= (buttonHeight + spacing);
    m_loginBtn = ui::Button::create();
    m_loginBtn->setTitleText("Login");
    m_loginBtn->setTitleFontSize(18);
    m_loginBtn->setContentSize(Size(buttonWidth, buttonHeight));
    m_loginBtn->setPosition(Vec2(origin.x + 100, startY));
    m_loginBtn->addClickEventListener(CC_CALLBACK_1(HelloWorld::onLoginClicked, this));
    m_loginBtn->setEnabled(false);
    this->addChild(m_loginBtn);
    
    // Show Conversation 按钮
    m_showConversationBtn = ui::Button::create();
    m_showConversationBtn->setTitleText("Show Chat");
    m_showConversationBtn->setTitleFontSize(18);
    m_showConversationBtn->setContentSize(Size(buttonWidth, buttonHeight));
    m_showConversationBtn->setPosition(Vec2(origin.x + 100 + buttonWidth + spacing, startY));
    m_showConversationBtn->addClickEventListener(CC_CALLBACK_1(HelloWorld::onShowConversationClicked, this));
    m_showConversationBtn->setEnabled(false);
    this->addChild(m_showConversationBtn);
    
    // Test FAQ 按钮
    startY -= (buttonHeight + spacing);
    m_testFAQBtn = ui::Button::create();
    m_testFAQBtn->setTitleText("Test FAQ");
    m_testFAQBtn->setTitleFontSize(18);
    m_testFAQBtn->setContentSize(Size(buttonWidth, buttonHeight));
    m_testFAQBtn->setPosition(Vec2(origin.x + 100, startY));
    m_testFAQBtn->addClickEventListener(CC_CALLBACK_1(HelloWorld::onTestFAQClicked, this));
    m_testFAQBtn->setEnabled(false);
    this->addChild(m_testFAQBtn);
    
    // Test Meta 按钮
    m_testMetaBtn = ui::Button::create();
    m_testMetaBtn->setTitleText("Test Meta");
    m_testMetaBtn->setTitleFontSize(18);
    m_testMetaBtn->setContentSize(Size(buttonWidth, buttonHeight));
    m_testMetaBtn->setPosition(Vec2(origin.x + 100 + buttonWidth + spacing, startY));
    m_testMetaBtn->addClickEventListener(CC_CALLBACK_1(HelloWorld::onTestMetaClicked, this));
    m_testMetaBtn->setEnabled(false);
    this->addChild(m_testMetaBtn);
}

void HelloWorld::createStatusArea() {
    auto visibleSize = Director::getInstance()->getVisibleSize();
    Vec2 origin = Director::getInstance()->getVisibleOrigin();
    
    // 状态标签
    m_statusLabel = ui::Text::create("状态: 未初始化", "Arial", 22);
    m_statusLabel->setPosition(Vec2(origin.x + visibleSize.width / 2, origin.y + visibleSize.height - 450));
    m_statusLabel->setColor(Color3B::YELLOW);
    this->addChild(m_statusLabel);
    
    // Token 显示
    m_tokenLabel = ui::Text::create("Token: (未生成)", "Arial", 16);
    m_tokenLabel->setPosition(Vec2(origin.x + visibleSize.width / 2, origin.y + visibleSize.height - 480));
    m_tokenLabel->setColor(Color3B::GREEN);
    this->addChild(m_tokenLabel);
}

void HelloWorld::createLogArea() {
    auto visibleSize = Director::getInstance()->getVisibleSize();
    Vec2 origin = Director::getInstance()->getVisibleOrigin();
    
    // 日志滚动视图
    m_logScrollView = ui::ScrollView::create();
    m_logScrollView->setContentSize(Size(visibleSize.width - 40, 200));
    m_logScrollView->setPosition(Vec2(origin.x + 20, origin.y + 20));
    m_logScrollView->setDirection(ui::ScrollView::Direction::VERTICAL);
    m_logScrollView->setBounceEnabled(true);
    this->addChild(m_logScrollView);
    
    // 日志文本
    m_logText = ui::Text::create("", "Arial", 14);
    m_logText->setAnchorPoint(Vec2(0, 1));
    m_logText->setPosition(Vec2(5, 195));
    m_logText->setTextAreaSize(Size(visibleSize.width - 50, 0));
    m_logScrollView->addChild(m_logText);
}

void HelloWorld::onInstallClicked(Ref* sender) {
    std::string channelId = m_channelIdInput->getString();
    std::string domain = m_domainInput->getString();
    
    if (channelId.empty() || domain.empty()) {
        appendLog("[错误] Channel ID 和 Domain 不能为空");
        return;
    }
    
    appendLog("[开始] 初始化 SDK...");
    appendLog("  Channel ID: " + channelId);
    appendLog("  Domain: " + domain);
    
    // 创建配置
    HelpBotConfig config = HelpBotConfig::Builder()
        .channelId(channelId)
        .domain(domain)
        .fullPrivacyMode(false)
        .enableSseNotification(true)
        .build();
    
    // 初始化 SDK
    HelpBot::install(config, m_initCallback.get());
    
    m_installBtn->setEnabled(false);
}

void HelloWorld::onGenTokenClicked(Ref* sender) {
    appendLog("[开始] 生成 Token...");
    generateToken();
}

void HelloWorld::onLoginClicked(Ref* sender) {
    if (m_rawToken.empty()) {
        appendLog("[错误] 请先生成 Token");
        return;
    }
    
    appendLog("[开始] 登录...");
    HelpBot::login(m_rawToken, nullptr, m_loginCallback.get());
    
    m_loginBtn->setEnabled(false);
}

void HelloWorld::onShowConversationClicked(Ref* sender) {
    appendLog("[执行] 显示对话界面");
    HelpBotResult<void> result = HelpBot::showConversation();
    
    if (result.isSuccess()) {
        appendLog("[成功] 对话界面已显示");
    } else {
        appendLog("[失败] " + result.getErrorMessage());
    }
}

void HelloWorld::onTestFAQClicked(Ref* sender) {
    appendLog("[测试] FAQ 功能");
    
    // 测试显示 FAQ 列表
    HelpBotResult<void> result = HelpBot::showFAQs();
    if (result.isSuccess()) {
        appendLog("[成功] FAQ 列表已显示");
    } else {
        appendLog("[失败] " + result.getErrorMessage());
    }
}

void HelloWorld::onTestMetaClicked(Ref* sender) {
    appendLog("[测试] 元数据更新");
    
    // 测试更新 SDK Meta
    std::map<std::string, std::string> sdkMeta;
    sdkMeta["game_version"] = "1.0.0";
    sdkMeta["player_level"] = "10";
    
    HelpBotResult<void> result = HelpBot::updateSDKMeta(sdkMeta);
    if (result.isSuccess()) {
        appendLog("[成功] SDK Meta 已更新");
    } else {
        appendLog("[失败] " + result.getErrorMessage());
    }
    
    // 测试更新 Custom Meta
    std::map<std::string, std::string> customMeta;
    customMeta["vip_level"] = "5";
    customMeta["server_id"] = "server_001";
    
    result = HelpBot::updateCustomMeta(customMeta);
    if (result.isSuccess()) {
        appendLog("[成功] Custom Meta 已更新");
    } else {
        appendLog("[失败] " + result.getErrorMessage());
    }
}

void HelloWorld::appendLog(const std::string& message) {
    // 在主线程中更新 UI
    Director::getInstance()->getScheduler()->performFunctionInCocosThread([this, message]() {
        std::string currentLog = m_logText->getString();
        std::string newLog = currentLog + "\n" + message;
        m_logText->setString(newLog);
        
        // 更新滚动视图内容大小
        Size textSize = m_logText->getContentSize();
        m_logScrollView->setInnerContainerSize(Size(m_logScrollView->getContentSize().width, 
                                                     std::max(textSize.height, m_logScrollView->getContentSize().height)));
        
        // 滚动到底部
        m_logScrollView->jumpToBottom();
    });
}

void HelloWorld::updateStatus(const std::string& status) {
    Director::getInstance()->getScheduler()->performFunctionInCocosThread([this, status]() {
        m_statusLabel->setString("状态: " + status);
    });
}

void HelloWorld::generateToken() {
    // 这里应该调用实际的 Token 生成 API
    // 为了演示,我们模拟一个简单的 Token
    std::string mockToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiMTIzNDU2Nzg5MCIsIm5hbWUiOiJDb2NvczJkIERlbW8iLCJpYXQiOjE1MTYyMzkwMjJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c";
    
    onTokenGenerated(mockToken);
}

void HelloWorld::onTokenGenerated(const std::string& token) {
    m_rawToken = token;
    
    // 截断显示
    std::string displayToken = token.length() > 30 ? 
        token.substr(0, 30) + "..." : token;
    
    m_tokenLabel->setString("Token: " + displayToken);
    appendLog("[成功] Token 已生成");
    
    m_loginBtn->setEnabled(true);
}

void HelloWorld::onTokenGenerationFailed(const std::string& error) {
    appendLog("[失败] Token 生成失败: " + error);
}

// ==================== DemoInitCallback ====================

void DemoInitCallback::onInitStart() {
    m_scene->appendLog("[回调] 初始化开始");
    m_scene->updateStatus("初始化中...");
}

void DemoInitCallback::onInitProgress(int progress, const std::string& message) {
    std::ostringstream oss;
    oss << "[回调] 初始化进度: " << progress << "% - " << message;
    m_scene->appendLog(oss.str());
}

void DemoInitCallback::onInitSuccess() {
    m_scene->appendLog("[回调] 初始化成功!");
    m_scene->updateStatus("已初始化");
    
    // 启用后续按钮
    Director::getInstance()->getScheduler()->performFunctionInCocosThread([this]() {
        m_scene->m_genTokenBtn->setEnabled(true);
        m_scene->m_testFAQBtn->setEnabled(true);
        m_scene->m_testMetaBtn->setEnabled(true);
    });
}

void DemoInitCallback::onInitFailure(HelpBotErrorCode errorCode, const std::string& errorMessage) {
    std::ostringstream oss;
    oss << "[回调] 初始化失败 (错误码: " << static_cast<int>(errorCode) << "): " << errorMessage;
    m_scene->appendLog(oss.str());
    m_scene->updateStatus("初始化失败");
    
    // 重新启用 Install 按钮
    Director::getInstance()->getScheduler()->performFunctionInCocosThread([this]() {
        m_scene->m_installBtn->setEnabled(true);
    });
}

// ==================== DemoLoginCallback ====================

void DemoLoginCallback::onSuccess() {
    m_scene->appendLog("[回调] 登录成功!");
    m_scene->updateStatus("已登录");
    
    // 启用对话按钮
    Director::getInstance()->getScheduler()->performFunctionInCocosThread([this]() {
        m_scene->m_showConversationBtn->setEnabled(true);
    });
}

void DemoLoginCallback::onFailure(HelpBotErrorCode errorCode, const std::string& errorMessage) {
    std::ostringstream oss;
    oss << "[回调] 登录失败 (错误码: " << static_cast<int>(errorCode) << "): " << errorMessage;
    m_scene->appendLog(oss.str());
    
    // 重新启用 Login 按钮
    Director::getInstance()->getScheduler()->performFunctionInCocosThread([this]() {
        m_scene->m_loginBtn->setEnabled(true);
    });
}

// ==================== DemoEventsListener ====================

void DemoEventsListener::onEventOccurred(const std::string& eventName, const EventData& data) {
    std::ostringstream oss;
    oss << "[事件] " << eventName;
    
    // 显示事件数据
    if (!data.empty()) {
        oss << " - 数据: {";
        bool first = true;
        for (const auto& pair : data) {
            if (!first) oss << ", ";
            oss << pair.first << ": " << pair.second;
            first = false;
        }
        oss << "}";
    }
    
    m_scene->appendLog(oss.str());
}

void DemoEventsListener::onUserAuthenticationFailure(HelpBotAuthenticationFailureReason reason) {
    std::ostringstream oss;
    oss << "[事件] 用户认证失败 (原因: " << static_cast<int>(reason) << ")";
    m_scene->appendLog(oss.str());
}
