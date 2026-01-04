/**
 * HelpBot Web SDK - 客服聊天系统Web端SDK
 * 提供完整的客服接口封装，支持参数校验、错误处理、重试机制等
 * @version 1.0.0
 * @author HelpBot Team
 */

/**
 * SDK错误类
 */
class HelpBotSDKError extends Error {
    constructor(message, code, details = null) {
        super(message);
        this.name = 'HelpBotSDKError';
        this.code = code;
        this.details = details;
        this.timestamp = new Date().toISOString();
    }
}

/**
 * 参数校验器
 */
class Validator {
    /**
     * 校验必填参数
     * @param {Object} params - 参数对象
     * @param {Array} required - 必填字段数组
     * @throws {HelpBotSDKError} 参数校验失败时抛出错误
     */
    static validateRequired(params, required) {
        const missing = required.filter(field =>
            params[field] === undefined ||
            params[field] === null ||
            params[field] === ''
        );

        if (missing.length > 0) {
            throw new HelpBotSDKError(
                `缺少必填参数: ${missing.join(', ')}`,
                'MISSING_REQUIRED_PARAMS',
                { missingFields: missing }
            );
        }
    }

    /**
     * 校验参数类型
     * @param {*} value - 参数值
     * @param {string} type - 期望类型
     * @param {string} fieldName - 字段名
     * @throws {HelpBotSDKError} 类型校验失败时抛出错误
     */
    static validateType(value, type, fieldName) {
        const actualType = typeof value;
        if (actualType !== type) {
            throw new HelpBotSDKError(
                `参数 ${fieldName} 类型错误，期望 ${type}，实际 ${actualType}`,
                'INVALID_PARAM_TYPE',
                { fieldName, expectedType: type, actualType }
            );
        }
    }

    /**
     * 校验字符串长度
     * @param {string} value - 字符串值
     * @param {number} maxLength - 最大长度
     * @param {string} fieldName - 字段名
     * @throws {HelpBotSDKError} 长度校验失败时抛出错误
     */
    static validateStringLength(value, maxLength, fieldName) {
        if (typeof value === 'string' && value.length > maxLength) {
            throw new HelpBotSDKError(
                `参数 ${fieldName} 长度超限，最大 ${maxLength} 字符`,
                'STRING_TOO_LONG',
                { fieldName, maxLength, actualLength: value.length }
            );
        }
    }
}

/**
 * HTTP客户端 - 处理网络请求、重试、超时等
 */
class HttpClient {
    constructor(config) {
        this.baseURL = config.baseURL;
        this.timeout = config.timeout || 10000;
        this.maxRetries = config.maxRetries || 3;
        this.retryDelay = config.retryDelay || 1000;
        this.defaultHeaders = config.headers || {};
        this.logger = config.logger || null;

        // 拦截器链
        this.requestInterceptors = [];
        this.responseInterceptors = [];
    }

    /**
     * 添加请求拦截器
     * @param {Function} onFulfilled - 请求发送前的处理函数
     * @param {Function} [onRejected] - 请求失败的处理函数
     * @returns {number} 拦截器ID，用于移除
     * @example
     * const interceptorId = httpClient.addRequestInterceptor(
     *   (config) => {
     *     config.headers['X-Custom-Header'] = 'value';
     *     return config;
     *   },
     *   (error) => {
     *     console.error('请求拦截器错误:', error);
     *     return Promise.reject(error);
     *   }
     * );
     */
    addRequestInterceptor(onFulfilled, onRejected) {
        this.requestInterceptors.push({ onFulfilled, onRejected });
        return this.requestInterceptors.length - 1;
    }

    /**
     * 添加响应拦截器
     * @param {Function} onFulfilled - 响应成功的处理函数
     * @param {Function} [onRejected] - 响应失败的处理函数
     * @returns {number} 拦截器ID，用于移除
     * @example
     * const interceptorId = httpClient.addResponseInterceptor(
     *   (response) => {
     *     console.log('响应数据:', response);
     *     return response;
     *   },
     *   (error) => {
     *     if (error.code === 'HTTP_ERROR' && error.details?.status === 401) {
     *       // 处理401错误，如重新登录
     *       return handleUnauthorized(error);
     *     }
     *     return Promise.reject(error);
     *   }
     * );
     */
    addResponseInterceptor(onFulfilled, onRejected) {
        this.responseInterceptors.push({ onFulfilled, onRejected });
        return this.responseInterceptors.length - 1;
    }

    /**
     * 移除请求拦截器
     * @param {number} id - 拦截器ID
     */
    removeRequestInterceptor(id) {
        if (this.requestInterceptors[id]) {
            this.requestInterceptors[id] = null;
        }
    }

    /**
     * 移除响应拦截器
     * @param {number} id - 拦截器ID
     */
    removeResponseInterceptor(id) {
        if (this.responseInterceptors[id]) {
            this.responseInterceptors[id] = null;
        }
    }

    /**
     * 清空所有拦截器
     */
    clearInterceptors() {
        this.requestInterceptors = [];
        this.responseInterceptors = [];
    }

    /**
     * 发送HTTP请求
     * @param {string} endpoint - 接口端点
     * @param {Object} options - 请求选项
     * @returns {Promise<*>} 响应数据
     */
    async request(endpoint, options = {}) {
        const url = `${this.baseURL}${endpoint}`;
        let config = this._buildRequestConfig(options);
        const startTime = performance.now();

        // 记录请求日志
        if (this.logger) {
            this.logger.debug('HTTP 请求', {
                method: options.method || 'GET',
                url: url,
                headers: options.headers
            });
        }

        // 执行请求拦截器链
        try {
            config = await this._runRequestInterceptors(config);
        } catch (error) {
            throw this._formatError(error);
        }

        let lastError;
        for (let attempt = 0; attempt <= this.maxRetries; attempt++) {
            try {
                const response = await this._fetchWithTimeout(url, config);
                const data = await this._handleResponse(response, url, options, startTime);

                // 执行响应拦截器链（成功情况）
                return await this._runResponseInterceptors(data);
            } catch (error) {
                lastError = error;

                // 尝试通过响应拦截器处理错误
                try {
                    const recoveredResponse = await this._runResponseInterceptorsOnError(error);
                    if (recoveredResponse !== undefined) {
                        return recoveredResponse;
                    }
                } catch (interceptorError) {
                    lastError = interceptorError;
                }

                if (attempt < this.maxRetries && this._shouldRetry(lastError)) {
                    await this._delay(this.retryDelay * Math.pow(2, attempt));
                    continue;
                }
                break;
            }
        }

        // 记录请求失败日志
        if (this.logger) {
            const duration = performance.now() - startTime;
            this.logger.error('HTTP 请求失败', {
                method: options.method || 'GET',
                url: url,
                duration: `${duration.toFixed(2)}ms`,
                error: {
                    code: lastError.code,
                    message: lastError.message,
                    details: lastError.details
                }
            });
        }

        throw this._formatError(lastError);
    }

    /**
     * 执行请求拦截器链
     * @private
     */
    async _runRequestInterceptors(config) {
        let currentConfig = config;

        for (const interceptor of this.requestInterceptors) {
            if (!interceptor) continue;

            try {
                if (interceptor.onFulfilled) {
                    currentConfig = await interceptor.onFulfilled(currentConfig);
                }
            } catch (error) {
                if (interceptor.onRejected) {
                    currentConfig = await interceptor.onRejected(error);
                } else {
                    throw error;
                }
            }
        }

        return currentConfig;
    }

