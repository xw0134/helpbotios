import Foundation
import UIKit
import UserNotifications

/**
 HelpBot 本地通知辅助类（iOS）。

 设计目标（与 Android 行为对齐）：
 - WebSDK 推送 SSE 新消息摘要到 Native 后，SDK 可选显示系统通知
 - 默认启用（可由 `HelpBot.enableSseNotification()/disableSseNotification()` 控制）
 - 不主动弹窗申请权限（避免打扰宿主），仅在已授权时发送通知
 */
final class HelpBotNotificationHelper {
    private static let tag = "HBNotification"

    /// 发送“新消息”本地通知（若未授权/会话可见/消息为空则静默忽略）
    static func notifyNewMessage(_ message: String) {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return }

        // 与 Android 一致的默认策略：会话正在展示时不做系统通知，避免打扰（宿主仍可通过事件监听自定义处理）
        if HelpBot.isConversationVisible() { return }

        // 仅在开关开启时通知
        if !HelpBot.isSseNotificationEnabled() { return }

        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    let content = UNMutableNotificationContent()
                    content.title = "HelpBot"
                    content.body = text
                    content.sound = .default

                    let identifier = "helpbot.sse.\(Int(Date().timeIntervalSince1970 * 1000))"
                    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request) { error in
                        if let error {
                            HBlogger.w(tag, "发送本地通知失败: \(error.localizedDescription)", error)
                        }
                    }
                default:
                    // 未授权：静默忽略（SDK 不主动申请权限）
                    break
                }
            }
        } else {
            // iOS 9 及以下：不支持 UNUserNotificationCenter（不做通知）
        }
    }
}


