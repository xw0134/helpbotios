/**
 * HelpBot Web Chat Loader - Helpshift Style
 * 轻量级加载器，自动创建和管理聊天界面
 * @version 1.0.0
 */
(function (document, scriptId) {
    'use strict';

    // 防止重复加载
    if (typeof window.HelpBot !== 'undefined') {
        console.warn('HelpBot 已经加载，跳过重复加载');
        return;
    }

    // 获取当前脚本的 URL，用于确定 SDK 的加载路径
    var scripts = document.getElementsByTagName('script');
    var currentScript = scripts[scripts.length - 1];
    var loaderUrl = currentScript.src;
    var sdkBaseUrl = loaderUrl.substring(0, loaderUrl.lastIndexOf('/'));

    // SDK 和聊天界面文件路径
    var SDK_URL = window.HelpBotConfig && window.HelpBotConfig.sdkUrl
        ? window.HelpBotConfig.sdkUrl
        : sdkBaseUrl + '/helpbot-sdk.js';

    var CHAT_WIDGET_URL = window.HelpBotConfig && window.HelpBotConfig.chatWidgetUrl
        ? window.HelpBotConfig.chatWidgetUrl
        : sdkBaseUrl + '/chat-widget.html';

    var BRIDGE_URL = window.HelpBotConfig && window.HelpBotConfig.bridgeUrl
        ? window.HelpBotConfig.bridgeUrl
        : sdkBaseUrl + '/helpbot-bridge.js';

    var LOGGER_URL = window.HelpBotConfig && window.HelpBotConfig.loggerUrl
        ? window.HelpBotConfig.loggerUrl
        : sdkBaseUrl + '/helpbot-logger.js';

    // 创建命令队列（在 SDK 加载前收集所有调用）
    var commandQueue = [];
    var sdkLoaded = false;
    var sdkInstance = null;
    var chatIframe = null;
    var chatBubble = null;
    var chatOpen = false;
    var issueData = null; // 保存从 getMyIssue 返回的数据（包括历史消息）
    var logger = null; // Logger 实例

    // 自动重连相关状态
    var backgroundTime = null;           // 进入后台的时间
    var lastActiveCheck = 0;             // 最后一次检查时间（防抖）
    var reconnectAttempts = 0;           // 重连尝试次数
    var maxReconnectAttempts = 3;        // 最大重连次数
    var isReconnecting = false;          // 是否正在重连
    var needsSSEConnection = false;      // 是否需要在发送消息后连接 SSE

    /**
     * HelpBot 全局函数
     * 在 SDK 加载前，所有调用都会进入队列
     * SDK 加载后，直接执行相应的方法
     */
    window.HelpBot = function (command) {
        var args = Array.prototype.slice.call(arguments, 1);

        if (!sdkLoaded && command !== 'getStatus') {
            // SDK 未加载，加入队列
            commandQueue.push({ command: command, args: args });
            return;
        }

        // SDK 已加载，执行命令
        return executeCommand(command, args);
    };

    /**
     * 执行命令
     */
    function executeCommand(command, args) {
        try {
            switch (command) {
                case 'init':
                    return initializeSDK(args[0]);
                case 'connect':
                    connectToServer();
                    break;
                case 'open':
                    return openChat();
                case 'close':
                    return closeChat();
                case 'toggle':
                    return toggleChat();
                case 'sendMessage':
                    sendMessage(args[0]);
                    break;
                case 'uploadFile':
                    return uploadFile(args[0]);
                case 'sendFileMessage':
                    return sendFileMessage(args[0]);
                case 'setToken':
                    return setToken(args[0], args[1]);
                case 'setTokenAndConnect':
                    return setTokenAndConnect(args[0]);
                case 'updateUserMeta':
                    return updateUserMeta(args[0]);
                case 'updateUserSdkMeta':
                    return updateUserSdkMeta(args[0]);
                case 'addIssueTags':
                    return addIssueTags(args[0]);
                case 'removeIssueTags':
                    return removeIssueTags(args[0]);
                case 'destroy':
                    return destroySDK();
                case 'getStatus':
                    return getStatus();
                case 'getHistoryMessages':
                    return getHistoryMessages();
                case 'loadMoreMessages':
                    return loadMoreMessages(args[0], args[1]);
                case 'on':
                    return addEventListener(args[0], args[1]);
                case 'off':
                    return removeEventListener(args[0], args[1]);
                case 'handleSSEMessage':
                    return handleSSEMessage(args[0]);
                case 'handleNativeError':
                    return handleNativeError(args[0]);
                case 'exportLogs':
                    return exportLogs(args[0]);
                case 'clearLogs':
                    return clearLogs();
                default:
                    console.warn('未知的 HelpBot 命令:', command);
            }
        } catch (error) {
            console.error('HelpBot 命令执行失败:', error);
        }
    }

    /**
     * 处理从 Native 接收的 SSE 消息
     */
    function handleSSEMessage(message) {
        try {
            console.log('[HelpBot] 收到 Native 推送的 SSE 消息:', message);
            // 触发消息事件，让 iframe 处理
            handleRealtimeMessage(message);
            return true;
        } catch (error) {
            console.error('[HelpBot] 处理 SSE 消息失败:', error);
            return false;
        }
    }

    /**
     * 处理从 Native 接收的错误通知
     */
    function handleNativeError(error) {
        try {
            console.error('[HelpBot] 收到 Native 的错误通知:', error);
            triggerEvent('error', error);
            return true;
        } catch (err) {
            console.error('[HelpBot] 处理 Native 错误失败:', err);
            return false;
        }
    }

    /**
     * 创建聊天 UI
     */
    function createChatUI() {
        if (chatIframe || chatBubble) {
            console.warn('聊天 UI 已经创建');
            return;
        }

        // 创建样式
        var style = document.createElement('style');
        style.textContent = `
            /* HelpBot 聊天气泡 */
            .helpbot-chat-bubble {
                position: fixed !important;
                bottom: 20px !important;
                right: 20px !important;
                width: 60px !important;
                height: 60px !important;
                min-width: 60px !important;
                min-height: 60px !important;
                max-width: 60px !important;
                max-height: 60px !important;
                background: linear-gradient(135deg, #667eea, #764ba2) !important;
                border-radius: 50% !important;
                display: flex !important;
                align-items: center !important;
                justify-content: center !important;
                cursor: pointer !important;
                box-shadow: 0 4px 20px rgba(102, 126, 234, 0.4) !important;
                transition: all 0.3s ease !important;
                z-index: 999999 !important;
                border: none !important;
                padding: 0 !important;
                margin: 0 !important;
                font-size: 24px !important;
                color: white !important;
            }

            .helpbot-chat-bubble:hover {
                transform: scale(1.1) !important;
                box-shadow: 0 6px 25px rgba(102, 126, 234, 0.6) !important;
            }

            .helpbot-chat-bubble-icon {
                width: 24px !important;
                height: 24px !important;
                flex-shrink: 0 !important;
            }

            /* 隐藏气泡样式（WebView 模式） */
            .helpbot-chat-bubble.hidden {
                display: none !important;
            }

            /* HelpBot 聊天窗口 */
            .helpbot-chat-iframe {
                position: fixed;
                bottom: 20px;
                right: 20px;
                width: 375px;
                height: 667px;
                border: none;
                border-radius: 12px;
                box-shadow: 0 4px 20px rgba(0,0,0,0.15);
                z-index: 999998;
                display: none;
                background: white;
                transition: all 0.3s ease;
            }

            .helpbot-chat-iframe.helpbot-open {
                display: block;
                animation: helpbot-slideIn 0.3s ease;
            }

            @keyframes helpbot-slideIn {
                from {
                    opacity: 0;
                    transform: translateY(20px);
                }
                to {
                    opacity: 1;
                    transform: translateY(0);
                }
            }

            /* 全屏模式（WebView 模式） */
            .helpbot-chat-iframe.fullscreen {
                top: 0 !important;
                left: 0 !important;
                right: 0 !important;
                bottom: 0 !important;
                width: 100% !important;
                height: 100% !important;
                border-radius: 0 !important;
                box-shadow: none !important;
            }

            /* 响应式 */
            @media (max-width: 480px) {
                .helpbot-chat-iframe:not(.fullscreen) {
                    width: calc(100vw - 40px);
                    height: calc(100vh - 40px);
                    bottom: 20px;
                    right: 20px;
                }
            }
        `;
        document.head.appendChild(style);

        // 获取配置
        var config = window.HelpBotConfig || {};

        // 根据配置决定是否创建聊天气泡
        if (config.hideBubble !== true) {
            // 创建聊天气泡
            chatBubble = document.createElement('button');
            chatBubble.className = 'helpbot-chat-bubble';
            chatBubble.innerHTML = `
                <svg class="helpbot-chat-bubble-icon" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 14H6l-2 2V4h16v12z"/>
                </svg>
            `;
            chatBubble.onclick = toggleChat;
            chatBubble.setAttribute('aria-label', '打开客服聊天');
            document.body.appendChild(chatBubble);

            console.log('HelpBot 聊天气泡已创建');
        } else {
            console.log('HelpBot 聊天气泡已隐藏（WebView 模式）');
        }

        // 创建聊天 iframe（始终创建）
        chatIframe = document.createElement('iframe');
        chatIframe.className = 'helpbot-chat-iframe';

        // 根据配置添加全屏样式
        // 当 hideBubble 为 true 时，自动启用全屏模式（WebView 场景）
        if (config.fullscreen === true || config.hideBubble === true) {
            chatIframe.classList.add('fullscreen');
            if (config.hideBubble === true && config.fullscreen !== true) {
                console.log('HelpBot 聊天窗口自动设置为全屏模式（hideBubble 启用）');
            } else {
                console.log('HelpBot 聊天窗口设置为全屏模式');
            }
        }

        chatIframe.src = CHAT_WIDGET_URL;
        chatIframe.setAttribute('title', 'HelpBot 客服聊天');
        chatIframe.setAttribute('allow', 'camera; microphone');
        document.body.appendChild(chatIframe);

        console.log('HelpBot 聊天 UI 已创建');
    }

    /**
     * 初始化 SDK
     */
    function initializeSDK(customConfig) {
        if (sdkInstance) {
            console.warn('HelpBot SDK 已经初始化');
            return false;
        }

        // 合并配置
        var config = Object.assign({}, window.HelpBotConfig || {}, customConfig || {});

        // 验证必填配置（根据模式不同，要求的字段不同）
        var requiredFields = ['baseURL', 'channelId'];

        // 开发模式需要额外字段
        if (config.useDevAPI === true) {
            requiredFields.push('companyId', 'userId');
        }

        for (var i = 0; i < requiredFields.length; i++) {
            if (!config[requiredFields[i]]) {
                throw new Error('HelpBot 配置缺少必填字段: ' + requiredFields[i]);
            }
        }

        // 创建 SDK 实例
        sdkInstance = new window.HelpBotSDK(config);

        console.log('HelpBot SDK 初始化成功');


        return true;
    }

    /**
     * 连接到服务器（认证、登录、连接实时消息）
     */
    function connectToServer() {
        if (!sdkInstance) {
            throw new Error('SDK 未初始化，请先调用 init');
        }
        // 自动认证和连接
        autoInitialize();
    }

    /**
     * 自动认证和连接
     */
    async function autoInitialize() {
        try {
            var log = logger || { info: console.log.bind(console), error: console.error.bind(console), debug: console.log.bind(console) };

            log.info('[HelpBot] 开始自动初始化...');

            // 1. 获取 token
            log.debug('[HelpBot] 步骤 1/4: 获取 token...');
            await sdkInstance.getToken();
            log.info('[HelpBot] ✅ Token 获取成功');

            // 2. 用户登录
            log.debug('[HelpBot] 步骤 2/4: 用户登录...');
            var loginResult = await sdkInstance.login({ full_privacy_mode: true });
            log.info('[HelpBot] ✅ 用户登录成功', loginResult);

            // 检查是否需要创建新 issue
            // 情况1: login 返回 have_issue = false，说明用户没有 issue，跳过获取会话步骤
            // 情况2: issue status 为 3(已解决) 或 4(已拒绝)，表示没有活跃的 issue
            // 以上两种情况都需要用户发送消息创建新 issue
            var needsNewIssue = false;

            // 检查 login 返回的 have_issue 字段
            if (loginResult && loginResult.haveIssue === false) {
                log.warn('[HelpBot] ⚠️ 用户没有 Issue (have_issue=false)，跳过获取会话，需要创建新会话');
                needsNewIssue = true;
                needsSSEConnection = true; // 标记需要在发送消息后连接 SSE
                issueData = null; // 设置为 null，表示没有会话数据
            } else {
                // 3. 获取会话（包括历史消息）
                log.debug('[HelpBot] 步骤 3/4: 获取会话...');
                issueData = await sdkInstance.getMyIssue();
                log.info('[HelpBot] ✅ 会话获取成功', issueData);

                // 检查 issue status
                if (issueData && (issueData.status === 3 || issueData.status === 4)) {
                    log.warn('[HelpBot] ⚠️ Issue 状态为 ' + issueData.status + ' (已解决/已拒绝)，需要创建新会话');
                    needsNewIssue = true;
                    needsSSEConnection = true; // 标记需要在发送消息后连接 SSE
                }
            }

            // 4. 连接实时消息（仅当有活跃 issue 时）
            if (!needsNewIssue && issueData && issueData.issueId) {
                log.debug('[HelpBot] 步骤 4/4: 连接实时消息...');
                await sdkInstance.connectRealtime(
                    handleRealtimeMessage,
                    handleRealtimeError
                );
                log.info('[HelpBot] ✅ 实时消息连接成功');
            } else {
                log.info('[HelpBot] 跳过 SSE 连接，等待用户发送消息创建新会话');
            }

            log.info('[HelpBot] ✅ 自动初始化完成');

            // 触发就绪事件
            triggerEvent('ready', {
                sdk: sdkInstance,
                historyMessages: issueData ? issueData.messages : [],
                needsNewIssue: needsNewIssue,
                issueStatus: issueData ? issueData.status : null,
                issueId: issueData ? issueData.issueId : null
            });

            // 通知 Native SDK 就绪
            if (window.HelpBotBridge) {
                window.HelpBotBridge.notifySDKReady({
                    historyMessages: issueData ? issueData.messages : [],
                    needsNewIssue: needsNewIssue,
                    issueStatus: issueData ? issueData.status : null,
                    issueId: issueData ? issueData.issueId : null
                });
            }

            // 通知 Native 对话状态
            if (window.HelpBotBridge && issueData && issueData.issueId) {
                window.HelpBotBridge.notifyConversationStatus(
                    issueData.issueId,
                    issueData.status !== 3 && issueData.status !== 4 // 不是已解决或已拒绝状态
                );
            }

        } catch (error) {
            var log = logger || { error: console.error.bind(console) };

            log.error('[HelpBot] ❌ 自动初始化失败', error);

            // 重置连接状态，允许用户重试
            isConnecting = false;

            // 触发错误事件，包含详细信息
            triggerEvent('error', {
                message: error.message || '未知错误',
                code: error.code || 'UNKNOWN_ERROR',
                details: error.details || null,
                stack: error.stack || null
            });

            // 通知 Native 发生错误
            if (window.HelpBotBridge) {
                window.HelpBotBridge.notifySDKError({
                    message: error.message || '未知错误',
                    code: error.code || 'UNKNOWN_ERROR',
                    details: error.details || null
                });
            }

            // 如果是认证失败，通知 Native
            if (window.HelpBotBridge &&
                (error.code === 'NOT_AUTHENTICATED' ||
                    error.code === 'TOKEN_EXPIRED' ||
                    error.code === 'TOKEN_REFRESH_FAILED')) {
                window.HelpBotBridge.sendUserAuthFailureEvent(error.code);
            }
        }
    }

    /**
     * 处理实时消息
     */
    function handleRealtimeMessage(message) {
        triggerEvent('message', { message: message });

        // 通知 Native 收到新消息
        if (window.HelpBotBridge && message) {
            if (message.type === 'message.new' && message.data) {
                // 判断是客服消息还是用户消息
                if (message.data.is_staff) {
                    window.HelpBotBridge.notifyAgentMessageReceived({
                        body: message.data.body?.body || '',
                        author: message.data.author || 'Agent',
                        created_at: message.data.created_at,
                        id: message.data.id
                    });
                } else {
                    window.HelpBotBridge.notifyUserMessageSend({
                        body: message.data.body?.body || '',
                        created_at: message.data.created_at,
                        id: message.data.id
                    });
                }
            }
        }

        // 如果聊天窗口关闭，显示新消息提示（可以添加气泡上的红点）
        if (!chatOpen && message.type === 'message.new' && message.data && !message.data.is_staff) {
            // 可以在这里添加未读消息提示
        }
    }

    /**
     * 处理实时连接错误
     */
    function handleRealtimeError(error) {
        triggerEvent('error', { error: error });
    }

    /**
     * 打开聊天窗口
     */
    var isFirstOpen = true;
    var isConnecting = false;

    function openChat() {
        if (!chatIframe) {
            console.warn('聊天界面未创建');
            return false;
        }

        chatIframe.classList.add('helpbot-open');
        chatOpen = true;

        // 首次打开时，如果还没连接服务器，则开始连接
        if (isFirstOpen && sdkInstance && !isConnecting) {
            isFirstOpen = false;
            isConnecting = true;
            console.log('首次打开聊天，开始连接服务器...');
            connectToServer();
        }

        triggerEvent('open');

        // 通知 Native 聊天窗口已打开
        if (window.HelpBotBridge) {
            window.HelpBotBridge.notifyWidgetToggle(true);
        }
        return true;
    }

    /**
     * 关闭聊天窗口
     */
    function closeChat() {
        if (!chatIframe) return false;

        chatIframe.classList.remove('helpbot-open');
        chatOpen = false;

        // 气泡图标保持不变（始终显示聊天图标）

        triggerEvent('close');

        // 通知 Native 聊天窗口已关闭
        if (window.HelpBotBridge) {
            window.HelpBotBridge.notifyWidgetToggle(false);
        }
        return true;
    }

    /**
     * 切换聊天窗口
     */
    function toggleChat() {
        return chatOpen ? closeChat() : openChat();
    }

    /**
     * 发送消息
     */
    async function sendMessage(message) {
        if (!sdkInstance) {
            var log = logger || { warn: console.warn.bind(console) };
            log.warn('HelpBot SDK 未初始化');
            return;
        }

        try {
            var log = logger || { info: console.log.bind(console), error: console.error.bind(console) };
            var result = await sdkInstance.sendMessage(message);
            log.info('[HelpBot] 消息发送成功', result);

            // 如果需要连接 SSE（第一次发送消息创建了新 issue）
            if (needsSSEConnection && result.issueId) {
                log.info('[HelpBot] 检测到新 issue 创建，开始连接 SSE...');
                needsSSEConnection = false; // 重置标记

                try {
                    await sdkInstance.connectRealtime(
                        handleRealtimeMessage,
                        handleRealtimeError
                    );
                    log.info('[HelpBot] ✅ SSE 连接成功');
                    triggerEvent('sseConnected', { issueId: result.issueId });
                } catch (sseError) {
                    log.error('[HelpBot] SSE 连接失败', sseError);
                    triggerEvent('error', { error: sseError });
                }
            }

            triggerEvent('messageSent', { result: result });
            return result;
        } catch (error) {
            var log = logger || { error: console.error.bind(console) };
            log.error('发送消息失败', error);
            triggerEvent('error', { error: error });
            throw error;
        }
    }

    /**
     * 设置Token
     * @param {string} token - 客户端生成的token
     * @param {boolean} autoConnect - 是否自动连接（可选）
     */
    function setToken(token, autoConnect) {
        if (!token || typeof token !== 'string') {
            console.error('HelpBot setToken: token必须是非空字符串');
            return false;
        }

        console.log('HelpBot 设置token:', token.substring(0, 20) + '...');

        // 如果SDK已初始化，调用SDK的setToken方法
        if (sdkInstance && typeof sdkInstance.setToken === 'function') {
            sdkInstance.setToken(token);
        } else {
            // SDK未初始化，更新配置
            if (!window.HelpBotConfig) {
                window.HelpBotConfig = {};
            }
            window.HelpBotConfig.preGeneratedToken = token;
            console.log('HelpBot token已保存到配置，等待SDK初始化');
        }

        triggerEvent('tokenSet', { token: token });

        // 检查是否需要自动连接
        // 优先级：1. 参数指定 2. 配置项 autoConnectAfterSetToken
        var shouldAutoConnect = autoConnect !== undefined
            ? autoConnect
            : (window.HelpBotConfig && window.HelpBotConfig.autoConnectAfterSetToken);

        if (shouldAutoConnect) {
            console.log('HelpBot 自动连接服务器...');
            connectToServer();
        }

        return true;
    }

    /**
     * 设置Token并自动连接
     * @param {string} token - 客户端生成的token
     */
    function setTokenAndConnect(token) {
        return setToken(token, true);
    }

    /**
     * 上传文件（从 base64 数据）
     */
    async function uploadFile(fileData) {
        if (!sdkInstance) {
            throw new Error('HelpBot SDK 未初始化');
        }

        try {
            // 从 base64 重建 File 对象
            var byteString = atob(fileData.data.split(',')[1]);
            var ab = new ArrayBuffer(byteString.length);
            var ia = new Uint8Array(ab);
            for (var i = 0; i < byteString.length; i++) {
                ia[i] = byteString.charCodeAt(i);
            }
            var blob = new Blob([ab], { type: fileData.type });
            var file = new File([blob], fileData.name, { type: fileData.type });

            var result = await sdkInstance.uploadFile(file);
            return result;
        } catch (error) {
            console.error('上传文件失败:', error);
            throw error;
        }
    }

    /**
     * 发送文件消息
     */
    async function sendFileMessage(fileInfo) {
        if (!sdkInstance) {
            throw new Error('HelpBot SDK 未初始化');
        }

        try {
            var result = await sdkInstance.sendFileMessage(fileInfo, 3);
            triggerEvent('messageSent', { result: result });
            return result;
        } catch (error) {
            console.error('发送文件消息失败:', error);
            throw error;
        }
    }

    /**
     * 更新用户自定义 Meta 数据
     */
    async function updateUserMeta(metaData) {
        if (!sdkInstance) {
            throw new Error('HelpBot SDK 未初始化');
        }

        try {
            var result = await sdkInstance.updateUserMeta(metaData);
            console.log('用户 Meta 更新成功:', result);
            return result;
        } catch (error) {
            console.error('更新用户 Meta 失败:', error);
            throw error;
        }
    }

    /**
     * 更新用户 SDK Meta 数据
     */
    async function updateUserSdkMeta(sdkMetaData) {
        if (!sdkInstance) {
            throw new Error('HelpBot SDK 未初始化');
        }

        try {
            var result = await sdkInstance.updateUserSdkMeta(sdkMetaData);
            console.log('SDK Meta 更新成功:', result);
            return result;
        } catch (error) {
            console.error('更新 SDK Meta 失败:', error);
            throw error;
        }
    }

    /**
     * 给 Issue 添加 Tags
     */
    async function addIssueTags(tags) {
        if (!sdkInstance) {
            throw new Error('HelpBot SDK 未初始化');
        }

        try {
            var result = await sdkInstance.addIssueTags(tags);
            console.log('Issue Tags 添加成功:', result);
            return result;
        } catch (error) {
            console.error('添加 Issue Tags 失败:', error);
            throw error;
        }
    }

    /**
     * 从 Issue 删除 Tags
     */
    async function removeIssueTags(tags) {
        if (!sdkInstance) {
            throw new Error('HelpBot SDK 未初始化');
        }

        try {
            var result = await sdkInstance.removeIssueTags(tags);
            console.log('Issue Tags 删除成功:', result);
            return result;
        } catch (error) {
            console.error('删除 Issue Tags 失败:', error);
            throw error;
        }
    }

    /**
     * 获取状态
     */
    function getStatus() {
        if (!sdkInstance) {
            return {
                loaded: sdkLoaded,
                initialized: false,
                chatOpen: chatOpen
            };
        }

        return Object.assign({
            loaded: sdkLoaded,
            initialized: true,
            chatOpen: chatOpen
        }, sdkInstance.getStatus());
    }

    /**
     * 获取历史消息（返回完整数据，包括 hasMore 和 status）
     */
    function getHistoryMessages() {
        if (!issueData) {
            return {
                messages: [],
                hasMore: false,
                issueId: null,
                status: null
            };
        }

        return {
            messages: issueData.messages || [],
            hasMore: issueData.hasMore || false,
            issueId: issueData.issueId || null,
            status: issueData.status || null
        };
    }

    /**
     * 加载更多历史消息
     */
    async function loadMoreMessages(limit, offset) {
        if (!sdkInstance) {
            throw new Error('HelpBot SDK 未初始化');
        }

        if (!issueData || !issueData.issueId) {
            throw new Error('没有可用的 Issue ID');
        }

        try {
            var result = await sdkInstance.getMessageHistory(issueData.issueId, limit, offset);
            return result;
        } catch (error) {
            console.error('加载更多消息失败:', error);
            throw error;
        }
    }

    /**
     * 销毁 SDK
     */
    function destroySDK() {
        if (sdkInstance) {
            sdkInstance.destroy();
            sdkInstance = null;
        }

        // 移除 UI
        if (chatIframe) {
            chatIframe.remove();
            chatIframe = null;
        }
        if (chatBubble) {
            chatBubble.remove();
            chatBubble = null;
        }

        triggerEvent('destroyed');
        return true;
    }

    /**
     * 事件监听器管理
     */
    var eventListeners = {};

    function addEventListener(eventType, callback) {
        if (typeof eventType !== 'string' || !eventType) {
            console.error('HelpBot on: eventType 必须是字符串');
            return false;
        }
        if (typeof callback !== 'function') {
            console.error('HelpBot on: callback 必须是函数');
            return false;
        }

        if (!eventListeners[eventType]) {
            eventListeners[eventType] = [];
        }
        eventListeners[eventType].push(callback);
        return true;
    }

    function removeEventListener(eventType, callback) {
        if (typeof eventType !== 'string' || !eventType) {
            console.error('HelpBot off: eventType 必须是字符串');
            return false;
        }

        if (!eventListeners[eventType]) return false;

        if (callback) {
            var index = eventListeners[eventType].indexOf(callback);
            if (index > -1) {
                eventListeners[eventType].splice(index, 1);
                if (eventListeners[eventType].length === 0) {
                    delete eventListeners[eventType];
                }
                return true;
            }
            return false;
        } else {
            delete eventListeners[eventType];
            return true;
        }
    }

    function triggerEvent(eventType, data) {
        var listeners = eventListeners[eventType] || [];
        listeners.forEach(function (callback) {
            try {
                callback(data || {});
            } catch (error) {
                console.error('HelpBot 事件监听器错误:', error);
            }
        });

        // 🔔 新增：错误事件自动通知 Native 客户端
        if (eventType === 'error' && typeof window.HelpBotBridge !== 'undefined') {
            try {
                var error = data.error || data;
                var errorCode = error.code || 'UNKNOWN_ERROR';
                var errorMessage = error.message || String(error);

                // 判断是否需要通知 Native（关键错误）
                var criticalErrors = [
                    'NETWORK_ERROR',
                    'TOKEN_REFRESH_FAILED',
                    'NOT_AUTHENTICATED',
                    'HTTP_ERROR',
                    'REQUEST_TIMEOUT',
                    'SDK_LOAD_FAILED',
                    'INVALID_TOKEN_RESPONSE',
                    'INVALID_LOGIN_RESPONSE'
                ];

                // 只通知关键错误
                if (criticalErrors.indexOf(errorCode) !== -1 ||
                    errorMessage.indexOf('network error') !== -1 ||
                    errorMessage.indexOf('认证失败') !== -1) {

                    window.HelpBotBridge.notifySDKError({
                        CODE: errorCode,
                        MESSAGE: errorMessage,
                        DETAILS: error.details || null,
                        TIMESTAMP: new Date().toISOString()
                    });

                    console.log('[HelpBot] 已通知 Native 客户端错误:', errorCode);
                }
            } catch (bridgeError) {
                console.warn('[HelpBot] 通知 Native 错误失败:', bridgeError);
            }
        }
    }

    /**
     * 导出日志
     * @param {Object} options - 选项
     * @returns {Object} 日志数据
     */
    function exportLogs(options) {
        options = options || {};

        if (!logger) {
            return { error: 'Logger 未初始化' };
        }

        var logs = logger.getLocalLogs(options.limit);

        // 可以按级别过滤
        var filteredLogs = logs;
        if (options.level) {
            filteredLogs = logs.filter(function (log) {
                return log.level === options.level;
            });
        }

        return {
            logs: filteredLogs,
            count: filteredLogs.length,
            sessionId: logger.context.sessionId,
            userId: logger.context.userId,
            exportTime: new Date().toISOString()
        };
    }

    /**
     * 清空日志
     */
    function clearLogs() {
        if (!logger) {
            console.warn('HelpBot Logger 未初始化，无法清空日志');
            return false;
        }
        logger.clearLocalLogs();
        return true;
    }

    /**
     * 动态加载 Bridge 脚本
     */
    function loadBridge() {
        return new Promise(function (resolve, reject) {
            // 检查是否已经加载
            if (window.HelpBotBridge) {
                console.log('HelpBot Bridge 已存在');
                resolve();
                return;
            }

            // 检查是否已经存在加载标记
            if (document.getElementById('helpbot-bridge-script')) {
                console.warn('HelpBot Bridge 脚本已经在加载中');
                return;
            }

            var script = document.createElement('script');
            script.id = 'helpbot-bridge-script';
            script.src = BRIDGE_URL;
            script.async = true;

            script.onload = function () {
                console.log('HelpBot Bridge 脚本加载成功');

                // 启用调试模式（如果配置了）
                if (window.HelpBotConfig && window.HelpBotConfig.debugBridge === true) {
                    window.HelpBotBridge.setDebugMode(true);
                }

                resolve();
            };

            script.onerror = function () {
                console.warn('HelpBot Bridge 脚本加载失败（非关键错误，继续运行）:', BRIDGE_URL);
                resolve(); // 即使失败也继续，因为 bridge 不是必需的
            };

            var firstScript = document.getElementsByTagName('script')[0];
            firstScript.parentNode.insertBefore(script, firstScript);
        });
    }

    /**
     * 动态加载 Logger 脚本
     */
    function loadLogger() {
        return new Promise(function (resolve, reject) {
            // 检查是否已经加载
            if (window.HelpBotLogger) {
                console.log('HelpBot Logger 已存在');
                resolve();
                return;
            }

            var script = document.createElement('script');
            script.id = 'helpbot-logger-script';
            script.src = LOGGER_URL;
            script.async = true;

            script.onload = function () {
                console.log('HelpBot Logger 脚本加载成功');
                resolve();
            };

            script.onerror = function () {
                console.error('HelpBot Logger 脚本加载失败，使用降级方案');
                // 降级：使用 console
                window.HelpBotLogger = function () {
                    return {
                        debug: console.debug.bind(console),
                        info: console.info.bind(console),
                        warn: console.warn.bind(console),
                        error: console.error.bind(console),
                        fatal: console.error.bind(console),
                        logApiCall: function () { },
                        startTimer: function () { return function () { }; },
                        getLocalLogs: function () { return []; },
                        clearLocalLogs: function () { },
                        context: { sessionId: null, userId: null }
                    };
                };
                window.LogLevel = { DEBUG: 0, INFO: 1, WARN: 2, ERROR: 3, FATAL: 4 };
                resolve();
            };

            var firstScript = document.getElementsByTagName('script')[0];
            firstScript.parentNode.insertBefore(script, firstScript);
        });
    }

    /**
     * 初始化 Logger
     */
    function initLogger() {
        // 等待 Logger 加载完成
        if (typeof window.HelpBotLogger === 'undefined') {
            setTimeout(initLogger, 100);
            return;
        }

        // 获取配置
        var config = window.HelpBotConfig || {};

        // 创建 Logger 实例
        logger = new window.HelpBotLogger({
            appId: config.channelId || 'helpbot-sdk',

            // 日志级别：开发环境 DEBUG，生产环境 WARN
            minLevel: config.logLevel !== undefined
                ? config.logLevel
                : (config.useDevAPI ? window.LogLevel.DEBUG : window.LogLevel.WARN),

            // 控制台输出：开发环境开启，生产环境关闭
            enableConsole: config.enableConsoleLog !== undefined
                ? config.enableConsoleLog
                : (config.useDevAPI ? true : false),

            // 本地存储：始终开启
            enableLocalStorage: true,
            maxLocalLogs: 100,

            // 远程上报：生产环境开启
            enableRemote: config.logEndpoint ? true : false,
            logEndpoint: config.logEndpoint || null,
            batchSize: 10,
            flushInterval: 30000
        });

        // 设置用户上下文
        if (config.userId) {
            logger.setUserId(config.userId);
        }

        // 暴露到全局（供 SDK 使用）
        window.HelpBotSDKLogger = logger;

        console.log('✅ HelpBot Logger 已初始化');
    }

    /**
     * 动态加载 SDK 脚本
     */
    function loadSDK() {
        // 检查是否已经存在加载标记
        if (document.getElementById(scriptId)) {
            console.warn('HelpBot SDK 脚本已经在加载中');
            return;
        }

        // 先加载 Logger，再加载 Bridge，最后加载 SDK
        loadLogger().then(function () {
            // 初始化 Logger
            initLogger();

            // 然后加载 Bridge
            return loadBridge();
        }).then(function () {
            var script = document.createElement('script');
            script.id = scriptId;
            script.src = SDK_URL;
            script.async = true;

            // SDK 加载成功
            script.onload = function () {
                console.log('HelpBot SDK 脚本加载成功');
                sdkLoaded = true;

                // 执行队列中的命令
                commandQueue.forEach(function (item) {
                    executeCommand(item.command, item.args);
                });
                commandQueue = [];

                // 总是创建聊天 UI（气泡和 iframe）
                createChatUI();

                // ✅ 设置页面可见性监听器（用于自动重连）
                setupVisibilityListener();

                // 如果配置了自动初始化，则立即初始化 SDK 并连接服务器
                if (window.HelpBotConfig && window.HelpBotConfig.autoInit !== false) {
                    window.HelpBot('init');
                    // 标记已经连接，避免首次打开时重复连接
                    isFirstOpen = false;
                    isConnecting = true;
                    connectToServer();
                } else {
                    // autoInit: false，只初始化 SDK，不连接服务器
                    window.HelpBot('init');
                    console.log('HelpBot SDK 已初始化，等待用户打开聊天窗口...');
                }
            };

            // SDK 加载失败
            script.onerror = function () {
                console.error('[HelpBot] ❌ SDK 脚本加载失败:', SDK_URL);
                console.error('[HelpBot] 可能的原因:');
                console.error('  1. 网络连接问题');
                console.error('  2. 文件路径错误');
                console.error('  3. WebView 安全策略阻止了脚本加载');
                console.error('  4. CORS 跨域限制');

                triggerEvent('error', {
                    message: 'SDK 脚本加载失败',
                    code: 'SDK_LOAD_FAILED',
                    details: {
                        url: SDK_URL,
                        possibleReasons: [
                            '网络连接问题',
                            '文件路径错误',
                            'WebView 安全策略阻止',
                            'CORS 跨域限制'
                        ]
                    }
                });
            };

            // 插入到页面
            var firstScript = document.getElementsByTagName('script')[0];
            firstScript.parentNode.insertBefore(script, firstScript);
        });
    }

    // 监听来自 iframe 的消息（处理 chat-widget.html 的请求）
    window.addEventListener('message', function (event) {
        var message = event.data;

        // 只处理 helpbot-command 类型的消息
        if (message.type !== 'helpbot-command') {
            return;
        }

        var command = message.command;
        var data = message.data;
        var id = message.id;

        // 处理命令并返回结果
        handleIframeCommand(command, data).then(function (result) {
            event.source.postMessage({
                type: 'helpbot-response',
                id: id,
                result: result
            }, '*');
        }).catch(function (error) {
            event.source.postMessage({
                type: 'helpbot-response',
                id: id,
                error: error.message || '命令执行失败'
            }, '*');
        });
    });

    // 序列化事件数据（移除不能被 postMessage 克隆的内容）
    function serializeEventData(eventData) {
        if (!eventData || typeof eventData !== 'object') {
            return eventData;
        }

        // 创建一个新对象，只包含可序列化的数据
        var result = {};

        for (var key in eventData) {
            if (eventData.hasOwnProperty(key)) {
                var value = eventData[key];
                var type = typeof value;

                // 跳过函数、undefined、symbol
                if (type === 'function' || type === 'undefined' || type === 'symbol') {
                    continue;
                }

                // 跳过 SDK 实例
                if (key === 'sdk') {
                    continue;
                }

                // 特殊处理 Error 对象
                if (value instanceof Error) {
                    result[key] = {
                        message: value.message || '未知错误',
                        code: value.code || 'UNKNOWN_ERROR',
                        name: value.name || 'Error',
                        stack: value.stack || null
                    };
                    continue;
                }

                // 递归处理嵌套对象
                if (type === 'object' && value !== null) {
                    try {
                        // 尝试 JSON 序列化来检测是否可克隆
                        JSON.stringify(value);
                        result[key] = value;
                    } catch (e) {
                        // 无法序列化，跳过
                        console.warn('[HelpBot] 无法序列化字段:', key, e);
                    }
                } else {
                    result[key] = value;
                }
            }
        }

        return result;
    }

    // ==================== 前后台切换和自动重连 ====================

    /**
     * 设置页面可见性监听器
     * 监听页面从后台切回前台的事件
     */
    function setupVisibilityListener() {
        console.log('[自动重连] 设置页面可见性监听器');

        // 监听页面可见性变化（主要方式）
        document.addEventListener('visibilitychange', function () {
            if (document.visibilityState === 'visible') {
                console.log('[自动重连] 页面回到前台 (visibilitychange)');
                onAppBecomeActive();
            } else if (document.visibilityState === 'hidden') {
                console.log('[自动重连] 页面进入后台 (visibilitychange)');
                onAppBecomeInactive();
            }
        });

        // iOS Safari 兼容：监听 pageshow 事件
        window.addEventListener('pageshow', function (event) {
            // event.persisted 表示页面是从缓存中恢复的
            if (event.persisted) {
                console.log('[自动重连] 页面从缓存恢复 (iOS pageshow)');
                onAppBecomeActive();
            }
        });

        // 监听窗口获得焦点（备用方式）
        window.addEventListener('focus', function () {
            console.log('[自动重连] 窗口获得焦点 (focus)');
            // 使用防抖，避免与 visibilitychange 重复触发
            setTimeout(function () { onAppBecomeActive(); }, 100);
        });

        console.log('[自动重连] 监听器设置完成');
    }

    /**
     * 应用回到前台时的处理
     * 检查连接状态，如果断开则自动重连
     */
    async function onAppBecomeActive() {
        console.log('[自动重连] ========== 应用回到前台 ==========');

        // 防止短时间内重复执行（100ms 内只执行一次）
        var now = Date.now();
        if (lastActiveCheck && now - lastActiveCheck < 100) {
            console.log('[自动重连] 跳过重复检查（防抖）');
            return;
        }
        lastActiveCheck = now;

        // 检查是否已初始化
        if (!sdkInstance) {
            console.log('[自动重连] SDK 未初始化，跳过重连');
            return;
        }

        // 计算后台时长
        var backgroundDuration = 0;
        if (backgroundTime) {
            backgroundDuration = now - backgroundTime;
            console.log('[自动重连] 后台时长: ' + Math.round(backgroundDuration / 1000) + '秒');
        }

        // 获取当前连接状态
        var status = sdkInstance.getStatus();
        console.log('[自动重连] 当前状态:', {
            authenticated: status.authenticated,
            realtimeConnected: status.realtimeConnected,
            hasIssue: status.hasIssue
        });

        // 如果后台时间超过 5 分钟，刷新全部数据
        if (backgroundDuration > 5 * 60 * 1000) {
            console.log('[自动重连] 后台时间较长（>5分钟），刷新全部数据');
            await refreshAllData();
        } else {
            // 只检查并重连 SSE
            await reconnectIfNeeded();
        }

        console.log('[自动重连] ========== 处理完成 ==========');
    }

    /**
     * 应用进入后台时的处理
     * 记录时间，用于判断后台时长
     */
    function onAppBecomeInactive() {
        console.log('[自动重连] 应用进入后台');
        backgroundTime = Date.now();
    }

    /**
     * 检查连接状态，如果断开则重连
     */
    async function reconnectIfNeeded() {
        console.log('[自动重连] 开始检查连接状态...');

        // 如果正在重连中，跳过
        if (isReconnecting) {
            console.log('[自动重连] 已在重连中，跳过');
            return;
        }

        // 检查是否已达到最大重连次数
        if (reconnectAttempts >= maxReconnectAttempts) {
            console.log('[自动重连] 已达到最大重连次数，需要手动刷新');
            return;
        }

        // 获取连接状态
        var status = sdkInstance.getStatus();

        // ✅ 修复：先检查是否已认证，未登录时不尝试重连
        if (!status.authenticated) {
            console.log('[自动重连] 用户未登录，跳过自动重连');
            return;
        }

        // ✅ 检查是否有活跃的 issue，没有则不重连
        if (!status.hasIssue) {
            console.log('[自动重连] 没有活跃的 Issue，跳过自动重连');
            return;
        }

        if (!status.realtimeConnected) {
            console.log('[自动重连] SSE 已断开，开始重连...');
            isReconnecting = true;
            reconnectAttempts++;

            try {
                // 计算重连延迟（指数退避）
                var delay = 1000 * Math.pow(2, reconnectAttempts - 1);
                console.log('[自动重连] 延迟 ' + delay + 'ms 后重连...');

                if (delay > 1000) {
                    await new Promise(function (resolve) { setTimeout(resolve, delay); });
                }

                // 重新连接 SSE
                await sdkInstance.connectRealtime(
                    handleRealtimeMessage,
                    function (error) {
                        console.error('[自动重连] 实时连接错误:', error);
                        triggerEvent('error', { error: error });
                    }
                );

                // 重连成功
                reconnectAttempts = 0; // 重置重连次数
                console.log('[自动重连] SSE 重连成功');

            } catch (error) {
                console.error('[自动重连] 重连失败 (' + reconnectAttempts + '/' + maxReconnectAttempts + '):', error);
            } finally {
                isReconnecting = false;
            }
        } else {
            console.log('[自动重连] SSE 连接正常，无需重连');
            // 连接正常，重置重连次数
            reconnectAttempts = 0;
        }
    }

    /**
     * 刷新全部数据（后台时间较长时使用）
     */
    async function refreshAllData() {
        console.log('[自动重连] 开始刷新全部数据...');

        try {
            // ✅ 修复：先检查是否已认证
            var status = sdkInstance.getStatus();
            if (!status.authenticated) {
                console.log('[自动重连] 用户未登录，跳过数据刷新');
                return;
            }

            // 1. 重新获取会话信息
            console.log('[自动重连] 刷新会话信息...');
            issueData = await sdkInstance.getMyIssue();

            // 2. 重连 SSE（仅当有活跃 issue 时）
            // 如果 issue status=3(已解决) 或 4(已拒绝)，则不重连
            if (issueData && (issueData.status === 3 || issueData.status === 4)) {
                console.log('[自动重连] Issue 状态为 ' + issueData.status + ' (已解决/已拒绝)，跳过 SSE 重连');
            } else if (issueData && issueData.issueId) {
                console.log('[自动重连] 重连 SSE...');
                await reconnectIfNeeded();
            } else {
                console.log('[自动重连] 没有活跃的 Issue，跳过 SSE 重连');
            }

            console.log('[自动重连] 全部数据刷新完成');

        } catch (error) {
            console.error('[自动重连] 数据刷新失败:', error);
            triggerEvent('error', { error: error });
        }
    }

    // ==================== 结束：前后台切换和自动重连 ====================

    // 处理来自 iframe 的命令
    async function handleIframeCommand(command, data) {
        switch (command) {
            case 'sendMessage':
                return await sendMessage(data);
            case 'uploadFile':
                return await uploadFile(data);
            case 'sendFileMessage':
                return await sendFileMessage(data);
            case 'setToken':
                setToken(data);
                return { success: true };
            case 'getStatus':
                return getStatus();
            case 'getHistoryMessages':
                return getHistoryMessages();
            case 'loadMoreMessages':
                return await loadMoreMessages(data.limit, data.offset);
            case 'addIssueTags':
                return await addIssueTags(data);
            case 'removeIssueTags':
                return await removeIssueTags(data);
            case 'on':
                // iframe 注册事件监听
                addEventListener(data, function (eventData) {
                    // 推送事件到 iframe
                    if (chatIframe && chatIframe.contentWindow) {
                        try {
                            // 序列化数据（移除不能克隆的内容，如函数、SDK 实例）
                            var serializableData = serializeEventData(eventData);

                            chatIframe.contentWindow.postMessage({
                                type: 'helpbot-event',
                                eventType: data,
                                data: serializableData
                            }, '*');
                        } catch (error) {
                            console.error('发送事件到 iframe 失败:', error);
                        }
                    }
                });
                return { success: true };
            default:
                throw new Error('未知的命令: ' + command);
        }
    }

    // 开始加载 SDK
    loadSDK();

})(document, 'helpbot-sdk-script');