    /**
     * 执行响应拦截器链（成功情况）
     * @private
     */
    async _runResponseInterceptors(response) {
        let currentResponse = response;

        for (const interceptor of this.responseInterceptors) {
            if (!interceptor) continue;

            try {
                if (interceptor.onFulfilled) {
                    currentResponse = await interceptor.onFulfilled(currentResponse);
                }
            } catch (error) {
                if (interceptor.onRejected) {
                    currentResponse = await interceptor.onRejected(error);
                } else {
                    throw error;
                }
            }
        }

        return currentResponse;
    }

    /**
     * 执行响应拦截器链（错误情况）
     * @private
     */
    async _runResponseInterceptorsOnError(error) {
        let currentError = error;

        for (const interceptor of this.responseInterceptors) {
            if (!interceptor || !interceptor.onRejected) continue;

            try {
                const result = await interceptor.onRejected(currentError);
                // 如果拦截器返回了数据，说明错误被处理了
                if (result !== undefined && !(result instanceof Error)) {
                    return result;
                }
                currentError = result;
            } catch (newError) {
                currentError = newError;
            }
        }

        throw currentError;
    }

    /**
     * 构建请求配置
     * @private
     */
    _buildRequestConfig(options) {
        return {
            method: options.method || 'GET',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                ...this.defaultHeaders,
                ...options.headers
            },
            body: options.body ? JSON.stringify(options.body) : undefined,
            signal: options.signal
        };
    }

    /**
     * 带超时的fetch请求
     * @private
     */
    async _fetchWithTimeout(url, config) {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), this.timeout);

        try {
            const response = await fetch(url, {
                ...config,
                signal: controller.signal
            });
            clearTimeout(timeoutId);
            return response;
        } catch (error) {
            clearTimeout(timeoutId);
            throw error;
        }
    }

    /**
     * 处理HTTP响应
     * @private
     */
    async _handleResponse(response, url, options, startTime) {
        const duration = performance.now() - startTime;

        if (!response.ok) {
            const errorText = await response.text().catch(() => '');

            const httpError = new HelpBotSDKError(
                `HTTP ${response.status}: ${response.statusText}`,
                'HTTP_ERROR',
                {
                    status: response.status,
                    statusText: response.statusText,
                    responseText: errorText,
                    url: url,
                    method: options.method || 'GET',
                    duration: `${duration.toFixed(2)}ms`
                }
            );

            // 记录 HTTP 错误日志
            if (this.logger) {
                this.logger.error('HTTP 错误', {
                    status: response.status,
                    statusText: response.statusText,
                    url: url,
                    method: options.method || 'GET',
                    duration: `${duration.toFixed(2)}ms`,
                    errorBody: errorText
                });
            }

            throw httpError;
        }

        const contentType = response.headers.get('content-type');
        const data = contentType && contentType.includes('application/json')
            ? await response.json()
            : await response.text();

        // 记录成功响应日志
        if (this.logger) {
            this.logger.debug('HTTP 响应', {
                method: options.method || 'GET',
                url: url,
                status: response.status,
                duration: `${duration.toFixed(2)}ms`
            });
        }

        return data;
    }

    /**
     * 判断是否应该重试
     * @private
     */
    _shouldRetry(error) {
        if (error.name === 'AbortError') return true;
        if (error.name === 'TypeError') return true;
        if (error.code === 'HTTP_ERROR' && error.details?.status >= 500) return true;
        // Token刷新后需要重试
        if (error.code === 'TOKEN_REFRESHED') return true;
        return false;
    }

    /**
     * 延迟函数
     * @private
     */
    _delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    /**
     * 格式化错误
     * @private
     */
    _formatError(error) {
        if (error instanceof HelpBotSDKError) {
            return error;
        }

        if (error.name === 'AbortError') {
            return new HelpBotSDKError('请求超时', 'REQUEST_TIMEOUT');
        }

        if (error.name === 'TypeError') {
            return new HelpBotSDKError('网络连接失败', 'NETWORK_ERROR');
        }

        return new HelpBotSDKError(
            error.message || '未知错误',
            'UNKNOWN_ERROR',
            { originalError: error }
        );
    }
}

/**
 * 服务器推送事件 (SSE) 客户端
 */
class SSEClient {
    constructor(httpClient) {
        this.httpClient = httpClient;
        this.connection = null;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 5;
        this.reconnectDelay = 1000;
        this.connectionState = 'disconnected';
        this.eventListeners = new Map();

        // 保存连接参数用于重连
        this.lastEndpoint = null;
        this.lastHeaders = null;
        this.reconnectTimer = null;
    }

    /**
     * 连接SSE
     * @param {string} endpoint - SSE端点
     * @param {Object} headers - 请求头
     * @returns {Promise<void>}
     */
    async connect(endpoint, headers = {}) {
        try {
            this.connectionState = 'connecting';

            // 保存连接参数用于重连
            this.lastEndpoint = endpoint;
            this.lastHeaders = { ...headers };  // 深拷贝避免引用问题

            const url = `${this.httpClient.baseURL}${endpoint}`;

            const response = await fetch(url, {
                method: 'GET',
                headers: {
                    'Accept': 'text/event-stream',
                    'Cache-Control': 'no-cache',
                    ...headers
                }
            });

            if (!response.ok) {
                throw new HelpBotSDKError(
                    `SSE连接失败: ${response.status}`,
                    'SSE_CONNECTION_FAILED'
                );
            }

            this.connection = response;
            this.connectionState = 'connected';
            this.reconnectAttempts = 0;
            this._startReading();
            this._emit('connect');

        } catch (error) {
            this.connectionState = 'error';
            this._emit('error', error);
            this._scheduleReconnect();
        }
    }

    /**
     * 监听事件
     * @param {string} eventType - 事件类型
     * @param {Function} listener - 事件监听器
     */
    on(eventType, listener) {
        if (!this.eventListeners.has(eventType)) {
            this.eventListeners.set(eventType, []);
        }
        this.eventListeners.get(eventType).push(listener);
    }

    /**
     * 断开连接
     */
    disconnect() {
        this.connectionState = 'disconnected';

        // 清理重连定时器
        if (this.reconnectTimer) {
            clearTimeout(this.reconnectTimer);
            this.reconnectTimer = null;
        }

        if (this.connection) {
            try {
                this.connection.body.getReader().cancel();
            } catch (error) {
                console.warn('关闭SSE连接时出错:', error);
            }
            this.connection = null;
        }

        // 清理保存的连接参数
        this.lastEndpoint = null;
        this.lastHeaders = null;
        this.reconnectAttempts = 0;

        this._emit('disconnect');
    }

    /**
     * 开始读取SSE流
     * @private
     */
    async _startReading() {
        const reader = this.connection.body.getReader();
        const decoder = new TextDecoder();
        let buffer = '';

        try {
            while (this.connectionState === 'connected') {
                const { done, value } = await reader.read();

                if (done) {
                    this._scheduleReconnect();
                    return;
                }

                buffer += decoder.decode(value, { stream: true });
                const lines = buffer.split('\n');
                buffer = lines.pop() || '';

                this._processSSELines(lines);
            }
        } catch (error) {
            if (this.connectionState === 'connected') {
                this._emit('error', error);
                this._scheduleReconnect();
            }
        }
    }

