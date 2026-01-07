/**
 * AppDelegate.h
 * Cocos2d-x 应用委托
 */

#ifndef  _APP_DELEGATE_H_
#define  _APP_DELEGATE_H_

#include "cocos2d.h"

/**
 * @brief 应用程序委托类
 * 
 * 负责应用程序生命周期管理和 Cocos2d-x 引擎初始化
 */
class AppDelegate : private cocos2d::Application
{
public:
    AppDelegate();
    virtual ~AppDelegate();

    /**
     * @brief 初始化 OpenGL 上下文属性
     */
    virtual void initGLContextAttrs();

    /**
     * @brief 应用程序启动完成回调
     * @return true 如果初始化成功
     */
    virtual bool applicationDidFinishLaunching();

    /**
     * @brief 应用程序进入后台回调
     */
    virtual void applicationDidEnterBackground();

    /**
     * @brief 应用程序进入前台回调
     */
    virtual void applicationWillEnterForeground();
};

#endif // _APP_DELEGATE_H_
