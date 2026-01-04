/**
 * HelpBot Logger - 生产级日志系统
 * 支持日志级别、远程上报、本地存储、性能监控等
 * @version 1.0.0
 */

/**
 * 日志级别枚举
 */
const LogLevel = {
    DEBUG: 0,   // 调试信息
    INFO: 1,    // 一般信息
    WARN: 2,    // 警告信息
    ERROR: 3,   // 错误信息
    FATAL: 4    // 致命错误
};

/**
 * 日志记录器类
 */
class HelpBotLogger {
    /**
     * 创建日志记录器实例
     * @param {Object} config - 配置对象
     * @param {string} config.appId - 应用ID
     * @param {string} config.logEndpoint - 日志上报端点（可选）
     * @param {number} config.minLevel - 最小日志级别（默认INFO，生产环境建议WARN）
     * @param {boolean} config.enableConsole - 是否输出到控制台（默认true，生产建议false）
     * @param {boolean} config.enableLocalStorage - 是否本地存储（默认true）
     * @param {number} config.maxLocalLogs - 本地最大存储条数（默认100）
     * @param {boolean} config.enableRemote - 是否远程上报（默认false）
     * @param {number} config.batchSize - 批量上报大小（默认10）
     * @param {number} config.flushInterval - 上报间隔ms（默认30000）
     */
    constructor(config = {}) {
        this.config = {
            appId: config.appId || 'helpbot-sdk',
            logEndpoint: config.logEndpoint || null,
            minLevel: config.minLevel !== undefined ? config.minLevel : LogLevel.INFO,
            enableConsole: config.enableConsole !== undefined ? config.enableConsole : true,
            enableLocalStorage: config.enableLocalStorage !== undefined ? config.enableLocalStorage : true,
            maxLocalLogs: config.maxLocalLogs || 100,
            enableRemote: config.enableRemote !== undefined ? config.enableRemote : false,
            batchSize: config.batchSize || 10,
            flushInterval: config.flushInterval || 30000
        };

        // 日志缓冲区（待上报）
        this.logBuffer = [];

        // 上报定时器
        this.flushTimer = null;

        // 用户上下文信息
        this.context = {
            userId: null,
            sessionId: this._generateSessionId(),
            userAgent: navigator.userAgent,
            url: window.location.href,
            timestamp: new Date().toISOString()
        };

        // 性能监控
        this.performanceMetrics = new Map();

        // 启动自动上报
        if (this.config.enableRemote && this.config.logEndpoint) {
            this._startAutoFlush();
        }

        // 监听页面卸载，上报剩余日志
        window.addEventListener('beforeunload', () => {
            this.flush();
        });

        // 监听全局错误
        this._setupGlobalErrorHandler();
    }

    /**
     * 设置用户上下文
     * @param {Object} context - 用户上下文信息
     */
    setContext(context) {
        this.context = {
            ...this.context,
            ...context
        };
    }

    /**
     * 更新用户ID
     * @param {string} userId - 用户ID
     */
    setUserId(userId) {
        this.context.userId = userId;
    }

    /**
     * DEBUG级别日志
     * @param {string} message - 日志消息
     * @param {Object} [data] - 附加数据
     */
    debug(message, data = null) {
        this._log(LogLevel.DEBUG, message, data);
    }

    /**
     * INFO级别日志
     * @param {string} message - 日志消息
     * @param {Object} [data] - 附加数据
     */
    info(message, data = null) {
        this._log(LogLevel.INFO, message, data);
    }

    /**
     * WARN级别日志
     * @param {string} message - 日志消息
     * @param {Object} [data] - 附加数据
     */
    warn(message, data = null) {
        this._log(LogLevel.WARN, message, data);
    }

    /**
     * ERROR级别日志
     * @param {string} message - 日志消息
     * @param {Error|Object} [error] - 错误对象或附加数据
     */
    error(message, error = null) {
        const errorData = error instanceof Error ? {
            message: error.message,
            stack: error.stack,
            name: error.name,
            code: error.code
        } : error;

        this._log(LogLevel.ERROR, message, errorData);
    }