    /**
     * 处理SSE行数据
     * @private
     */
    _processSSELines(lines) {
        let currentEvent = {};

        for (const line of lines) {
            if (line.startsWith('id: ')) {
                currentEvent.id = line.substring(4).trim();
            } else if (line.startsWith('event: ')) {
                currentEvent.event = line.substring(7).trim();
            } else if (line.startsWith('data: ')) {
                currentEvent.data = line.substring(6).trim();
            } else if (line.trim() === '') {
                if (currentEvent.event && currentEvent.data) {
                    this._processEvent(currentEvent);
                }
                currentEvent = {};
            }
        }
    }

    /**
     * 处理完整事件
     * @private
     */
    _processEvent(event) {
        try {
            let data = event.data;

            // 尝试解析JSON数据
            try {
                data = JSON.parse(event.data);
            } catch (e) {
                // 处理Python字典格式
                try {
                    const jsonString = event.data
                        .replace(/'/g, '"')
                        .replace(/True/g, 'true')
                        .replace(/False/g, 'false')
                        .replace(/None/g, 'null');
                    data = JSON.parse(jsonString);
                } catch (e2) {
                    // 保持原始字符串
                }
            }

            this._emit('message', {
                type: event.event,
                data: data,
                id: event.id
            });

            this._notifyNative('onSSEMessage', this._formatNotificationText(event.event, data));

        } catch (error) {
            this._emit('error', new HelpBotSDKError(
                '解析SSE事件数据失败',
                'SSE_PARSE_ERROR',
                { event, error: error.message }
            ));
        }
    }

    /**
     * 触发事件
     * @private
     */
    _emit(eventType, data = null) {
        const listeners = this.eventListeners.get(eventType) || [];
        listeners.forEach(listener => {
            try {
                listener(data);
            } catch (error) {
                console.error(`事件监听器执行错误 (${eventType}):`, error);
            }
        });
    }

    /**
     * 格式化通知文本
     * @private
     */
    _formatNotificationText(eventType, data) {
        if (eventType !== 'message.new' || !data) {
            return '';
        }

        const isStaff = data.is_staff === true;
        if (!isStaff) {
            return '';
        }

        const messageType = data.type;

        if (messageType === 3 && data.body && typeof data.body === 'object') {
            const fileInfo = data.body;
            const contentType = fileInfo.file_content_type || '';

            if (contentType.startsWith('image/')) {
                return '[图片]';
            } else if (contentType.startsWith('audio/')) {
                return '[语音]';
            } else if (contentType.startsWith('video/')) {
                return '[视频]';
            } else {
                return '[文件]';
            }
        } else {
            let content = '';
            if (typeof data.body === 'string') {
                content = data.body;
            } else if (data.body && typeof data.body === 'object') {
                content = data.body.body || '';
            }

            if (content) {
                content = content.replace(/<br\s*\/?>/gi, '\n').replace(/<[^>]*>/g, '');

                if (content.length > 100) {
                    content = content.substring(0, 100) + '...';
                }

                return content;
            }
        }

        return '';
    }

    /**
     * 通知原生应用
     * @private
     */
    _notifyNative(method, data) {
        if (!data) {
            return;
        }

        try {
            if (window.HelpBotNativeAndroid && typeof window.HelpBotNativeAndroid[method] === 'function') {
                window.HelpBotNativeAndroid[method](String(data));
            } else if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[method]) {
                window.webkit.messageHandlers[method].postMessage(String(data));
            }
        } catch (error) {
            console.warn('通知原生应用失败:', error);
        }
    }

    /**
     * 调度重连
     * @private
     */
    _scheduleReconnect() {
        if (this.reconnectAttempts >= this.maxReconnectAttempts) {
            this.connectionState = 'failed';
            this._emit('error', new HelpBotSDKError(
                '达到最大重连次数',
                'MAX_RECONNECT_ATTEMPTS_REACHED'
            ));
            return;
        }

        this.connectionState = 'reconnecting';
        this.reconnectAttempts++;

        const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1);
        this.reconnectTimer = setTimeout(async () => {
            if (this.connectionState === 'reconnecting') {
                this._emit('reconnecting', { attempt: this.reconnectAttempts });

                // 使用保存的参数重新连接
                if (this.lastEndpoint && this.lastHeaders) {
                    try {
                        await this.connect(this.lastEndpoint, this.lastHeaders);
                        // 连接成功，重置重连次数
                        this.reconnectAttempts = 0;
                        this._emit('reconnected', { attempt: this.reconnectAttempts });
                    } catch (error) {
                        // 连接失败，会触发 catch 中的 _scheduleReconnect 继续重试
                        console.error('[SSEClient] 重连失败:', error);
                    }
                } else {
                    this._emit('error', new HelpBotSDKError(
                        '无法重连：缺少原始连接参数',
                        'MISSING_CONNECTION_PARAMS'
                    ));
                }
            }
        }, delay);
    }
}

/**
 * HelpBot SDK 主类
 */
class HelpBotSDK {
    /**
     * 创建SDK实例
     * @param {Object} config - 配置对象
     * @param {string} config.baseURL - API基础URL
     * @param {string} config.companyId - 公司ID
     * @param {string} config.channelId - 渠道ID
     * @param {string} config.userId - 用户ID
     * @param {string} [config.channel] - 渠道类型（如 'web'）
     * @param {string} [config.companyCode] - 公司代码
     * @param {string} [config.preGeneratedToken] - 预生成的 token（生产环境由后端提供）
     * @param {boolean} [config.useDevAPI] - 是否使用开发环境 API 获取 token（默认 false，测试环境使用）
     * @param {Object} [config.httpConfig] - HTTP配置
     */
    constructor(config) {
        // 参数校验（根据模式不同，要求的字段不同）
        const requiredFields = ['baseURL', 'channelId'];

        // 开发模式需要额外字段（用于生成 token）
        if (config.useDevAPI === true) {
            requiredFields.push('companyId', 'userId');
        }

        Validator.validateRequired(config, requiredFields);

        this.config = {
            baseURL: config.baseURL,
            appId: null, // 将从 login 接口返回值中获取
            companyId: config.companyId || null, // 生产模式下可能为 null
            companyCode: config.companyCode || null,
            channel: config.channel || null,
            channelId: config.channelId,
            userId: config.userId || null, // 生产模式下可能为 null（登录后从服务器获取）
            preGeneratedToken: config.preGeneratedToken || null, // 预生成的 token（生产环境）
            useDevAPI: config.useDevAPI || false, // 是否使用开发环境 API（测试环境）
            httpConfig: {
                timeout: 10000,
                maxRetries: 3,
                retryDelay: 1000,
                ...config.httpConfig
            }
        };

        // 获取 Logger 实例（或创建降级 Logger）
        this.logger = window.HelpBotSDKLogger || this._createFallbackLogger();

        // 记录 SDK 初始化
        this.logger.info('SDK 初始化', {
            baseURL: config.baseURL,
            channelId: config.channelId,
            channel: config.channel
        });

        // 初始化HTTP客户端
        this.httpClient = new HttpClient({
            baseURL: this.config.baseURL,
            logger: this.logger,
            ...this.config.httpConfig
        });

        // 初始化SSE客户端
        this.sseClient = new SSEClient(this.httpClient);

        // 内部状态
        this.tokens = {
            genToken: null,
            apiToken: null
        };
        this.userId = null;
        this.issueId = null;

        // Token刷新相关状态
        this.tokenRefreshing = false;
        this.tokenRefreshPromise = null;
        this.pendingRequests = [];

        // 事件监听器
        this.eventListeners = new Map();

        // 设置响应拦截器处理401错误
        this._setupAuthInterceptor();
    }

