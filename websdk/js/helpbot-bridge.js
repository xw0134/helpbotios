/**
 * HelpBot Native Bridge - Android/iOS 双向通信桥接
 * @version 1.0.0
 * @description 实现 WebView 与 Native 客户端之间的事件通信
 */
(function(window) {
    'use strict';

    /**
     * HelpBot 事件类型定义
     */
    const HelpBotEvent = {
        // 对话状态事件
        CONVERSATION_STATUS: 'CONVERSATION_STATUS',
        CONVERSATION_START: 'CONVERSATION_START',
        CONVERSATION_END: 'CONVERSATION_END',
        CONVERSATION_REJECTED: 'CONVERSATION_REJECTED',
        CONVERSATION_RESOLVED: 'CONVERSATION_RESOLVED',
        CONVERSATION_REOPENED: 'CONVERSATION_REOPENED',

        // 消息事件
        MESSAGE_ADD: 'MESSAGE_ADD',
        AGENT_MESSAGE_RECEIVED: 'AGENT_MESSAGE_RECEIVED',
        USER_MESSAGE_SEND: 'USER_MESSAGE_SEND',

        // 用户交互事件
        WIDGET_TOGGLE: 'WIDGET_TOGGLE',
        USER_CLICK_ACTION: 'USER_CLICK_ACTION',
        CSAT_SUBMIT: 'CSAT_SUBMIT',

        // 会话信息事件
        UNREAD_MESSAGE_COUNT: 'UNREAD_MESSAGE_COUNT',

        // 用户认证事件
        USER_AUTHENTICATION_FAILED: 'USER_AUTHENTICATION_FAILED',
        USER_SESSION_EXPIRED: 'USER_SESSION_EXPIRED',
        REFRESH_USER_CREDENTIALS: 'REFRESH_USER_CREDENTIALS',

        // SDK 状态事件
        SDK_READY: 'SDK_READY',
        SDK_ERROR: 'SDK_ERROR',

        // 文件上传事件
        FILE_UPLOAD_START: 'FILE_UPLOAD_START',
        FILE_UPLOAD_SUCCESS: 'FILE_UPLOAD_SUCCESS',
        FILE_UPLOAD_FAILED: 'FILE_UPLOAD_FAILED',

        // 连接状态事件
        CONNECTION_ESTABLISHED: 'CONNECTION_ESTABLISHED',
        CONNECTION_LOST: 'CONNECTION_LOST',
        RECONNECTING: 'RECONNECTING',

        // 日志上报事件
        LOG_REPORT: 'LOG_REPORT'
    };

    /**
     * 认证失败原因
     */
    const AuthenticationFailureReason = {
        INVALID_IDENTITY_TOKEN: 'INVALID_IDENTITY_TOKEN',
        IAT_IS_MANDATORY: 'IAT_IS_MANDATORY',
        IDENTITY_DATA_INVALID: 'IDENTITY_DATA_INVALID',
        IDENTITY_DATA_LIMIT_EXCEEDED: 'IDENTITY_DATA_LIMIT_EXCEEDED',
        IDENTITY_DATA_SYNC_FAILED: 'IDENTITY_DATA_SYNC_FAILED',
        APP_ATTRIBUTES_LIMIT_EXCEEDED: 'APP_ATTRIBUTES_LIMIT_EXCEEDED',
        MASTER_ATTRIBUTES_LIMIT_EXCEEDED: 'MASTER_ATTRIBUTES_LIMIT_EXCEEDED',
        APP_ATTRIBUTES_VALIDATION_FAILED: 'APP_ATTRIBUTES_VALIDATION_FAILED',
        MASTER_ATTRIBUTES_VALIDATION_FAILED: 'MASTER_ATTRIBUTES_VALIDATION_FAILED',
        APP_ATTRIBUTES_SYNC_FAILED: 'APP_ATTRIBUTES_SYNC_FAILED',
        MASTER_ATTRIBUTES_SYNC_FAILED: 'MASTER_ATTRIBUTES_SYNC_FAILED',
        IDENTITY_FEATURE_NOT_ENABLED: 'IDENTITY_FEATURE_NOT_ENABLED',
        USER_SESSION_EXPIRED: 'USER_SESSION_EXPIRED',
        TOKEN_EXPIRED: 'TOKEN_EXPIRED',
        TOKEN_REFRESH_FAILED: 'TOKEN_REFRESH_FAILED',
        NOT_AUTHENTICATED: 'NOT_AUTHENTICATED'
    };

    /**
     * Native Bridge 类
     */
    class HelpBotNativeBridge {
        constructor() {
            this.isAndroid = typeof window.HelpBotNativeAndroid !== 'undefined';
            this.isIOS = typeof window.HelpBotNativeIOS !== 'undefined';
            this.eventQueue = [];
            this.isNativeReady = false;
            this.debugMode = false;

            this._log('Bridge initialized', { isAndroid: this.isAndroid, isIOS: this.isIOS });
        }

        /**
         * 设置调试模式
         */
        setDebugMode(enabled) {
            this.debugMode = enabled;
        }

        /**
         * 日志输出
         */
        _log(message, data = null) {
            if (this.debugMode) {
                console.log('[HelpBot Bridge]', message, data || '');
            }
        }

        /**
         * 错误日志
         */
        _error(message, error = null) {
            console.error('[HelpBot Bridge Error]', message, error || '');
        }

        /**
         * 检测是否在 Native 环境中
         */
        isNativeEnvironment() {
            return this.isAndroid || this.isIOS;
        }

        /**
         * ============================================
         * WebView → Native: 发送事件到客户端
         * ============================================
         */

        /**
         * 发送事件到 Native（支持多个事件合并发送）
         * @param {string} eventName - 事件名称
         * @param {Object} eventData - 事件数据
         */
        sendEvent(eventName, eventData) {
            if (!this.isNativeEnvironment()) {
                this._log('Not in native environment, skip sending event', { eventName, eventData });
                return;
            }

            try {
                // 构建事件对象（支持多个事件）
                const payload = {};
                payload[eventName] = eventData;

                const payloadStr = JSON.stringify(payload);
                this._log('Sending event to native', { eventName, eventData, payload: payloadStr });

                // Android 调用
                if (this.isAndroid && window.HelpBotNativeAndroid && window.HelpBotNativeAndroid.sendEvent) {
                    window.HelpBotNativeAndroid.sendEvent(payloadStr);
                    this._log('Event sent to Android');
                }
                // iOS 调用（统一使用 HelpBotNativeIOS）
                else if (this.isIOS && window.HelpBotNativeIOS && window.HelpBotNativeIOS.sendEvent) {
                    window.HelpBotNativeIOS.sendEvent(payloadStr);
                    this._log('Event sent to iOS');
                } else {
                    this._error('Native sendEvent method not found');
                }

            } catch (error) {
                this._error('Failed to send event to native', error);
            }
        }

        /**
         * 批量发送多个事件
         * @param {Object} events - 多个事件对象 {eventName1: data1, eventName2: data2}
         */
        sendMultipleEvents(events) {
            if (!this.isNativeEnvironment()) {
                return;
            }

            try {
                const payloadStr = JSON.stringify(events);
                this._log('Sending multiple events to native', events);

                if (this.isAndroid && window.HelpBotNativeAndroid && window.HelpBotNativeAndroid.sendEvent) {
                    window.HelpBotNativeAndroid.sendEvent(payloadStr);
                } else if (this.isIOS && window.HelpBotNativeIOS && window.HelpBotNativeIOS.sendEvent) {
                    window.HelpBotNativeIOS.sendEvent(payloadStr);
                }

            } catch (error) {
                this._error('Failed to send multiple events to native', error);
            }
        }

        /**
         * 发送用户认证失败事件
         * @param {string} reason - 失败原因（使用 AuthenticationFailureReason 中的常量）
         */
        sendUserAuthFailureEvent(reason) {
            if (!this.isNativeEnvironment()) {
                this._log('Not in native environment, skip auth failure event');
                return;
            }

            try {
                this._log('Sending auth failure event to native', { reason });

                // Android 调用
                if (this.isAndroid && window.HelpBotNativeAndroid && window.HelpBotNativeAndroid.sendUserAuthFailureEvent) {
                    window.HelpBotNativeAndroid.sendUserAuthFailureEvent(reason);
                    this._log('Auth failure event sent to Android');
                }
                // iOS 调用（统一使用 HelpBotNativeIOS）
                else if (this.isIOS && window.HelpBotNativeIOS && window.HelpBotNativeIOS.sendUserAuthFailureEvent) {
                    window.HelpBotNativeIOS.sendUserAuthFailureEvent(reason);
                    this._log('Auth failure event sent to iOS');
                } else {
                    this._error('Native sendUserAuthFailureEvent method not found');
                }

            } catch (error) {
                this._error('Failed to send auth failure event to native', error);
            }
        }

        /**
         * ============================================
         * Native → WebView: 接收来自客户端的调用
         * ============================================
         */

        /**
         * 接收 Native 推送的 SSE 消息
         * 这个方法会被 Native 调用
         * @param {string|Object} data - SSE 消息数据
         */
        onSSEMessage(data) {
            try {
                const message = typeof data === 'string' ? JSON.parse(data) : data;
                this._log('Received SSE message from native', message);

                // 触发 HelpBot SDK 的消息处理
                if (window.HelpBot && typeof window.HelpBot === 'function') {
                    window.HelpBot('handleSSEMessage', message);
                } else {
                    this._error('HelpBot SDK not ready to handle SSE message');
                }

            } catch (error) {
                this._error('Failed to handle SSE message from native', error);
            }
        }

        /**
         * 接收 Native 的错误通知
         * 这个方法会被 Native 调用
         * @param {string|Object} errorData - 错误数据
         */
        onWebChatError(errorData) {
            try {
                const error = typeof errorData === 'string' ? JSON.parse(errorData) : errorData;
                this._error('Received error from native', error);

                // 触发 HelpBot SDK 的错误处理
                if (window.HelpBot && typeof window.HelpBot === 'function') {
                    window.HelpBot('handleNativeError', error);
                } else {
                    console.error('[HelpBot] Error from native:', error);
                }

            } catch (error) {
                this._error('Failed to handle error from native', error);
            }
        }

        /**
         * Native 调用：设置 Token
         * @param {string} token - 认证 Token
         * @param {boolean} autoConnect - 是否自动连接
         */
        setToken(token, autoConnect = false) {
            try {
                this._log('Native set token', { tokenLength: token?.length, autoConnect });

                if (window.HelpBot && typeof window.HelpBot === 'function') {
                    window.HelpBot('setToken', token, autoConnect);
                } else {
                    this._error('HelpBot SDK not ready to set token');
                }

            } catch (error) {
                this._error('Failed to set token from native', error);
            }
        }

        /**
         * Native 调用：打开聊天窗口
         */
        openChat() {
            try {
                this._log('Native open chat');

                if (window.HelpBot && typeof window.HelpBot === 'function') {
                    window.HelpBot('open');
                } else {
                    this._error('HelpBot SDK not ready to open chat');
                }

            } catch (error) {
                this._error('Failed to open chat from native', error);
            }
        }

        /**
         * Native 调用：关闭聊天窗口
         */
        closeChat() {
            try {
                this._log('Native close chat');

                if (window.HelpBot && typeof window.HelpBot === 'function') {
                    window.HelpBot('close');
                } else {
                    this._error('HelpBot SDK not ready to close chat');
                }

            } catch (error) {
                this._error('Failed to close chat from native', error);
            }
        }

        /**
         * ============================================
         * 便捷方法：发送各类事件
         * ============================================
         */

        /**
         * 对话状态变化
         */
        notifyConversationStatus(issueId, isOpen) {
            this.sendEvent(HelpBotEvent.CONVERSATION_STATUS, {
                LAST_ISSUE_ID: issueId,
                LAST_ISSUE_IS_OPEN: isOpen
            });
        }

        /**
         * 对话开始
         */
        notifyConversationStart(message, issueId) {
            this.sendEvent(HelpBotEvent.CONVERSATION_START, {
                MESSAGE: message,
                ISSUE_ID: issueId
            });
        }

        /**
         * 对话结束
         */
        notifyConversationEnd(issueId) {
            this.sendEvent(HelpBotEvent.CONVERSATION_END, {
                ISSUE_ID: issueId
            });
        }

        /**
         * 对话已解决
         */
        notifyConversationResolved(issueId) {
            this.sendEvent(HelpBotEvent.CONVERSATION_RESOLVED, {
                ISSUE_ID: issueId
            });
        }

        /**
         * 对话重新打开
         */
        notifyConversationReopened(issueId) {
            this.sendEvent(HelpBotEvent.CONVERSATION_REOPENED, {
                ISSUE_ID: issueId
            });
        }

        /**
         * 收到客服消息
         */
        notifyAgentMessageReceived(message) {
            this.sendEvent(HelpBotEvent.AGENT_MESSAGE_RECEIVED, {
                MESSAGE: message.body,
                AUTHOR: message.author,
                CREATED_AT: message.created_at,
                MESSAGE_ID: message.id
            });
        }

        /**
         * 用户发送消息
         */
        notifyUserMessageSend(message) {
            this.sendEvent(HelpBotEvent.USER_MESSAGE_SEND, {
                MESSAGE: message.body,
                CREATED_AT: message.created_at,
                MESSAGE_ID: message.id
            });
        }

        /**
         * 消息添加（通用）
         */
        notifyMessageAdd(message) {
            this.sendEvent(HelpBotEvent.MESSAGE_ADD, {
                MESSAGE: message.body,
                AUTHOR: message.author,
                TYPE: message.type,
                CREATED_AT: message.created_at
            });
        }

        /**
         * 未读消息数量变化
         */
        notifyUnreadMessageCount(count) {
            this.sendEvent(HelpBotEvent.UNREAD_MESSAGE_COUNT, {
                COUNT: count
            });
        }

        /**
         * 窗口打开/关闭
         */
        notifyWidgetToggle(isOpen) {
            this.sendEvent(HelpBotEvent.WIDGET_TOGGLE, {
                IS_OPEN: isOpen
            });
        }

        /**
         * SDK 就绪
         */
        notifySDKReady(data) {
            this.sendEvent(HelpBotEvent.SDK_READY, {
                HISTORY_COUNT: data.historyMessages?.length || 0,
                NEEDS_NEW_ISSUE: data.needsNewIssue,
                ISSUE_STATUS: data.issueStatus,
                ISSUE_ID: data.issueId
            });
        }

        /**
         * SDK 错误
         */
        notifySDKError(error) {
            this.sendEvent(HelpBotEvent.SDK_ERROR, {
                CODE: error.CODE || error.code,
                MESSAGE: error.MESSAGE || error.message,
                DETAILS: error.DETAILS || error.details,
                TIMESTAMP: error.TIMESTAMP || error.timestamp
            });
        }

        /**
         * 文件上传开始
         */
        notifyFileUploadStart(fileName, fileSize) {
            this.sendEvent(HelpBotEvent.FILE_UPLOAD_START, {
                FILE_NAME: fileName,
                FILE_SIZE: fileSize
            });
        }

        /**
         * 文件上传成功
         */
        notifyFileUploadSuccess(fileName, fileUrl) {
            this.sendEvent(HelpBotEvent.FILE_UPLOAD_SUCCESS, {
                FILE_NAME: fileName,
                FILE_URL: fileUrl
            });
        }

        /**
         * 文件上传失败
         */
        notifyFileUploadFailed(fileName, error) {
            this.sendEvent(HelpBotEvent.FILE_UPLOAD_FAILED, {
                FILE_NAME: fileName,
                ERROR: error
            });
        }

        /**
         * 连接建立
         */
        notifyConnectionEstablished() {
            this.sendEvent(HelpBotEvent.CONNECTION_ESTABLISHED, {
                TIMESTAMP: new Date().toISOString()
            });
        }

        /**
         * 连接丢失
         */
        notifyConnectionLost() {
            this.sendEvent(HelpBotEvent.CONNECTION_LOST, {
                TIMESTAMP: new Date().toISOString()
            });
        }

        /**
         * 正在重连
         */
        notifyReconnecting(attempt) {
            this.sendEvent(HelpBotEvent.RECONNECTING, {
                ATTEMPT: attempt,
                TIMESTAMP: new Date().toISOString()
            });
        }

        /**
         * 日志上报
         * @param {Array} logs - 日志数组
         */
        reportLogs(logs) {
            if (!Array.isArray(logs) || logs.length === 0) {
                this._log('No logs to report');
                return;
            }

            this.sendEvent(HelpBotEvent.LOG_REPORT, {
                LOGS: logs,
                COUNT: logs.length,
                TIMESTAMP: new Date().toISOString()
            });

            this._log('Reported logs to native', { count: logs.length });
        }
    }

    // 创建全局实例
    const bridge = new HelpBotNativeBridge();

    // 将桥接方法暴露到全局
    window.HelpBotBridge = bridge;
    window.HelpBotEvent = HelpBotEvent;
    window.HelpBotAuthenticationFailureReason = AuthenticationFailureReason;

    // 将 Native 调用的方法暴露到全局（供 Native 直接调用）
    window.onSSEMessage = bridge.onSSEMessage.bind(bridge);
    window.onWebChatError = bridge.onWebChatError.bind(bridge);

    console.log('[HelpBot Bridge] Native bridge initialized');

})(window);
