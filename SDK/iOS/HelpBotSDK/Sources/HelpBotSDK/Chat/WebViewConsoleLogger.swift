import Foundation
import WebKit

/**
 WebView 控制台日志捕获器（iOS）。
 
 与 Android WebViewConsoleLogger.java 对齐。
 用于捕获和记录 WebView 控制台输出。
 */
public final class WebViewConsoleLogger {
    
    private static let tag = "WebViewConsole"
    
    /**
     处理控制台消息
     
     - Parameters:
        - message: 消息内容
        - level: 日志级别
        - sourceURL: 来源 URL
        - lineNumber: 行号
     */
    public static func logConsoleMessage(
        _ message: String,
        level: String = "log",
        sourceURL: String? = nil,
        lineNumber: Int? = nil
    ) {
        var logMessage = "[WebView Console] \(message)"
        
        if let url = sourceURL {
            logMessage += " (source: \(url)"
            if let line = lineNumber {
                logMessage += ":\(line)"
            }
            logMessage += ")"
        }
        
        switch level.lowercased() {
        case "error":
            HBlogger.e(tag, logMessage)
        case "warn", "warning":
            HBlogger.w(tag, logMessage)
        case "info":
            HBlogger.i(tag, logMessage)
        case "debug":
            HBlogger.d(tag, logMessage)
        default:
            HBlogger.d(tag, logMessage)
        }
    }
    
    /**
     从 WKScriptMessage 中提取并记录控制台消息
     
     - Parameter message: WKScriptMessage 对象
     */
    public static func logFromScriptMessage(_ message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else {
            HBlogger.d(tag, "收到 WebView 消息: \(message.body)")
            return
        }
        
        let level = body["level"] as? String ?? "log"
        let text = body["message"] as? String ?? String(describing: message.body)
        let source = body["source"] as? String
        let line = body["line"] as? Int
        
        logConsoleMessage(text, level: level, sourceURL: source, lineNumber: line)
    }
    
    /**
     创建用于注入 WebView 的控制台拦截脚本
     
     - Returns: JavaScript 脚本字符串
     */
    public static func createConsoleInterceptScript() -> String {
        return """
        (function() {
            var originalConsole = {
                log: console.log,
                warn: console.warn,
                error: console.error,
                info: console.info,
                debug: console.debug
            };
            
            function sendToNative(level, args) {
                try {
                    var message = Array.prototype.slice.call(args).map(function(arg) {
                        if (typeof arg === 'object') {
                            try {
                                return JSON.stringify(arg);
                            } catch(e) {
                                return String(arg);
                            }
                        }
                        return String(arg);
                    }).join(' ');
                    
                    var error = new Error();
                    var stack = error.stack || '';
                    var lines = stack.split('\\n');
                    var source = '';
                    var line = 0;
                    
                    if (lines.length > 2) {
                        var match = lines[2].match(/at\\s+(.+?):(\\d+):(\\d+)/);
                        if (match) {
                            source = match[1];
                            line = parseInt(match[2]);
                        }
                    }
                    
                    window.webkit.messageHandlers.consoleLog.postMessage({
                        level: level,
                        message: message,
                        source: source,
                        line: line
                    });
                } catch(e) {
                    // 静默失败
                }
            }
            
            console.log = function() {
                originalConsole.log.apply(console, arguments);
                sendToNative('log', arguments);
            };
            
            console.warn = function() {
                originalConsole.warn.apply(console, arguments);
                sendToNative('warn', arguments);
            };
            
            console.error = function() {
                originalConsole.error.apply(console, arguments);
                sendToNative('error', arguments);
            };
            
            console.info = function() {
                originalConsole.info.apply(console, arguments);
                sendToNative('info', arguments);
            };
            
            console.debug = function() {
                originalConsole.debug.apply(console, arguments);
                sendToNative('debug', arguments);
            };
        })();
        """
    }
    
    private init() {
        fatalError("WebViewConsoleLogger 不能被实例化")
    }
}