    /**
     * 创建降级 Logger（当 Logger 未加载时使用）
     * @private
     */
    _createFallbackLogger() {
        return {
            debug: (...args) => console.debug('[HelpBot]', ...args),
            info: (...args) => console.info('[HelpBot]', ...args),
            warn: (...args) => console.warn('[HelpBot]', ...args),
            error: (...args) => console.error('[HelpBot]', ...args),
            fatal: (...args) => console.error('[HelpBot FATAL]', ...args),
            logApiCall: () => {},
            startTimer: () => () => {},
            context: { sessionId: null, userId: null }
        };
    }

    /**
     * 设置认证拦截器，自动处理Token过期
     * @private
     */
    _setupAuthInterceptor() {
        this.httpClient.addResponseInterceptor(
            // 成功响应直接返回
            (response) => response,
            // 错误响应处理
            async (error) => {
                // 检查是否是401错误
                if (error.code === 'HTTP_ERROR' && error.details?.status === 401) {
                    // 如果正在刷新Token，等待刷新完成
                    if (this.tokenRefreshing) {
                        return new Promise((resolve, reject) => {
                            this.pendingRequests.push({ resolve, reject });
                        });
                    }

                    // 开始刷新Token
                    this.tokenRefreshing = true;
                    this.tokenRefreshPromise = this._refreshToken();

                    try {
                        await this.tokenRefreshPromise;
                        this.tokenRefreshing = false;

                        // 解决所有等待的请求
                        this.pendingRequests.forEach(({ resolve }) => resolve());
                        this.pendingRequests = [];

                        // 触发token刷新成功事件
                        this._emit('tokenRefreshed', { token: this.tokens.apiToken });

                        // 返回特殊标记，让调用方知道需要重试
                        throw new HelpBotSDKError(
                            'Token已刷新，请重试请求',
                            'TOKEN_REFRESHED',
                            { shouldRetry: true }
                        );
                    } catch (refreshError) {
                        this.tokenRefreshing = false;

                        // 拒绝所有等待的请求
                        this.pendingRequests.forEach(({ reject }) => reject(refreshError));
                        this.pendingRequests = [];

                        // 触发token刷新失败事件
                        this._emit('tokenRefreshFailed', refreshError);

                        throw new HelpBotSDKError(
                            'Token刷新失败，请重新登录',
                            'TOKEN_REFRESH_FAILED',
                            { originalError: refreshError }
                        );
                    }
                }

                // 非401错误直接抛出
                throw error;
            }
        );
    }

    /**
     * 刷新Token
     * @private
     * @returns {Promise<void>}
     */
    async _refreshToken() {
        try {
            this.logger.info('Token已过期，正在自动刷新...');

            // 重新获取genToken
            await this.getToken();

            // 重新登录获取apiToken
            const loginResult = await this.login();

            this.logger.info('Token刷新成功');

            return loginResult;
        } catch (error) {
            this.logger.error('Token刷新失败', error);
            throw error;
        }
    }

    /**
     * 获取生成token
     * @returns {Promise<string>} 生成的token
     * @example
     * // 测试环境（使用 API）
     * const sdk = new HelpBotSDK({
     *   baseURL: 'https://dev-bot-server.yuedongcs.com',
     *   companyId: 'company-xxx',
     *   channelId: 'appc-xxx',
     *   userId: '12345',
     *   useDevAPI: true  // 测试环境从接口获取
     * });
     * const token = await sdk.getToken();
     *
     * // 生产环境（使用预生成的 token）
     * const sdk = new HelpBotSDK({
     *   baseURL: 'https://api.helpbot.com',
     *   companyId: 'company-xxx',
     *   channelId: 'appc-xxx',
     *   userId: '12345',
     *   preGeneratedToken: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'  // 后端提供的 token
     * });
     * const token = await sdk.getToken();
     */
    async getToken() {
        try {
            // 生产环境配置验证
            if (!this.config.useDevAPI) {
                // 生产环境必须提供预生成 token
                if (!this.config.preGeneratedToken) {
                    throw new HelpBotSDKError(
                        '生产环境必须提供 preGeneratedToken。请通过后端 API 生成 token 并传入配置项。',
                        'MISSING_PRE_GENERATED_TOKEN',
                        {
                            hint: '设置 config.preGeneratedToken 或 config.useDevAPI = true（仅测试环境）'
                        }
                    );
                }

                // 验证 token 格式
                if (typeof this.config.preGeneratedToken !== 'string' || !this.config.preGeneratedToken.trim()) {
                    throw new HelpBotSDKError(
                        '预生成 token 无效，必须是非空字符串',
                        'INVALID_PRE_GENERATED_TOKEN',
                        { token: this.config.preGeneratedToken }
                    );
                }

                this.logger.info('使用预生成 token（生产环境）');
                this.tokens.genToken = this.config.preGeneratedToken;
                return this.config.preGeneratedToken;
            }

            // 测试环境：验证必需参数后再调用 API
            this.logger.debug('使用开发环境 API 获取 token（测试环境）');

            // 验证测试环境必需参数
            const missingParams = [];
            if (!this.config.companyId) missingParams.push('companyId');
            if (!this.config.channelId) missingParams.push('channelId');
            if (!this.config.userId) missingParams.push('userId');

            if (missingParams.length > 0) {
                throw new HelpBotSDKError(
                    `测试环境缺少必需配置参数: ${missingParams.join(', ')}`,
                    'MISSING_DEV_CONFIG',
                    {
                        missingParams,
                        hint: '请在 HelpBotConfig 中设置这些参数，或使用 preGeneratedToken（生产环境）'
                    }
                );
            }

            const currentTime = Math.floor(Date.now() / 1000);
            const iatTimestamp = currentTime - (5 * 60 * 60); // 减去5小时

            const requestBody = {
                company_id: this.config.companyId,
                channel_id: this.config.channelId,
                iat_timestamp: iatTimestamp,
                identities: [{
                    identifier: "uid",
                    value: this.config.userId
                }]
            };

            const response = await this.httpClient.request('/sdk/do_not_production/gen_token', {
                method: 'POST',
                body: requestBody
            });

            if (!response || !response.token) {
                throw new HelpBotSDKError(
                    'Token响应格式错误',
                    'INVALID_TOKEN_RESPONSE',
                    { response }
                );
            }

            this.tokens.genToken = response.token;
            return response.token;

        } catch (error) {
            throw this._wrapError(error, 'getToken');
        }
    }

    /**
     * 设置Token（客户端生成的token）
     * @param {string} token - 客户端生成的token
     * @example
     * // 客户端生成token后设置
     * sdk.setToken('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...');
     *
     * // 或者通过 HelpBot API
     * HelpBot('setToken', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...');
     */
    setToken(token) {
        if (!token || typeof token !== 'string') {
            throw new HelpBotSDKError(
                'Token必须是非空字符串',
                'INVALID_TOKEN',
                { token }
            );
        }

        this.logger.info('设置token');

        // 更新配置中的预生成token
        this.config.preGeneratedToken = token;

        // 更新内部token状态
        this.tokens.genToken = token;

        // 触发token更新事件
        this._emit('tokenUpdated', { token: token });

        return true;
    }

