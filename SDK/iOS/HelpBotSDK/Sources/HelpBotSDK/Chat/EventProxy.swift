import Foundation

/**
 事件代理：将 Web 侧事件透传给宿主（事件驱动）。
 */
public final class EventProxy {
    private weak var listener: HelpBotEventsListener?
    private let mainQueue = DispatchQueue.main

    init(listener: HelpBotEventsListener?) {
        self.listener = listener
    }

    func updateListener(_ listener: HelpBotEventsListener?) {
        self.listener = listener
    }

    func sendEvent(_ eventName: String, _ data: [String: Any]?) {
        // 统一在主线程回调宿主，避免宿主在后台线程更新 UI 造成崩溃
        let dataCopy: [String: Any]? = {
            guard let data else { return nil }
            // Swift Dictionary 为值类型，这里显式复制，避免引用类型 value 被外部并发修改导致宿主侧不稳定
            return Dictionary(uniqueKeysWithValues: data.map { ($0.key, $0.value) })
        }()

        mainQueue.async { [weak self] in
            guard let self else { return }
            self.listener?.onEventOccurred(eventName, dataCopy)
        }
    }

    func notifyAuthFailure(_ reason: HelpBotAuthenticationFailureReason) {
        // 主线程回调
        mainQueue.async { [weak self] in
            guard let self else { return }
            self.listener?.onUserAuthenticationFailure(reason)
        }
    }
}


