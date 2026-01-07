/**
 * MainScene.cpp
 * HelpBot Demo 主场景实现
 */

#include "MainScene.h"
#include <sstream>
#include <vector>
#include <algorithm>

USING_NS_CC;
using namespace cocos2d::ui;
using namespace cocos2d::network;

Scene* MainScene::createScene()
{
    return MainScene::create();
}

bool MainScene::init()
{
    if (!Scene::init())
    {
        return false;
    }

    auto visibleSize = Director::getInstance()->getVisibleSize();
    auto origin = Director::getInstance()->getVisibleOrigin();
    
    // 背景
    auto bg = LayerColor::create(Color4B(240, 240, 240, 255));
    this->addChild(bg, 0);

    createUI();
    
    // 监听 HelpBot 事件
    HelpBotBridge::getInstance()->setEventListener([this](const std::string& eventName, const std::map<std::string, std::string>& data) {
        std::stringstream ss;
        ss << "收到事件: " << eventName;
        for (const auto& pair : data) {
            ss << "\n  key: " << pair.first << ", value: " << pair.second;
        }
        this->appendLog(ss.str());
    });
    
    // 打印初始化日志
    appendLog("Cocos2d Demo 已启动");
    appendLog("SDK 版本: " + HelpBotBridge::getInstance()->getSDKVersion());

    return true;
}