    /**
     * 用户登录
     * @param {Object} [sdkData] - SDK数据
     * @returns {Promise<Object>} 登录结果 {userId, appId, haveIssue, token}
     * @example
     * const loginResult = await sdk.login({
     *   full_privacy_mode: false
     * });
     * console.log('登录成功:', loginResult);
     */
    async login(sdkData = { full_privacy_mode: false }) {
        try {
            // 确保有生成token
            if (!this.tokens.genToken) {
                await this.getToken();
            }

            const queryParams = new URLSearchParams({
                channel_id: this.config.channelId
            });

            const endpoint = `/sdk/user/login?${queryParams.toString()}`;
            const requestBody = sdkData;

            const response = await this.httpClient.request(endpoint, {
                method: 'POST',
                body: requestBody,
                headers: {
                    'Authorization': `Bearer ${this.tokens.genToken}`
                }
            });

            if (!response || !response.user_id) {
                throw new HelpBotSDKError(
                    '登录响应格式错误',
                    'INVALID_LOGIN_RESPONSE',
                    { response }
                );
                
            }

            // 保存从服务器返回的 appId
            this.config.appId = response.app_id;
            this.userId = response.user_id;
            this.tokens.apiToken = response.token;

            return {
                userId: response.user_id,
                appId: response.app_id,
                haveIssue: response.have_issue,
                token: response.token
            };

        } catch (error) {
            throw this._wrapError(error, 'login');
        }
    }

    /**
     * 获取用户最近的Issue
     * @returns {Promise<Object|null>} Issue信息和历史消息，如果不存在则返回null
     * @example
     * const issueData = await sdk.getMyIssue();
     * if (issueData) {
     *   console.log('Issue信息:', issueData);
     * } else {
     *   console.log('用户还没有Issue');
     * }
     */
    async getMyIssue() {
        try {
            this._ensureAuthenticated();

            const queryParams = new URLSearchParams({
                app_id: this.config.appId,
                company_code: this.config.companyCode,
                channel: this.config.channel
            });

            const endpoint = `/sdk/issue/me?${queryParams.toString()}`;

            const response = await this.httpClient.request(endpoint, {
                method: 'GET',
                headers: {
                    'Content-Type': 'text/plain',
                    'Authorization': `Bearer ${this.tokens.apiToken}`
                }
            });

            if (!response || !response.issue_id) {
                throw new HelpBotSDKError(
                    '获取Issue响应格式错误',
                    'INVALID_GET_ISSUE_RESPONSE',
                    { response }
                );
            }

            // 保存 issue_id 和完整的 issue 数据
            // 如果 issue 状态为 3(已解决) 或 4(已拒绝)，则不保存 issueId
            // 这样下次发送消息时会创建新的 issue
            const status = response.status;
            if (status === 3 || status === 4) {
                console.log(`[SDK] Issue 状态为 ${status} (已解决/已拒绝)，清空 issueId 以便创建新会话`);
                this.issueId = null;
            } else {
                this.issueId = response.issue_id;
            }

            return {
                issueId: response.issue_id,
                status: response.status,
                createdAt: response.created_at,
                updatedAt: response.updated_at,
                hasMore: response.has_more,
                messages: response.messages || []
            };

        } catch (error) {
            // 如果是404错误，说明用户还没有Issue，返回null
            if (error.code === 'HTTP_ERROR' && error.details?.status === 404) {
                this.issueId = null;
                return null;
            }
            throw this._wrapError(error, 'getMyIssue');
        }
    }

    /**
     * 发送文本消息
     * @param {string} message - 消息内容
     * @param {number} [type=1] - 消息类型，默认为1
     * @returns {Promise<Object>} 发送结果 {messageId, issueId}
     * @example
     * const result = await sdk.sendMessage('你好，我需要帮助');
     * console.log('消息发送成功:', result);
     */
    async sendMessage(message, type = 1) {
        try {
            // 参数校验
            Validator.validateRequired({ message }, ['message']);
            Validator.validateType(message, 'string', 'message');
            Validator.validateStringLength(message, 2000, 'message');
            Validator.validateType(type, 'number', 'type');

            this._ensureAuthenticated();

            const queryParams = new URLSearchParams({
                app_id: this.config.appId,
                company_code: this.config.companyCode,
                channel: this.config.channel
            });

            const endpoint = `/sdk/message?${queryParams.toString()}`;

            // 构建请求体，如果没有 issueId 则不传 issue_id（会自动创建）
            const requestBody = {
                body: {
                    body: message
                }
            };

            // 如果已经有 issueId，则添加到请求体
            if (this.issueId) {
                requestBody.issue_id = this.issueId;
            }

            const response = await this.httpClient.request(endpoint, {
                method: 'POST',
                body: requestBody,
                headers: {
                    'Authorization': `Bearer ${this.tokens.apiToken}`
                }
            });

            if (!response || !response.message_id) {
                throw new HelpBotSDKError(
                    '发送消息响应格式错误',
                    'INVALID_SEND_MESSAGE_RESPONSE',
                    { response }
                );
            }

            // 如果返回了 issue_id，保存它（可能是新创建的）
            if (response.issue_id) {
                this.issueId = response.issue_id;
            }

            return {
                messageId: response.message_id,
                issueId: response.issue_id
            };

        } catch (error) {
            throw this._wrapError(error, 'sendMessage');
        }
    }

    /**
     * 发送文件消息
     * @param {Object} fileInfo - 文件信息对象
     * @param {string} fileInfo.fileKey - 文件唯一标识
     * @param {string} fileInfo.fileName - 文件名
     * @param {number} fileInfo.fileSize - 文件大小
     * @param {string} fileInfo.fileContentType - 文件MIME类型
     * @param {number} [type=3] - 消息类型，默认为3(文件消息)
     * @returns {Promise<Object>} 发送结果 {messageId, issueId}
     * @example
     * const fileInfo = {
     *   fileKey: 'media-xxx.jpg',
     *   fileName: 'photo.jpg',
     *   fileSize: 123456,
     *   fileContentType: 'image/jpeg'
     * };
     * const result = await sdk.sendFileMessage(fileInfo);
     */
    async sendFileMessage(fileInfo, type = 3) {
        try {
            // 参数校验
            Validator.validateRequired(fileInfo, ['fileKey', 'fileName', 'fileSize', 'fileContentType']);
            Validator.validateType(fileInfo.fileKey, 'string', 'fileKey');
            Validator.validateType(fileInfo.fileName, 'string', 'fileName');
            Validator.validateType(fileInfo.fileSize, 'number', 'fileSize');
            Validator.validateType(fileInfo.fileContentType, 'string', 'fileContentType');
            Validator.validateType(type, 'number', 'type');

            this._ensureAuthenticated();

            const queryParams = new URLSearchParams({
                app_id: this.config.appId,
                company_code: this.config.companyCode,
                channel: this.config.channel
            });

            const endpoint = `/sdk/message?${queryParams.toString()}`;

            // 构建请求体，如果没有 issueId 则不传 issue_id（会自动创建）
            const requestBody = {
                body: {
                    file_key: fileInfo.fileKey,
                    file_name: fileInfo.fileName,
                    file_size: fileInfo.fileSize,
                    file_content_type: fileInfo.fileContentType
                },
                type: type
            };

            // 如果已经有 issueId，则添加到请求体
            if (this.issueId) {
                requestBody.issue_id = this.issueId;
            }

            const response = await this.httpClient.request(endpoint, {
                method: 'POST',
                body: requestBody,
                headers: {
                    'Authorization': `Bearer ${this.tokens.apiToken}`
                }
            });

            if (!response || !response.message_id) {
                throw new HelpBotSDKError(
                    '发送文件消息响应格式错误',
                    'INVALID_SEND_FILE_MESSAGE_RESPONSE',
                    { response }
                );
            }

            // 如果返回了 issue_id，保存它（可能是新创建的）
            if (response.issue_id) {
                this.issueId = response.issue_id;
            }

            return {
                messageId: response.message_id,
                issueId: response.issue_id
            };

        } catch (error) {
            throw this._wrapError(error, 'sendFileMessage');
        }
    }

