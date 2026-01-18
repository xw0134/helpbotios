/**
 * HelpBot SDK for Cocos2d Creator - 精简版
 * 
 * 职责：统一接口 + 平台自动判断 + 直接调用原生 SDK
 * 原生 SDK（AAR/XCFramework）负责所有核心功能实现
 */

// ==================== 类型定义 ====================

export interface HelpBotConfig {
    baseURL: string;      // 服务器地址
    token: string;        // 安装 Token
    identifier: string;   // 用户唯一标识
    name?: string;        // 用户名称
    email?: string;       // 用户邮箱
    avatar?: string;      // 用户头像
    [key: string]: any;   // 其他自定义配置
}

export type HelpBotEventCallback = (eventName: string, data?: any) => void;

// ==================== 主 SDK 类 ====================

export class HelpBotSDK {
    private static instance: HelpBotSDK;
    private platform: 'android' | 'ios' | 'unknown' = 'unknown';
    private nativeBridge: any = null;

    private constructor() {
        this.detectPlatform();
        this.initNativeBridge();
    }

    public static getInstance(): HelpBotSDK {
        if (!HelpBotSDK.instance) {
            HelpBotSDK.instance = new HelpBotSDK();
        }
        return HelpBotSDK.instance;
    }

    // ==================== 平台检测 ====================

    private detectPlatform(): void {
        try {
            // @ts-ignore
            if (typeof cc !== 'undefined' && cc.sys) {
                // @ts-ignore
                if (cc.sys.os === cc.sys.OS_ANDROID) {
                    this.platform = 'android';
                    // @ts-ignore
                } else if (cc.sys.os === cc.sys.OS_IOS) {
                    this.platform = 'ios';
                }
            }
        } catch (e) {
            console.error('[HelpBot] Platform detection failed:', e);
        }
    }

    // ==================== 原生桥接初始化 ====================

    private initNativeBridge(): void {
        try {
            // @ts-ignore
            if (typeof jsb === 'undefined' || !jsb.reflection) {
                console.warn('[HelpBot] jsb.reflection not available, SDK will not work');
                return;
            }

            if (this.platform === 'android') {
                // Android: 调用 HelpBotCocosBridge
                // @ts-ignore
                this.nativeBridge = jsb.reflection.callStaticMethod(
                    'com/example/helpbot/cocos/HelpBotCocosBridge',
                    'getInstance',
                    '()Lcom/example/helpbot/cocos/HelpBotCocosBridge;'
                );
            } else if (this.platform === 'ios') {
                // iOS: 调用 HelpBotCocosBridge
                this.nativeBridge = 'HelpBotCocosBridge'; // iOS 桥接类名
            }

            // 注册全局事件回调
            this.registerGlobalCallback();
        } catch (e) {
            console.error('[HelpBot] Native bridge init failed:', e);
        }
    }

    // ==================== 注册全局事件回调 ====================

    private registerGlobalCallback(): void {
        try {
            // @ts-ignore
            if (typeof window !== 'undefined') {
                // @ts-ignore
                window.__helpBotEventCallback = (eventName: string, dataJson?: string) => {
                    try {
                        const data = dataJson ? JSON.parse(dataJson) : undefined;
                        this.handleNativeEvent(eventName, data);
                    } catch (e) {
                        console.error('[HelpBot] Event callback error:', e);
                    }
                };
            }
        } catch (e) {
            console.error('[HelpBot] Register callback failed:', e);
        }
    }

    // ==================== 事件处理 ====================

    private eventCallbacks: HelpBotEventCallback[] = [];

    public on(callback: HelpBotEventCallback): void {
        if (typeof callback === 'function') {
            this.eventCallbacks.push(callback);
        }
    }

    public off(callback: HelpBotEventCallback): void {
        const index = this.eventCallbacks.indexOf(callback);
        if (index > -1) {
            this.eventCallbacks.splice(index, 1);
        }
    }

    private handleNativeEvent(eventName: string, data?: any): void {
        this.eventCallbacks.forEach(callback => {
            try {
                callback(eventName, data);
            } catch (e) {
                console.error('[HelpBot] Event handler error:', e);
            }
        });
    }

    // ==================== 核心 API（直接调用原生）====================

    /**
     * 安装配置
     */
    public install(config: HelpBotConfig): void {
        this.callNative('install', JSON.stringify(config));
    }

    /**
     * 用户登录
     */
    public login(token: string): void {
        this.callNative('login', token);
    }