void MainScene::createUI()
{
    auto visibleSize = Director::getInstance()->getVisibleSize();
    float startY = visibleSize.height - 50;
    float gapY = 50;
    float centerX = visibleSize.width / 2;
    
    // 1. 输入区域
    // Channel ID
    auto labelChannel = Text::create("Channel ID:", "Arial", 24);
    labelChannel->setColor(Color3B::BLACK);
    labelChannel->setAnchorPoint(Vec2(0, 0.5));
    labelChannel->setPosition(Vec2(20, startY));
    this->addChild(labelChannel);
    
    editChannelId = TextField::create("Enter Channel ID", "Arial", 24);
    editChannelId->setColor(Color3B::BLACK);
    editChannelId->setPosition(Vec2(centerX + 50, startY));
    // 对齐 Android Demo 默认值
    editChannelId->setText("appc-20251126114209416-ptvea1y414vey36");
    this->addChild(editChannelId);
    
    startY -= gapY;
    
    // Domain
    auto labelDomain = Text::create("Domain:", "Arial", 24);
    labelDomain->setColor(Color3B::BLACK);
    labelDomain->setAnchorPoint(Vec2(0, 0.5));
    labelDomain->setPosition(Vec2(20, startY));
    this->addChild(labelDomain);
    
    // 对齐 Android Demo：允许仅填写 host（SDK 内部会自动补全为 https://），也允许直接填写 https://xxx
    editDomain = TextField::create("Enter Domain (host or https://...)", "Arial", 24);
    editDomain->setColor(Color3B::BLACK);
    editDomain->setPosition(Vec2(centerX + 50, startY));
    editDomain->setText("dev-bot-server.yuedongcs.com");
    this->addChild(editDomain);
    
    startY -= gapY;

    // Token URL
    auto labelTokenUrl = Text::create("Token URL:", "Arial", 24);
    labelTokenUrl->setColor(Color3B::BLACK);
    labelTokenUrl->setAnchorPoint(Vec2(0, 0.5));
    labelTokenUrl->setPosition(Vec2(20, startY));
    this->addChild(labelTokenUrl);

    editTokenUrl = TextField::create("Enter Token Gen URL", "Arial", 24);
    editTokenUrl->setColor(Color3B::BLACK);
    editTokenUrl->setPosition(Vec2(centerX + 50, startY));
    editTokenUrl->setText("https://dev-bot-server.yuedongcs.com:8123/generate_token");
    this->addChild(editTokenUrl);
    
    startY -= gapY;
    
    // Identifier & Value
    auto labelId = Text::create("ID:", "Arial", 24);
    labelId->setColor(Color3B::BLACK);
    labelId->setPosition(Vec2(50, startY));
    this->addChild(labelId);
    
    editIdentifier = TextField::create("user_id", "Arial", 24);
    editIdentifier->setColor(Color3B::BLACK);
    editIdentifier->setPosition(Vec2(150, startY));
    editIdentifier->setText("uid");
    this->addChild(editIdentifier);
    
    auto labelVal = Text::create("Val:", "Arial", 24);
    labelVal->setColor(Color3B::BLACK);
    labelVal->setPosition(Vec2(300, startY));
    this->addChild(labelVal);

    editValue = TextField::create("name", "Arial", 24);
    editValue->setColor(Color3B::BLACK);
    editValue->setPosition(Vec2(400, startY));
    editValue->setText("123456789");
    this->addChild(editValue);
    
    startY -= gapY;
    
    // Buttons Row 1
    auto btnInstall = Button::create();
    btnInstall->setTitleText("Install SDK");
    btnInstall->setTitleFontSize(24);
    btnInstall->setTitleColor(Color3B::BLUE);
    btnInstall->setPosition(Vec2(centerX - 150, startY));
    btnInstall->addClickEventListener(CC_CALLBACK_1(MainScene::onInstallClicked, this));
    this->addChild(btnInstall);
    
    auto btnGenToken = Button::create();
    btnGenToken->setTitleText("Gen Token");
    btnGenToken->setTitleFontSize(24);
    btnGenToken->setTitleColor(Color3B::BLUE);
    btnGenToken->setPosition(Vec2(centerX, startY));
    btnGenToken->addClickEventListener(CC_CALLBACK_1(MainScene::onGenerateTokenClicked, this));
    this->addChild(btnGenToken);
    
    auto btnLogin = Button::create();
    btnLogin->setTitleText("Login");
    btnLogin->setTitleFontSize(24);
    btnLogin->setTitleColor(Color3B::BLUE);
    btnLogin->setPosition(Vec2(centerX + 150, startY));
    btnLogin->addClickEventListener(CC_CALLBACK_1(MainScene::onLoginClicked, this));
    this->addChild(btnLogin);
    
    startY -= gapY;
    
    // Buttons Row 2
    auto btnChat = Button::create();
    btnChat->setTitleText("Show Chat");
    btnChat->setTitleFontSize(24);
    btnChat->setTitleColor(Color3B::BLUE);
    btnChat->setPosition(Vec2(centerX - 150, startY));
    btnChat->addClickEventListener(CC_CALLBACK_1(MainScene::onShowConversationClicked, this));
    this->addChild(btnChat);
    
    auto btnFAQ = Button::create();
    btnFAQ->setTitleText("Show FAQs");
    btnFAQ->setTitleFontSize(24);
    btnFAQ->setTitleColor(Color3B::BLUE);
    btnFAQ->setPosition(Vec2(centerX, startY));
    btnFAQ->addClickEventListener(CC_CALLBACK_1(MainScene::onShowFAQsClicked, this));
    this->addChild(btnFAQ);
    
    auto btnFunc = Button::create();
    btnFunc->setTitleText("Update Meta");
    btnFunc->setTitleFontSize(24);
    btnFunc->setTitleColor(Color3B::BLUE);
    btnFunc->setPosition(Vec2(centerX + 150, startY));
    btnFunc->addClickEventListener(CC_CALLBACK_1(MainScene::onUpdateMetaClicked, this));
    this->addChild(btnFunc);
    
    startY -= gapY;

    // Status Area
    textStatus = Text::create("Status: Ready", "Arial", 24);
    textStatus->setColor(Color3B::RED);
    textStatus->setPosition(Vec2(centerX, startY));
    this->addChild(textStatus);
    
    startY -= gapY;
    
    textToken = Text::create("Token: None", "Arial", 20);
    textToken->setColor(Color3B::GRAY);
    textToken->setPosition(Vec2(centerX, startY));
    this->addChild(textToken);
    
    startY -= gapY;
    
    // Log Area
    auto logBg = LayerColor::create(Color4B(200, 200, 200, 255), visibleSize.width - 40, 300);
    logBg->setPosition(Vec2(20, 20));
    this->addChild(logBg);
    
    scrollViewLog = ScrollView::create();
    scrollViewLog->setDirection(ScrollView::Direction::VERTICAL);
    scrollViewLog->setContentSize(Size(visibleSize.width - 40, 300));
    scrollViewLog->setPosition(Vec2(20, 20));
    this->addChild(scrollViewLog);
    
    textLog = Text::create("", "Arial", 20);
    textLog->setColor(Color3B::BLACK);
    textLog->setAnchorPoint(Vec2(0, 1));
    textLog->setTextAreaSize(Size(visibleSize.width - 60, 0));
    textLog->ignoreContentAdaptWithSize(false);
    textLog->setPosition(Vec2(10, 290));
    scrollViewLog->addChild(textLog);
    
    auto btnClear = Button::create();
    btnClear->setTitleText("Clear Log");
    btnClear->setTitleFontSize(20);
    btnClear->setTitleColor(Color3B::BLACK);
    btnClear->setPosition(Vec2(visibleSize.width - 80, 340));
    btnClear->addClickEventListener(CC_CALLBACK_1(MainScene::onClearLogClicked, this));
    this->addChild(btnClear);
}