    /**
     * 发送混合消息（文本+文件，分两条发送）
     * @param {string} textMessage - 文本消息内容
     * @param {Object} fileInfo - 文件信息对象
     * @returns {Promise<Array>} 发送结果数组 [{messageId, issueId, type}, {messageId, issueId, type}]
     * @example
     * const results = await sdk.sendMixedMessage('这是一个文件', fileInfo);
     * console.log('文本消息ID:', results[0].messageId);
     * console.log('文件消息ID:', results[1].messageId);
     */
    async sendMixedMessage(textMessage, fileInfo) {
        try {
            const results = [];

            // 先发送文本消息 (type=1)
            if (textMessage && textMessage.trim()) {
                const textResult = await this.sendMessage(textMessage.trim(), 1);
                results.push(textResult);
            }

            // 再发送文件消息 (type=3)
            const fileResult = await this.sendFileMessage(fileInfo, 3);
            results.push(fileResult);

            return results;

        } catch (error) {
            throw this._wrapError(error, 'sendMixedMessage');
        }
    }

    /**
     * 上传文件
     * @description 上传文件到服务器，支持多种文件格式，自动添加app_id和channel参数
     * @param {File} file - 要上传的文件
     * @returns {Promise<Object>} 上传结果 {fileKey, fileName, fileSize, fileContentType, fileUrl}
     * @example
     * const fileInput = document.querySelector('input[type="file"]');
     * const file = fileInput.files[0];
     * const result = await sdk.uploadFile(file);
     * console.log('文件上传成功:', result);
     */
    async uploadFile(file) {
        try {
            // 参数校验
            Validator.validateRequired({ file }, ['file']);

            if (!(file instanceof File)) {
                throw new HelpBotSDKError(
                    '参数必须是File对象',
                    'INVALID_FILE_TYPE',
                    { actualType: typeof file }
                );
            }

            // 文件大小限制 (10MB)
            const maxSize = 10 * 1024 * 1024;
            if (file.size > maxSize) {
                throw new HelpBotSDKError(
                    `文件大小超过限制，最大支持 ${maxSize / 1024 / 1024}MB`,
                    'FILE_TOO_LARGE',
                    { fileSize: file.size, maxSize }
                );
            }

            // 支持的文件类型
            const allowedTypes = [
                'image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp',
                'application/pdf', 'text/plain',
                'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            ];

            if (!allowedTypes.includes(file.type)) {
                throw new HelpBotSDKError(
                    `不支持的文件类型: ${file.type}`,
                    'UNSUPPORTED_FILE_TYPE',
                    { fileType: file.type, allowedTypes }
                );
            }

            this._ensureAuthenticated();

            // 构建FormData
            const formData = new FormData();
            formData.append('file', file);

            // 构建上传URL，添加必要的查询参数
            const uploadUrl = new URL(`${this.config.baseURL}/sdk/message/upload`);
            uploadUrl.searchParams.append('app_id', this.config.appId);
            uploadUrl.searchParams.append('channel', this.config.channel);

            const url = uploadUrl.toString();

            const response = await fetch(url, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.tokens.apiToken}`
                    // 不设置Content-Type，让浏览器自动设置multipart/form-data边界
                },
                body: formData
            });

            if (!response.ok) {
                const errorText = await response.text().catch(() => '');
                throw new HelpBotSDKError(
                    `文件上传失败: HTTP ${response.status}`,
                    'UPLOAD_HTTP_ERROR',
                    {
                        status: response.status,
                        statusText: response.statusText,
                        responseText: errorText
                    }
                );
            }

            const result = await response.json();

            if (!result || !result.file_key) {
                throw new HelpBotSDKError(
                    '文件上传响应格式错误',
                    'INVALID_UPLOAD_RESPONSE',
                    { response: result }
                );
            }

            return {
                fileKey: result.file_key,
                fileName: result.file_name,
                fileSize: result.file_size,
                fileContentType: result.file_content_type,
                fileUrl: result.file_url
            };

        } catch (error) {
            throw this._wrapError(error, 'uploadFile');
        }
    }

    /**
     * 连接实时消息推送
     * @param {Function} onMessage - 消息回调函数
     * @param {Function} [onError] - 错误回调函数
     * @returns {Promise<void>}
     * @example
     * await sdk.connectRealtime(
     *   (message) => console.log('收到消息:', message),
     *   (error) => console.error('连接错误:', error)
     * );
     */
    async connectRealtime(onMessage, onError) {
        try {
            Validator.validateRequired({ onMessage }, ['onMessage']);
            Validator.validateType(onMessage, 'function', 'onMessage');

            this._ensureAuthenticated();

            const queryParams = new URLSearchParams({
                app_id: this.config.appId,
                company_code: this.config.companyCode,
                channel: this.config.channel
            });

            const endpoint = `/sdk/stock?${queryParams.toString()}`;

            // 设置事件监听
            this.sseClient.on('message', onMessage);
            if (onError) {
                this.sseClient.on('error', onError);
            }

            // 连接SSE
            await this.sseClient.connect(endpoint, {
                'Authorization': `Bearer ${this.tokens.apiToken}`
            });

        } catch (error) {
            throw this._wrapError(error, 'connectRealtime');
        }
    }

    /**
     * 断开实时消息连接
     * @example
     * sdk.disconnectRealtime();
     */
    disconnectRealtime() {
        this.sseClient.disconnect();
    }

    /**
     * 获取聊天历史
     * @param {number} [limit=50] - 获取条数限制
     * @returns {Promise<Array>} 历史消息列表
     * @example
     * const history = await sdk.getChatHistory(20);
     * console.log('历史消息:', history);
     */
    async getChatHistory(limit = 50) {
        try {
            Validator.validateType(limit, 'number', 'limit');

            // 优先使用登录后服务器返回的 userId，如果没有则使用配置中的 userId
            const userId = this.userId || this.config.userId;
            if (!userId) {
                throw new HelpBotSDKError(
                    '无法获取 userId，请先登录',
                    'MISSING_USER_ID'
                );
            }

            const endpoint = `/chat/history?userId=${encodeURIComponent(userId)}&limit=${limit}`;

            const response = await this.httpClient.request(endpoint, {
                method: 'GET'
            });

            return response || [];

        } catch (error) {
            throw this._wrapError(error, 'getChatHistory');
        }
    }

    /**
     * 获取消息历史（分页）
     * @param {string} issueId - Issue ID
     * @param {number} [limit=20] - 每页条数
     * @param {number} [offset=0] - 偏移量
     * @returns {Promise<Object>} 返回 {hasMore, data}
     * @example
     * const result = await sdk.getMessageHistory('issue-xxx', 20, 0);
     * console.log('更多消息:', result.data);
     * console.log('是否还有更多:', result.hasMore);
     */
    async getMessageHistory(issueId, limit = 0, offset = 0) {
        try {
            // 参数校验
            Validator.validateRequired({ issueId }, ['issueId']);
            Validator.validateType(issueId, 'string', 'issueId');
            Validator.validateType(limit, 'number', 'limit');
            Validator.validateType(offset, 'number', 'offset');

            this._ensureAuthenticated();

            const queryParams = new URLSearchParams({
                issue_id: issueId,
                limit: limit.toString(),
                offset: offset.toString(),
                app_id: this.config.appId
            });

            const endpoint = `/sdk/message?${queryParams.toString()}`;

            const response = await this.httpClient.request(endpoint, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${this.tokens.apiToken}`
                }
            });

