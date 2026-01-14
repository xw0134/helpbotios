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
    private var previousHostNavBarHidden: Bool?

    init(showTitleBar: Bool) {
        self.showTitleBar = showTitleBar
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        // 作为 SDK 会话页，避免误触下拉导致半屏/裁剪（对齐 Android：非弹窗）
        if #available(iOS 13.0, *) {
            isModalInPresentation = true
        }
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
        view.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false

        // 说明：
        // - showTitleBar=true：页面顶部有原生导航栏（push 或 present(nav)），WebView 应从 safeArea 开始，避免被遮挡/误判裁剪。
        // - showTitleBar=false：对齐 Android“沉浸式全屏”，允许覆盖到屏幕顶端。
        if showTitleBar {
            NSLayoutConstraint.activate([
                containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                containerView.topAnchor.constraint(equalTo: view.topAnchor),
                containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // showTitleBar=false 时，如果是 push 进宿主导航栈，为避免出现“原生导航栏 + WebView 内标题栏”的混乱体验：
        // - 临时隐藏宿主导航栏（仅对当前页面生效）
        if !showTitleBar, let nav = navigationController {
            if previousHostNavBarHidden == nil {
                previousHostNavBarHidden = nav.isNavigationBarHidden
            }
            nav.setNavigationBarHidden(true, animated: animated)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 恢复宿主导航栏状态，避免影响宿主其它页面
        if let nav = navigationController, let prev = previousHostNavBarHidden {
            nav.setNavigationBarHidden(prev, animated: animated)
            previousHostNavBarHidden = nil
        }
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