void MainScene::onInstallClicked(cocos2d::Ref* sender)
{
    std::string channel = editChannelId->getString();
    std::string domain = editDomain->getString();
    
    if (channel.empty() || domain.empty()) {
        updateStatus("Error: Channel or Domain is empty");
        return;
    }
    
    appendLog("Installing SDK...");
    HelpBotBridge::getInstance()->install(channel, domain, [this](bool success, const std::string& msg){
        if (success) {
            updateStatus("Install Success");
            appendLog("SDK Install Success");
        } else {
            updateStatus("Install Failed: " + msg);
            appendLog("SDK Install Failed: " + msg);
        }
    });
}

void MainScene::onGenerateTokenClicked(cocos2d::Ref* sender)
{
    // 对齐 Android Demo：优先走真实 Token API；为空时 fallback mock
    std::string url = editTokenUrl->getString();
    if (url.empty()) {
        // 模拟生成一个 Token 以供测试
        rawToken = "mock_jwt_token_" + editIdentifier->getString();
        textToken->setString("Token(脱敏): " + maskToken(rawToken));
        appendLog("Token Generated (Mock): " + maskToken(rawToken));
        updateStatus("Token Generated (Mock)");
        return;
    }
    
    updateStatus("Generating Token...");
    appendLog("Requesting Token from: " + url);

    // 构造请求体：{"identities":[{"identifier":"uid","value":"123"}]}
    const std::string identifier = editIdentifier->getString();
    const std::string value = editValue->getString();
    const std::string jsonBody = std::string("{\"identities\":[{\"identifier\":\"")
            + identifier + "\",\"value\":\"" + value + "\"}]}";

    auto request = new HttpRequest();
    request->setUrl(url.c_str());
    request->setRequestType(HttpRequest::Type::POST);
    std::vector<std::string> headers;
    headers.emplace_back("Content-Type: application/json");
    request->setHeaders(headers);
    request->setRequestData(jsonBody.c_str(), jsonBody.length());
    request->setResponseCallback(CC_CALLBACK_2(MainScene::onHttpRequestCompleted, this));
    HttpClient::getInstance()->send(request);
    request->release();
}

void MainScene::onLoginClicked(cocos2d::Ref* sender)
{
    if (rawToken.empty()) {
        updateStatus("Error: No Token");
        return;
    }
    
    appendLog("Logging in...");
    HelpBotBridge::getInstance()->login(rawToken, [this](bool success, const std::string& msg){
        if (success) {
            updateStatus("Login Success");
            appendLog("Login Success");
        } else {
            updateStatus("Login Failed: " + msg);
            appendLog("Login Failed: " + msg);
        }
    });
}

void MainScene::onShowConversationClicked(cocos2d::Ref* sender)
{
    HelpBotBridge::getInstance()->showConversation([this](bool success, const std::string& msg){
         if (!success) {
             appendLog("Show Conversation Failed: " + msg);
         }
    });
}

void MainScene::onShowFAQsClicked(cocos2d::Ref* sender)
{
    HelpBotBridge::getInstance()->showFAQs([this](bool success, const std::string& msg){
         if (!success) {
             appendLog("Show FAQs Failed: " + msg);
         }
    });
}

void MainScene::onUpdateMetaClicked(cocos2d::Ref* sender)
{
    std::map<std::string, std::string> meta;
    meta["user_level"] = "10";
    meta["server"] = "S1";
    
    HelpBotBridge::getInstance()->updateCustomMeta(meta);
    appendLog("Custom Meta Updated");
    
    std::map<std::string, std::string> sdkMeta;
    sdkMeta["engine"] = "cocos2d-x";
    HelpBotBridge::getInstance()->updateSDKMeta(sdkMeta);
    appendLog("SDK Meta Updated");
}