            if (!response) {
                throw new HelpBotSDKError(
                    '获取消息历史响应格式错误',
                    'INVALID_MESSAGE_HISTORY_RESPONSE',
                    { response }
                );
            }

            return {
                hasMore: response.has_more || false,
                data: response.data || []
            };

        } catch (error) {
            throw this._wrapError(error, 'getMessageHistory');
        }
    }

    /**
     * 更新用户自定义 Meta 数据（Custom Meta）
     * @description 更新用户 app 下的 custom meta 数据，不存在则创建。支持多种数据类型（bool, enum, string, text, dropdown, date, number）
     * @param {Object} metaData - 客户端透传的 Meta 数据对象，格式为 {key: value}
     * @returns {Promise<Object>} 返回更新结果 {success, no_key, achived, iligal}
     * @example
     * // 更新单个字段
     * const result = await sdk.updateUserMeta({ x3: "2" });
     * console.log('成功:', result.success);
     * console.log('未找到的key:', result.no_key);
     *
     * // 更新多个字段（支持不同类型）
     * const result = await sdk.updateUserMeta({
     *   "user_level": "5",           // string 类型
     *   "vip_status": "true",        // bool 类型（字符串 "true"/"false"）
     *   "last_login": 1731398400,    // date 类型（UTC Unix 时间戳）
     *   "score": 1234567             // number 类型
     * });
     */
    async updateUserMeta(metaData) {
        try {
            // 参数校验
            Validator.validateRequired({ metaData }, ['metaData']);

            if (typeof metaData !== 'object' || metaData === null || Array.isArray(metaData)) {
                throw new HelpBotSDKError(
                    '参数 metaData 必须是对象',
                    'INVALID_META_DATA_TYPE',
                    { actualType: typeof metaData, isArray: Array.isArray(metaData) }
                );
            }

            // 确保已认证
            this._ensureAuthenticated();

            // 构建查询参数
            const queryParams = new URLSearchParams({
                app_id: this.config.appId
            });

            const endpoint = `/sdk/user/meta/custom?${queryParams.toString()}`;

            // 发送 PATCH 请求，直接透传客户端的 JSON 数据
            const response = await this.httpClient.request(endpoint, {
                method: 'PATCH',
                body: metaData,
                headers: {
                    'Authorization': `Bearer ${this.tokens.apiToken}`
                }
            });

            // 返回完整的响应
            return {
                success: response.success || [],
                no_key: response.no_key || [],
                achived: response.achived || [],
                iligal: response.iligal || []
            };

        } catch (error) {
            throw this._wrapError(error, 'updateUserMeta');
        }
    }

    /**
     * 更新用户 SDK Meta 数据（SDK Meta）
     * @description 更新用户 SDK 下的 meta 数据，不存在则创建。用于存储 SDK 相关信息（如版本号、系统版本等）。支持多种数据类型（bool, enum, string, text, dropdown, date, number）
     * @param {Object} sdkMetaData - 客户端透传的 SDK Meta 数据对象，格式为 {key: value}
     * @returns {Promise<Object>} 返回更新结果 {success, no_key, achived, iligal}
     * @example
     * // 更新 SDK 版本信息
     * const result = await sdk.updateUserSdkMeta({
     *   "sdk_version": "1.2.3",
     *   "os_version": "0.2.3"
     * });
     * console.log('成功:', result.success);
     *
     * // 更新多个 SDK 相关字段（支持不同类型）
     * const result = await sdk.updateUserSdkMeta({
     *   "sdk_version": "1.2.3",      // string 类型
     *   "os_version": "0.2.3",       // string 类型
     *   "device_id": "device-123",   // string 类型
     *   "last_active": 1758858446,   // date 类型（UTC Unix 时间戳）
     *   "session_count": 100         // number 类型
     * });
     */
    async updateUserSdkMeta(sdkMetaData) {
        try {
            // 参数校验
            Validator.validateRequired({ sdkMetaData }, ['sdkMetaData']);

            if (typeof sdkMetaData !== 'object' || sdkMetaData === null || Array.isArray(sdkMetaData)) {
                throw new HelpBotSDKError(
                    '参数 sdkMetaData 必须是对象',
                    'INVALID_SDK_META_DATA_TYPE',
                    { actualType: typeof sdkMetaData, isArray: Array.isArray(sdkMetaData) }
                );
            }

            // 确保已认证
            this._ensureAuthenticated();

            // 构建查询参数
            const queryParams = new URLSearchParams({
                app_id: this.config.appId
            });

            const endpoint = `/sdk/user/meta/sdk?${queryParams.toString()}`;

            // 发送 PATCH 请求，直接透传客户端的 JSON 数据
            const response = await this.httpClient.request(endpoint, {
                method: 'PATCH',
                body: sdkMetaData,
                headers: {
                    'Authorization': `Bearer ${this.tokens.apiToken}`
                }
            });

            // 返回完整的响应
            return {
                success: response.success || [],
                no_key: response.no_key || [],
                achived: response.achived || [],
                iligal: response.iligal || []
            };

        } catch (error) {
            throw this._wrapError(error, 'updateUserSdkMeta');
        }
    }

    /**
     * 给已存在的 Issue 添加 Tags
     * @description 为当前用户的 Issue 添加一个或多个标签。标签用于分类和筛选客服工单。
     * @param {Array<string>} tags - 要添加的标签数组
     * @returns {Promise<Object>} 返回操作结果 {success}
     * @example
     * // 添加单个标签
     * const result = await sdk.addIssueTags(['VIP']);
     * console.log('成功:', result.success);
     *
     * // 添加多个标签
     * const result = await sdk.addIssueTags(['VIP', 'urgent', 'payment-issue']);
     * console.log('成功添加的标签:', result.success);
     */
    async addIssueTags(tags) {
        try {
            // 参数校验
            Validator.validateRequired({ tags }, ['tags']);

            if (!Array.isArray(tags)) {
                throw new HelpBotSDKError(
                    '参数 tags 必须是数组',
                    'INVALID_TAGS_TYPE',
                    { actualType: typeof tags }
                );
            }

            if (tags.length === 0) {
                throw new HelpBotSDKError(
                    '参数 tags 不能为空数组',
                    'EMPTY_TAGS_ARRAY'
                );
            }

            // 验证每个tag都是字符串
            const invalidTags = tags.filter(tag => typeof tag !== 'string');
            if (invalidTags.length > 0) {
                throw new HelpBotSDKError(
                    '所有标签必须是字符串类型',
                    'INVALID_TAG_ITEM_TYPE',
                    { invalidTags }
                );
            }

            // 确保已认证
            this._ensureAuthenticated();

            // 构建查询参数
            const queryParams = new URLSearchParams({
                app_id: this.config.appId
            });

            const endpoint = `/sdk/issue/tags/add?${queryParams.toString()}`;

            // 发送 PATCH 请求
            const response = await this.httpClient.request(endpoint, {
                method: 'PATCH',
                body: { tags },
                headers: {
                    'Authorization': `Bearer ${this.tokens.apiToken}`
                }
            });

            // 返回响应结果
            return {
                success: response.success || []
            };

        } catch (error) {
            throw this._wrapError(error, 'addIssueTags');
        }
    }

    /**
     * 从已存在的 Issue 删除 Tags
     * @description 从当前用户的 Issue 中删除一个或多个标签。
     * @param {Array<string>} tags - 要删除的标签数组
     * @returns {Promise<Object>} 返回操作结果 {success}
     * @example
     * // 删除单个标签
     * const result = await sdk.removeIssueTags(['urgent']);
     * console.log('成功删除:', result.success);
     *
     * // 删除多个标签
     * const result = await sdk.removeIssueTags(['urgent', 'payment-issue']);
     * console.log('成功删除的标签:', result.success);
     */
    async removeIssueTags(tags) {
        try {
            // 参数校验
            Validator.validateRequired({ tags }, ['tags']);

            if (!Array.isArray(tags)) {
                throw new HelpBotSDKError(
                    '参数 tags 必须是数组',
                    'INVALID_TAGS_TYPE',
                    { actualType: typeof tags }
                );
            }

            if (tags.length === 0) {
                throw new HelpBotSDKError(
                    '参数 tags 不能为空数组',
                    'EMPTY_TAGS_ARRAY'
                );
            }

            // 验证每个tag都是字符串
            const invalidTags = tags.filter(tag => typeof tag !== 'string');
            if (invalidTags.length > 0) {
                throw new HelpBotSDKError(
                    '所有标签必须是字符串类型',
                    'INVALID_TAG_ITEM_TYPE',
                    { invalidTags }
                );
            }

            // 确保已认证
            this._ensureAuthenticated();

            // 构建查询参数
            const queryParams = new URLSearchParams({
                app_id: this.config.appId
            });

            const endpoint = `/sdk/issue/tags/remove?${queryParams.toString()}`;

            // 发送 PATCH 请求
            const response = await this.httpClient.request(endpoint, {
                method: 'PATCH',
                body: { tags },
                headers: {
                    'Authorization': `Bearer ${this.tokens.apiToken}`
                }
            });

            // 返回响应结果
            return {
                success: response.success || []
            };

        } catch (error) {
            throw this._wrapError(error, 'removeIssueTags');
        }
    }

    /**
     * 添加请求拦截器
     * @param {Function} onFulfilled - 请求发送前的处理函数
     * @param {Function} [onRejected] - 请求失败的处理函数
     * @returns {number} 拦截器ID，用于移除
     * @example
     * const interceptorId = sdk.addRequestInterceptor(
     *   (config) => {
     *     console.log('发送请求:', config);
     *     return config;
     *   }
     * );
     */
    addRequestInterceptor(onFulfilled, onRejected) {
        return this.httpClient.addRequestInterceptor(onFulfilled, onRejected);
    }

    /**
     * 添加响应拦截器
     * @param {Function} onFulfilled - 响应成功的处理函数
     * @param {Function} [onRejected] - 响应失败的处理函数
     * @returns {number} 拦截器ID，用于移除
     * @example
     * const interceptorId = sdk.addResponseInterceptor(
     *   (response) => {
     *     console.log('收到响应:', response);
     *     return response;
     *   },
     *   (error) => {
     *     console.error('请求失败:', error);
     *     return Promise.reject(error);
     *   }
     * );
     */
    addResponseInterceptor(onFulfilled, onRejected) {
        return this.httpClient.addResponseInterceptor(onFulfilled, onRejected);
    }

    /**
     * 移除请求拦截器
     * @param {number} id - 拦截器ID
     */
    removeRequestInterceptor(id) {
        this.httpClient.removeRequestInterceptor(id);
    }

    /**
     * 移除响应拦截器
     * @param {number} id - 拦截器ID
     */
    removeResponseInterceptor(id) {
        this.httpClient.removeResponseInterceptor(id);
    }

    /**
     * 监听SDK事件
     * @param {string} eventType - 事件类型 (error, tokenRefreshed, tokenRefreshFailed)
     * @param {Function} listener - 事件监听器
     * @example
     * // 监听错误事件
     * sdk.on('error', (error) => {
     *   console.error('SDK错误:', error);
     * });
     *
     * // 监听Token刷新成功事件
     * sdk.on('tokenRefreshed', (data) => {
     *   console.log('Token已自动刷新:', data.token);
     * });
     *
     * // 监听Token刷新失败事件
     * sdk.on('tokenRefreshFailed', (error) => {
     *   console.error('Token刷新失败，请重新登录:', error);
     *   // 可以在这里跳转到登录页面
     * });
     */
    on(eventType, listener) {
        if (!this.eventListeners.has(eventType)) {
            this.eventListeners.set(eventType, []);
        }
        this.eventListeners.get(eventType).push(listener);
    }

    /**
     * 移除事件监听器
     * @param {string} eventType - 事件类型
     * @param {Function} [listener] - 事件监听器，不传则移除所有
     */
    off(eventType, listener) {
        if (!this.eventListeners.has(eventType)) return;

        if (listener) {
            const listeners = this.eventListeners.get(eventType);
            const index = listeners.indexOf(listener);
            if (index > -1) {
                listeners.splice(index, 1);
            }
        } else {
            this.eventListeners.delete(eventType);
        }
    }

    /**
     * 获取SDK状态
     * @returns {Object} SDK当前状态
     */
    getStatus() {
        return {
            authenticated: !!(this.tokens.genToken && this.tokens.apiToken),
            hasIssue: !!this.issueId,
            userId: this.userId,
            issueId: this.issueId,
            realtimeConnected: this.sseClient.connectionState === 'connected'
        };
    }

    /**
     * 销毁SDK实例
     */
    destroy() {
        this.disconnectRealtime();
        this.eventListeners.clear();
        this.tokens = { genToken: null, apiToken: null };
        this.userId = null;
        this.issueId = null;
    }

    // 私有方法

    /**
     * 确保已认证
     * @private
     */
    _ensureAuthenticated() {
        if (!this.tokens.apiToken) {
            throw new HelpBotSDKError(
                '用户未登录，请先调用login方法',
                'NOT_AUTHENTICATED'
            );
        }
        if (!this.config.appId) {
            throw new HelpBotSDKError(
                'AppId未初始化，请先调用login方法完成登录',
                'APP_ID_NOT_INITIALIZED'
            );
        }
    }

    /**
     * 确保Issue存在
     * @private
     */
    _ensureIssueExists() {
        if (!this.issueId) {
            throw new HelpBotSDKError(
                'Issue不存在，请先调用createIssue或getMyIssue方法',
                'NO_ISSUE'
            );
        }
    }

    /**
     * 包装错误
     * @private
     */
    _wrapError(error, methodName) {
        if (error instanceof HelpBotSDKError) {
            return error;
        }

        return new HelpBotSDKError(
            `${methodName}方法执行失败: ${error.message}`,
            'METHOD_EXECUTION_FAILED',
            { methodName, originalError: error }
        );
    }

    /**
     * 触发事件
     * @private
     */
    _emit(eventType, data) {
        const listeners = this.eventListeners.get(eventType) || [];
        listeners.forEach(listener => {
            try {
                listener(data);
            } catch (error) {
                console.error(`事件监听器执行错误 (${eventType}):`, error);
            }
        });
    }
}

// 导出
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { HelpBotSDK, HelpBotSDKError };
} else if (typeof window !== 'undefined') {
    window.HelpBotSDK = HelpBotSDK;
    window.HelpBotSDKError = HelpBotSDKError;
}