    /**
     * FATAL级别日志
     * @param {string} message - 日志消息
     * @param {Error|Object} [error] - 错误对象或附加数据
     */
    fatal(message, error = null) {
        const errorData = error instanceof Error ? {
            message: error.message,
            stack: error.stack,
            name: error.name,
            code: error.code
        } : error;

        this._log(LogLevel.FATAL, message, errorData);

        // 致命错误立即上报
        if (this.config.enableRemote) {
            this.flush();
        }
    }

    /**
     * 记录API调用
     * @param {string} method - API方法名
     * @param {Object} params - 参数
     * @param {number} duration - 耗时ms
     * @param {boolean} success - 是否成功
     * @param {Object} [error] - 错误信息
     */
    logApiCall(method, params, duration, success, error = null) {
        const data = {
            method,
            params,
            duration,
            success,
            error: error ? {
                message: error.message,
                code: error.code
            } : null
        };

        if (success) {
            this.info(`API调用成功: ${method}`, data);
        } else {
            this.error(`API调用失败: ${method}`, data);
        }

        // 记录性能指标
        this._recordPerformance(method, duration);
    }

    /**
     * 开始性能计时
     * @param {string} label - 计时标签
     * @returns {Function} 结束计时函数
     */
    startTimer(label) {
        const startTime = performance.now();

        return () => {
            const duration = performance.now() - startTime;
            this.info(`⏱️ ${label}`, { duration: `${duration.toFixed(2)}ms` });
            return duration;
        };
    }

    /**
     * 获取本地存储的日志
     * @param {number} [limit] - 获取条数限制
     * @returns {Array} 日志数组
     */
    getLocalLogs(limit = null) {
        if (!this.config.enableLocalStorage) {
            return [];
        }

        try {
            const logsJson = localStorage.getItem('helpbot_logs');
            if (!logsJson) return [];

            const logs = JSON.parse(logsJson);
            return limit ? logs.slice(-limit) : logs;
        } catch (error) {
            console.error('读取本地日志失败:', error);
            return [];
        }
    }

    /**
     * 清空本地日志
     */
    clearLocalLogs() {
        try {
            localStorage.removeItem('helpbot_logs');
            this.info('本地日志已清空');
        } catch (error) {
            console.error('清空本地日志失败:', error);
        }
    }

    /**
     * 导出日志（用于调试）
     * @returns {string} JSON格式的日志
     */
    exportLogs() {
        const logs = this.getLocalLogs();
        return JSON.stringify(logs, null, 2);
    }