void MainScene::onClearLogClicked(cocos2d::Ref* sender)
{
    logBuffer = "";
    textLog->setString("");
}

void MainScene::onCopyTokenClicked(cocos2d::Ref* sender)
{
    // copy to clipboard
    cocos2d::Device::setKeepScreenOn(true); // Dummy call
    appendLog("Token copied to clipboard (Mock)");
}

void MainScene::appendLog(const std::string& message)
{
    // 在主线程更新 UI
    Director::getInstance()->getScheduler()->performFunctionInCocosThread([this, message](){
        logBuffer += "\n> " + message;
        if (logBuffer.length() > 5000) {
            logBuffer = logBuffer.substr(logBuffer.length() - 5000);
        }
        textLog->setString(logBuffer);
        
        // 自动滚动到底部
        float innerHeight = textLog->getVirtualRendererSize().height;
        scrollViewLog->setInnerContainerSize(Size(scrollViewLog->getContentSize().width, innerHeight));
        scrollViewLog->scrollToBottom(0.1, false);
    });
}

void MainScene::updateStatus(const std::string& status)
{
    Director::getInstance()->getScheduler()->performFunctionInCocosThread([this, status](){
        textStatus->setString("Status: " + status);
    });
}

void MainScene::onHttpRequestCompleted(cocos2d::network::HttpClient* sender,
        cocos2d::network::HttpResponse* response) {
    try {
        if (response == nullptr) {
            updateStatus("Token Failed: response null");
            appendLog("Token Failed: response null");
            return;
        }
        if (!response->isSucceed()) {
            const std::string err = response->getErrorBuffer() ? std::string(response->getErrorBuffer()) : "unknown";
            updateStatus("Token Failed: " + err);
            appendLog("Token Failed: " + err);
            return;
        }
        std::vector<char>* buffer = response->getResponseData();
        if (buffer == nullptr || buffer->empty()) {
            updateStatus("Token Failed: empty response");
            appendLog("Token Failed: empty response");
            return;
        }
        std::string body(buffer->begin(), buffer->end());
        const std::string token = extractTokenFromJson(body);
        if (token.empty()) {
            updateStatus("Token Failed: parse error");
            appendLog("Token Failed: parse error");
            return;
        }
        rawToken = token;
        textToken->setString("Token(脱敏): " + maskToken(rawToken));
        appendLog("Token Generated: " + maskToken(rawToken));
        updateStatus("Token Generated");
    } catch (const std::exception& e) {
        updateStatus(std::string("Token Failed: ") + e.what());
        appendLog(std::string("Token Failed: ") + e.what());
    } catch (...) {
        updateStatus("Token Failed: unknown exception");
        appendLog("Token Failed: unknown exception");
    }
}

std::string MainScene::maskToken(const std::string& token) {
    try {
        std::string t = token;
        t.erase(std::remove_if(t.begin(), t.end(), ::isspace), t.end());
        if (t.empty()) {
            return "";
        }
        if (t.length() <= 12) {
            return t.substr(0, std::min<size_t>(4, t.length())) + "***";
        }
        return t.substr(0, 6) + "..." + t.substr(t.length() - 6);
    } catch (...) {
        return "***";
    }
}

std::string MainScene::extractTokenFromJson(const std::string& json) {
    try {
        // 极简解析：查找 "token":"..."
        const std::string key = "\"token\"";
        size_t p = json.find(key);
        if (p == std::string::npos) {
            return "";
        }
        p = json.find(':', p + key.length());
        if (p == std::string::npos) {
            return "";
        }
        p = json.find('"', p);
        if (p == std::string::npos) {
            return "";
        }
        size_t end = json.find('"', p + 1);
        if (end == std::string::npos || end <= p + 1) {
            return "";
        }
        return json.substr(p + 1, end - p - 1);
    } catch (...) {
        return "";
    }
}

// ==================== 高级功能实现 ====================

