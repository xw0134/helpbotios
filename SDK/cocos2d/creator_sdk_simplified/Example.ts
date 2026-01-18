/**
 * HelpBot SDK 使用示例 - 精简版
 * 
 * 这个版本只需要一个文件：HelpBotSDK.ts
 * 原生功能全部由 AAR/XCFramework 实现
 */

import HelpBotSDK from './HelpBotSDK';

// ==================== 1. 获取 SDK 实例 ====================

const helpBot = HelpBotSDK.getInstance();

// ==================== 2. 监听事件（可选）====================

helpBot.on((eventName, data) => {
    console.log(`[HelpBot Event] ${eventName}`, data);

    switch (eventName) {
        case 'INSTALL_SUCCESS':
            console.log('SDK 安装成功');
            break;
        case 'LOGIN_SUCCESS':
            console.log('用户登录成功');
            break;
        case 'CONVERSATION_SHOWN':
            console.log('会话界面已显示');
            break;
        case 'CONVERSATION_HIDDEN':
            console.log('会话界面已隐藏');
            break;
        case 'UNREAD_COUNT_CHANGED':
            console.log('未读消息数:', data?.count);
            break;
    }
});

// ==================== 3. 安装配置 ====================

helpBot.install({
    baseURL: 'https://your-helpbot-domain.com',
    token: 'your-installation-token',
    identifier: 'user-12345',
    name: '张三',
    email: 'zhangsan@example.com'
});

// ==================== 4. 用户登录 ====================

helpBot.login('user-session-token');

// ==================== 5. 显示客服会话 ====================

// 在按钮点击时调用
function onContactSupportClick() {
    helpBot.showConversation();
}

// ==================== 6. 隐藏会话 ====================

function onCloseConversation() {
    helpBot.hideConversation();
}

// ==================== 7. 更新用户信息 ====================

helpBot.updateCustomMeta({
    vipLevel: 5,
    gameLevel: 99,
    serverName: '服务器1',
    lastLoginTime: new Date().toISOString()
});

// ==================== 8. 添加问题标签 ====================

helpBot.addIssueTags(['充值问题', '账号问题']);

// ==================== 9. 用户登出 ====================

function onUserLogout() {
    helpBot.logout();
    helpBot.clearWebViewData(); // 清除缓存
}

// ==================== 10. 诊断工具 ====================

console.log('SDK 版本:', helpBot.getSdkVersion());
console.log('当前平台:', helpBot.getPlatform());
console.log('是否原生环境:', helpBot.isNative());
console.log('是否已初始化:', helpBot.isInitialized());

// ==================== 完整示例：Cocos Creator 组件 ====================

const { ccclass, property } = cc._decorator;

@ccclass
export default class GameMain extends cc.Component {

    onLoad() {
        // 初始化 HelpBot
        const helpBot = HelpBotSDK.getInstance();

        // 监听事件
        helpBot.on((eventName, data) => {
            console.log(`[HelpBot] ${eventName}`, data);
        });

        // 安装配置
        helpBot.install({
            baseURL: 'https://helpbot.example.com',
            token: 'your-token',
            identifier: 'user-id'
        });

        // 登录
        helpBot.login('user-token');
    }

    // 联系客服按钮点击
    onContactSupportBtnClick() {
        HelpBotSDK.getInstance().showConversation();
    }

    // 用户登出
    onUserLogout() {
        const helpBot = HelpBotSDK.getInstance();
        helpBot.logout();
        helpBot.clearWebViewData();
    }
}

// ==================== 对比说明 ====================

/**
 * 旧版本（复杂）:
 * - HelpBotSdk.ts (568 行)
 * - HelpBotNative.ts (原生调用封装)
 * - HelpBotEventBus.ts (事件总线)
 * - HelpBotTypes.ts (类型定义)
 * - HBlogger.ts (日志系统)
 * - HBGlobal.ts (全局配置)
 * - index.ts (导出)
 * 
 * 总计: 7 个文件，1000+ 行代码
 * 
 * 新版本（精简）:
 * - HelpBotSDK.ts (1 个文件，300 行)
 * 
 * 总计: 1 个文件，300 行代码
 * 
 * 功能完全一样！因为核心功能都在原生 SDK（AAR/XCFramework）中实现
 */