    /**
     * 用户登出
     */
    public logout(): void {
        this.callNative('logout');
    }

    /**
     * 显示会话界面
     */
    public showConversation(): void {
        this.callNative('showConversation');
    }

    /**
     * 隐藏会话界面
     */
    public hideConversation(): void {
        this.callNative('hideConversation');
    }

    /**
     * 更新 SDK 元数据
     */
    public updateSdkMeta(meta: Record<string, any>): void {
        this.callNative('updateSdkMeta', JSON.stringify(meta));
    }

    /**
     * 更新自定义元数据
     */
    public updateCustomMeta(meta: Record<string, any>): void {
        this.callNative('updateCustomMeta', JSON.stringify(meta));
    }

    /**
     * 添加问题标签
     */
    public addIssueTags(tags: string[]): void {
        this.callNative('addIssueTags', JSON.stringify(tags));
    }

    /**
     * 移除问题标签
     */
    public removeIssueTags(tags: string[]): void {
        this.callNative('removeIssueTags', JSON.stringify(tags));
    }

    /**
     * 销毁 SDK
     */
    public destroy(): void {
        this.callNative('destroy');
    }

    // ==================== 诊断工具 ====================

    /**
     * 获取 SDK 版本
     */
    public getSdkVersion(): string {
        return this.callNative('getSdkVersion') || '';
    }

    /**
     * 检查是否已初始化
     */
    public isInitialized(): boolean {
        return this.callNative('isInitialized') === true;
    }

    /**
     * 检查会话是否可见
     */
    public isConversationVisible(): boolean {
        return this.callNative('isConversationVisible') === true;
    }

    /**
     * 清除 WebView 数据
     */
    public clearWebViewData(): void {
        this.callNative('clearWebViewData');
    }

    // ==================== 底层调用（自动判断平台）====================

    private callNative(method: string, ...args: any[]): any {
        try {
            if (!this.nativeBridge) {
                console.warn(`[HelpBot] Native bridge not initialized, cannot call ${method}`);
                return null;
            }

            if (this.platform === 'android') {
                return this.callAndroid(method, args);
            } else if (this.platform === 'ios') {
                return this.callIOS(method, args);
            } else {
                console.warn(`[HelpBot] Unknown platform, cannot call ${method}`);
                return null;
            }
        } catch (e) {
            console.error(`[HelpBot] Call native ${method} failed:`, e);
            return null;
        }
    }

    private callAndroid(method: string, args: any[]): any {
        try {
            // @ts-ignore
            const signature = this.getAndroidSignature(method, args);
            // @ts-ignore
            return jsb.reflection.callStaticMethod(
                'com/example/helpbot/cocos/HelpBotCocosBridge',
                method,
                signature,
                ...args
            );
        } catch (e) {
            console.error(`[HelpBot] Android call ${method} failed:`, e);
            return null;
        }
    }

    private callIOS(method: string, args: any[]): any {
        try {
            // @ts-ignore
            return jsb.reflection.callStaticMethod(
                'HelpBotCocosBridge',
                `${method}:`,
                ...args
            );
        } catch (e) {
            console.error(`[HelpBot] iOS call ${method} failed:`, e);
            return null;
        }
    }

    private getAndroidSignature(method: string, args: any[]): string {
        // 根据方法和参数自动生成 JNI 签名
        const signatures: Record<string, string> = {
            'install': '(Ljava/lang/String;)V',
            'login': '(Ljava/lang/String;)V',
            'logout': '()V',
            'showConversation': '()V',
            'hideConversation': '()V',
            'updateSdkMeta': '(Ljava/lang/String;)V',
            'updateCustomMeta': '(Ljava/lang/String;)V',
            'addIssueTags': '(Ljava/lang/String;)V',
            'removeIssueTags': '(Ljava/lang/String;)V',
            'destroy': '()V',
            'getSdkVersion': '()Ljava/lang/String;',
            'isInitialized': '()Z',
            'isConversationVisible': '()Z',
            'clearWebViewData': '()V'
        };
        return signatures[method] || '()V';
    }

    // ==================== 工具方法 ====================

    /**
     * 获取当前平台
     */
    public getPlatform(): string {
        return this.platform;
    }

    /**
     * 检查是否在原生环境
     */
    public isNative(): boolean {
        return this.platform !== 'unknown';
    }
}

// ==================== 导出 ====================

export default HelpBotSDK;
