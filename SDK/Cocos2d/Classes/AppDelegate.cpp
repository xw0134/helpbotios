/**
 * AppDelegate.cpp
 * Cocos2d-x 应用委托实现
 */

#include "AppDelegate.h"
#include "MainScene.h"
#include "HelpBotBridge.h"

USING_NS_CC;

// 设计分辨率
static cocos2d::Size designResolutionSize = cocos2d::Size(720, 1280);
static cocos2d::Size smallResolutionSize = cocos2d::Size(480, 854);
static cocos2d::Size mediumResolutionSize = cocos2d::Size(720, 1280);
static cocos2d::Size largeResolutionSize = cocos2d::Size(1080, 1920);

AppDelegate::AppDelegate() {
}

AppDelegate::~AppDelegate() {
    // 清理 HelpBot SDK
    HelpBotBridge::destroyInstance();
}

void AppDelegate::initGLContextAttrs() {
    // 设置 OpenGL 上下文属性
    GLContextAttrs glContextAttrs = {8, 8, 8, 8, 24, 8, 0};
    GLView::setGLContextAttrs(glContextAttrs);
}

static int register_all_packages() {
    return 0; // 标志成功
}

bool AppDelegate::applicationDidFinishLaunching() {
    // 初始化 Director
    auto director = Director::getInstance();
    auto glview = director->getOpenGLView();
    
    if(!glview) {
#if (CC_TARGET_PLATFORM == CC_PLATFORM_WIN32) || (CC_TARGET_PLATFORM == CC_PLATFORM_MAC) || (CC_TARGET_PLATFORM == CC_PLATFORM_LINUX)
        glview = GLViewImpl::createWithRect("HelpBot Cocos2d Demo", 
                                           cocos2d::Rect(0, 0, designResolutionSize.width, designResolutionSize.height));
#else
        glview = GLViewImpl::create("HelpBot Cocos2d Demo");
#endif
        director->setOpenGLView(glview);
    }

    // 开启 FPS 显示（调试用）
    director->setDisplayStats(true);

    // 设置 FPS
    director->setAnimationInterval(1.0f / 60);

    // 设置设计分辨率
    glview->setDesignResolutionSize(designResolutionSize.width, 
                                   designResolutionSize.height, 
                                   ResolutionPolicy::NO_BORDER);
    
    auto frameSize = glview->getFrameSize();
    
    // 根据屏幕大小选择资源
    if (frameSize.height > mediumResolutionSize.height) {
        director->setContentScaleFactor(MIN(largeResolutionSize.height/designResolutionSize.height, 
                                           largeResolutionSize.width/designResolutionSize.width));
    }
    else if (frameSize.height > smallResolutionSize.height) {
        director->setContentScaleFactor(MIN(mediumResolutionSize.height/designResolutionSize.height, 
                                           mediumResolutionSize.width/designResolutionSize.width));
    }
    else {
        director->setContentScaleFactor(MIN(smallResolutionSize.height/designResolutionSize.height, 
                                           smallResolutionSize.width/designResolutionSize.width));
    }

    register_all_packages();

    // 创建并运行主场景
    auto scene = MainScene::createScene();
    director->runWithScene(scene);

    return true;
}

void AppDelegate::applicationDidEnterBackground() {
    Director::getInstance()->stopAnimation();
    
    // 如果需要，可以在这里暂停 HelpBot SDK 相关功能
}

void AppDelegate::applicationWillEnterForeground() {
    Director::getInstance()->startAnimation();
    
    // 如果需要，可以在这里恢复 HelpBot SDK 相关功能
}