    /**
     * 手动刷新缓冲区，上报日志
     * @returns {Promise<void>}
     */
    async flush() {
        if (!this.config.enableRemote || !this.config.logEndpoint) {
            return;
        }

        if (this.logBuffer.length === 0) {
            return;
        }

        const logsToSend = [...this.logBuffer];
        this.logBuffer = [];

        try {
            const response = await fetch(this.config.logEndpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    appId: this.config.appId,
                    logs: logsToSend,
                    context: this.context
                }),
                // 使用 keepalive 确保页面卸载时也能发送
                keepalive: true
            });

            if (!response.ok) {
                console.error('日志上报失败:', response.status, response.statusText);
            }
        } catch (error) {
            console.error('日志上报异常:', error);
            // 上报失败，重新放回缓冲区
            this.logBuffer.unshift(...logsToSend);
        }
    }

    /**
     * 获取性能报告
     * @returns {Object} 性能报告
     */
    getPerformanceReport() {
        const report = {};

        this.performanceMetrics.forEach((metrics, method) => {
            const durations = metrics.durations;
            const avg = durations.reduce((sum, d) => sum + d, 0) / durations.length;
            const max = Math.max(...durations);
            const min = Math.min(...durations);

            report[method] = {
                count: metrics.count,
                avg: avg.toFixed(2),
                max: max.toFixed(2),
                min: min.toFixed(2)
            };
        });

        return report;
    }

    /**
     * 销毁日志记录器
     */
    destroy() {
        // 上报剩余日志
        this.flush();

        // 清除定时器
        if (this.flushTimer) {
            clearInterval(this.flushTimer);
            this.flushTimer = null;
        }
    }

    // 私有方法

    /**
     * 记录日志（核心方法）
     * @private
     */
    _log(level, message, data) {
        // 检查日志级别
        if (level < this.config.minLevel) {
            return;
        }

        const levelName = this._getLevelName(level);

        // 构建日志对象
        const logEntry = {
            level: levelName,
            message,
            data,
            context: { ...this.context },
            timestamp: new Date().toISOString(),
            url: window.location.href
        };

        // 输出到控制台
        if (this.config.enableConsole) {
            this._logToConsole(level, logEntry);
        }

        // 存储到本地
        if (this.config.enableLocalStorage) {
            this._saveToLocalStorage(logEntry);
        }

        // 添加到缓冲区（待上报）
        if (this.config.enableRemote) {
            this.logBuffer.push(logEntry);

            // 达到批量大小，立即上报
            if (this.logBuffer.length >= this.config.batchSize) {
                this.flush();
            }
        }
    }

    /**
     * 输出到控制台
     * @private
     */
    _logToConsole(level, logEntry) {
        const prefix = `[${logEntry.timestamp}] [${logEntry.level}]`;
        const message = `${prefix} ${logEntry.message}`;

        switch (level) {
            case LogLevel.DEBUG:
                console.debug(message, logEntry.data);
                break;
            case LogLevel.INFO:
                console.info(message, logEntry.data);
                break;
            case LogLevel.WARN:
                console.warn(message, logEntry.data);
                break;
            case LogLevel.ERROR:
            case LogLevel.FATAL:
                console.error(message, logEntry.data);
                break;
        }
    }

    /**
     * 保存到本地存储
     * @private
     */
    _saveToLocalStorage(logEntry) {
        try {
            const logsJson = localStorage.getItem('helpbot_logs');
            let logs = logsJson ? JSON.parse(logsJson) : [];

            // 添加新日志
            logs.push(logEntry);

            // 限制存储数量
            if (logs.length > this.config.maxLocalLogs) {
                logs = logs.slice(-this.config.maxLocalLogs);
            }

            localStorage.setItem('helpbot_logs', JSON.stringify(logs));
        } catch (error) {
            console.error('保存日志到本地存储失败:', error);
        }
    }

    /**
     * 启动自动上报
     * @private
     */
    _startAutoFlush() {
        this.flushTimer = setInterval(() => {
            this.flush();
        }, this.config.flushInterval);
    }

    /**
     * 记录性能指标
     * @private
     */
    _recordPerformance(method, duration) {
        if (!this.performanceMetrics.has(method)) {
            this.performanceMetrics.set(method, {
                count: 0,
                durations: []
            });
        }

        const metrics = this.performanceMetrics.get(method);
        metrics.count++;
        metrics.durations.push(duration);

        // 只保留最近100次记录
        if (metrics.durations.length > 100) {
            metrics.durations.shift();
        }
    }

    /**
     * 设置全局错误处理
     * @private
     */
    _setupGlobalErrorHandler() {
        // 捕获未处理的错误
        window.addEventListener('error', (event) => {
            this.error('未捕获的错误', {
                message: event.message,
                filename: event.filename,
                lineno: event.lineno,
                colno: event.colno,
                error: event.error ? {
                    message: event.error.message,
                    stack: event.error.stack
                } : null
            });
        });

        // 捕获未处理的Promise拒绝
        window.addEventListener('unhandledrejection', (event) => {
            this.error('未捕获的Promise拒绝', {
                reason: event.reason,
                promise: event.promise
            });
        });
    }

    /**
     * 生成会话ID
     * @private
     */
    _generateSessionId() {
        return `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    }

    /**
     * 获取日志级别名称
     * @private
     */
    _getLevelName(level) {
        const levelNames = ['DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL'];
        return levelNames[level] || 'UNKNOWN';
    }
}

// 导出
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { HelpBotLogger, LogLevel };
} else if (typeof window !== 'undefined') {
    window.HelpBotLogger = HelpBotLogger;
    window.LogLevel = LogLevel;
}
