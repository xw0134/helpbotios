#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// Unity 消息发送函数（由 Unity 提供）
extern void UnitySendMessage(const char* obj, const char* method, const char* msg);

// HelpBot SDK 初始化
void HelpBot_Install(const char* configJson, const char* gameObjectName, const char* callbackMethod);

// 用户登录
void HelpBot_Login(const char* token, const char* loginConfigJson, const char* gameObjectName, const char* callbackMethod);

// 显示对话窗口
void HelpBot_ShowConversation(void);

// 显示 FAQ
void HelpBot_ShowFAQs(const char* configJson);

// 用户登出
void HelpBot_Logout(const char* gameObjectName, const char* callbackMethod);

// 销毁 SDK
void HelpBot_Destroy(void);

// 设置事件监听器
void HelpBot_SetEventsListener(const char* gameObjectName, const char* eventMethod, const char* authFailureMethod);

// 清除事件监听器
void HelpBot_ClearEventsListener(void);

// 更新主属性
void HelpBot_UpdateMasterAttributes(const char* attributesJson, const char* gameObjectName, const char* callbackMethod);

// 更新应用属性
void HelpBot_UpdateAppAttributes(const char* attributesJson, const char* gameObjectName, const char* callbackMethod);

// 获取 SDK 版本
const char* HelpBot_GetSDKVersion(void);

#ifdef __cplusplus
}
#endif
