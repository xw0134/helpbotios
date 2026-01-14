import Foundation
import UIKit
import WebKit

/**
 HelpBot 会话界面（iOS）。

 设计目标：
 - 作为 SDK 内部 UI 容器，不耦合宿主业务
 - 通过 `HelpBotWebViewSession` 复用同一个 WKWebView
 - 标题栏可通过 `HelpBotConfig.customConfig["showTitleBar"]` 控制显示/隐藏
 */
final class HelpBotViewController: UIViewController {
    private static let tag = "HelpBotVC"

    private let containerView = UIView()
    private let showTitleBar: Bool

    init(showTitleBar: Bool) {
        self.showTitleBar = showTitleBar
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        // 作为 SDK 会话页，避免误触下拉导致半屏/裁剪（对齐 Android：非弹窗）
        isModalInPresentation = true
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // iOS 12 兼容：systemBackground 为 iOS 13+
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        // 说明：
        // - 必须“全宽”等于屏幕宽度，避免 iPad/横屏 safeArea 左右 inset 造成 WebView 宽度不足
        // - 垂直方向尊重 safeArea，避免导航栏/刘海/底部 Home Indicator 造成 WebView 内容被遮挡（看起来像裁剪）
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        if showTitleBar {
            navigationItem.title = "HelpBot"
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "关闭",
                style: .done,
                target: self,
                action: #selector(onCloseTapped)
            )
        }

        // attach WKWebView
        HelpBotWebViewSession.shared.attach(to: self, containerView: containerView)
        HelpBotWebViewSession.shared.openWhenReady()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || isMovingFromParent {
            HelpBotWebViewSession.shared.detach()
            HelpBot.onConversationDismissed()
        }
    }

    @objc private func onCloseTapped() {
        _ = HelpBot.hideConversation()
    }
}