void MainScene::onSelfCheckClicked(cocos2d::Ref* sender) {
    appendLog("========== 一键自检开始 ==========");
    updateStatus("自检中...");
    
    // 1. 基础信息
    appendLog("Cocos2d-x 版本: " + cocos2d::cocos2dVersion());
    appendLog("平台: " + std::string(CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID ? "Android" : 
                                     CC_TARGET_PLATFORM == CC_PLATFORM_IOS ? "iOS" : "Other"));
    appendLog("SDK 版本: " + HelpBotBridge::getInstance()->getSDKVersion());
    
    // 2. 显示信息
    auto director = cocos2d::Director::getInstance();
    auto visibleSize = director->getVisibleSize();
    std::stringstream ss;
    ss << "屏幕尺寸: " << visibleSize.width << "x" << visibleSize.height;
    appendLog(ss.str());
    
    // 3. SDK 状态
    appendLog("SDK 已初始化: " + std::string(HelpBotBridge::getInstance()->isInitialized() ? "是" : "否"));
    
    updateStatus("自检完成");
    appendLog("========== 一键自检完成 ==========");
}

void MainScene::onStressTestStartClicked(cocos2d::Ref* sender) {
    if (stressTestRunning) {
        appendLog("压力测试已在运行中");
        return;
    }
    
    appendLog("========== 压力测试开始 ==========");
    stressTestRunning = true;
    stressLoopCount = 0;
    stressSuccessCount = 0;
    stressFailureCount = 0;
    
    // 启动定时器，每秒执行一次
    this->schedule(CC_SCHEDULE_SELECTOR(MainScene::stressTestTick), 1.0f);
}

void MainScene::onStressTestStopClicked(cocos2d::Ref* sender) {
    if (!stressTestRunning) {
        appendLog("压力测试未运行");
        return;
    }
    
    stressTestRunning = false;
    this->unschedule(CC_SCHEDULE_SELECTOR(MainScene::stressTestTick));
    
    appendLog("========== 压力测试停止 ==========");
    std::stringstream ss;
    ss << "总循环: " << stressLoopCount;
    appendLog(ss.str());
    ss.str("");
    ss << "成功: " << stressSuccessCount;
    appendLog(ss.str());
    ss.str("");
    ss << "失败: " << stressFailureCount;
    appendLog(ss.str());
    updateStatus("压力测试已停止");
}

void MainScene::stressTestTick(float dt) {
    if (!stressTestRunning) {
        return;
    }
    
    stressLoopCount++;
    std::stringstream ss;
    ss << "压力测试中... 循环 " << stressLoopCount;
    updateStatus(ss.str());
    
    // 显示对话
    HelpBotBridge::getInstance()->showConversation([this](bool success, const std::string& msg) {
        if (success) {
            stressSuccessCount++;
        } else {
            stressFailureCount++;
            appendLog("Show 失败: " + msg);
        }
    });
    
    // 每 10 次循环输出一次统计
    if (stressLoopCount % 10 == 0) {
        std::stringstream statsSs;
        statsSs << "压力测试进度: " << stressLoopCount << " 次, 成功: " 
                << stressSuccessCount << ", 失败: " << stressFailureCount;
        appendLog(statsSs.str());
    }
}

void MainScene::onNegativeTestsClicked(cocos2d::Ref* sender) {
    appendLog("========== 负向测试开始 ==========");
    updateStatus("负向测试中...");
    
    // 1. 未登录直接 ShowConversation
    appendLog("测试 1: 未登录直接 ShowConversation");
    HelpBotBridge::getInstance()->showConversation([this](bool success, const std::string& msg) {
        appendLog("  结果: " + std::string(success ? "成功" : "失败 - " + msg));
    });
    
    // 2. 空 Token 登录
    appendLog("测试 2: 空 Token 登录");
    HelpBotBridge::getInstance()->login("", [this](bool success, const std::string& msg) {
        appendLog("  结果: " + std::string(success ? "意外成功" : "预期失败 - " + msg));
    });
    
    // 3. 无效配置 Install
    appendLog("测试 3: 无效配置 Install");
    HelpBotBridge::getInstance()->install("", "", [this](bool success, const std::string& msg) {
        appendLog("  结果: " + std::string(success ? "意外成功" : "预期失败 - " + msg));
    });
    
    // 4. 重复 Install
    appendLog("测试 4: 重复 Install");
    if (HelpBotBridge::getInstance()->isInitialized()) {
        std::string channel = editChannelId->getString();
        std::string domain = editDomain->getString();
        HelpBotBridge::getInstance()->install(channel, domain, [this](bool success, const std::string& msg) {
            appendLog("  结果: " + std::string(success ? "成功" : "失败 - " + msg));
        });
    }
    
    updateStatus("负向测试完成");
    appendLog("========== 负向测试完成 ==========");
}

