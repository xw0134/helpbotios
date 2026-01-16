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

    // 键盘避让：对 WKWebView 的 scrollView 调整 contentInset（Apple 推荐做法）
    private var keyboardObserverTokens: [NSObjectProtocol] = []
    private var hasCapturedBaseInsets: Bool = false
    private var baseContentInset: UIEdgeInsets = .zero
    private var baseIndicatorInset: UIEdgeInsets = .zero

    // 自愈提示条（仅 SDK 会话页内显示，不影响宿主）
    private let recoveryBanner = UIView()
    /// iOS 12 兼容：`.medium` 为 iOS 13+；低版本使用 `.gray`
    private let recoverySpinner: UIActivityIndicatorView = {
        if #available(iOS 13.0, *) {
            return UIActivityIndicatorView(style: .medium)
        }
        return UIActivityIndicatorView(style: .gray)
    }()
    private let recoveryLabel = UILabel()
    private let recoveryCancelButton = UIButton(type: .system)
    private let recoveryRetryButton = UIButton(type: .system)
    private let recoveryCloseButton = UIButton(type: .system)

    init(showTitleBar: Bool) {
        self.showTitleBar = showTitleBar
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        // 作为 SDK 会话页，避免误触下拉导致半屏/裁剪
        if #available(iOS 13.0, *) {
            isModalInPresentation = true
        }
    }

    required init?(coder: NSCoder) {
        return nil
    }
    
    deinit {
        // 确保 observer 释放（SDK 视图生命周期结束时）
        teardownKeyboardAvoidance()
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

        // 键盘遮挡输入框兜底：部分机型/系统版本下 WKWebView 不会自动把输入框滚到可视区域
        setupKeyboardAvoidance()

        // 网络自愈提示条（仅当发生自愈时显示）
        setupRecoveryBannerUi()
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

// MARK: - Recovery banner (friendly, cancellable, non-blocking)

private extension HelpBotViewController {
    func setupRecoveryBannerUi() {
        recoveryBanner.translatesAutoresizingMaskIntoConstraints = false
        recoveryBanner.isHidden = true
        recoveryBanner.backgroundColor = UIColor(white: 0.0, alpha: 0.55)
        recoveryBanner.isUserInteractionEnabled = true

        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .white
        card.layer.cornerRadius = 10
        card.clipsToBounds = true

        recoveryBanner.addSubview(card)

        recoverySpinner.translatesAutoresizingMaskIntoConstraints = false
        recoverySpinner.hidesWhenStopped = true

        recoveryLabel.translatesAutoresizingMaskIntoConstraints = false
        recoveryLabel.numberOfLines = 2
        recoveryLabel.font = UIFont.systemFont(ofSize: 14)
        recoveryLabel.textColor = UIColor(white: 0.15, alpha: 1.0)
        recoveryLabel.text = "网络重建中，请稍候…"

        recoveryCancelButton.translatesAutoresizingMaskIntoConstraints = false
        recoveryCancelButton.setTitle("取消", for: .normal)

        recoveryRetryButton.translatesAutoresizingMaskIntoConstraints = false
        recoveryRetryButton.setTitle("重试", for: .normal)
        recoveryRetryButton.isHidden = true

        recoveryCloseButton.translatesAutoresizingMaskIntoConstraints = false
        recoveryCloseButton.setTitle("关闭", for: .normal)

        let topRow = UIStackView(arrangedSubviews: [recoverySpinner, recoveryLabel])
        topRow.translatesAutoresizingMaskIntoConstraints = false
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 10

        let buttonRow = UIStackView(arrangedSubviews: [recoveryCancelButton, recoveryRetryButton, recoveryCloseButton])
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.axis = .horizontal
        buttonRow.alignment = .center
        buttonRow.spacing = 10
        buttonRow.distribution = .fillProportionally

        let root = UIStackView(arrangedSubviews: [topRow, buttonRow])
        root.translatesAutoresizingMaskIntoConstraints = false
        root.axis = .vertical
        root.spacing = 10

        card.addSubview(root)
        view.addSubview(recoveryBanner)

        NSLayoutConstraint.activate([
            recoveryBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            recoveryBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            recoveryBanner.topAnchor.constraint(equalTo: view.topAnchor),
            recoveryBanner.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            card.leadingAnchor.constraint(equalTo: recoveryBanner.leadingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: recoveryBanner.trailingAnchor, constant: -12),
            card.topAnchor.constraint(equalTo: recoveryBanner.safeAreaLayoutGuide.topAnchor, constant: 12),

            root.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            root.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            root.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            root.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])

        recoveryCancelButton.addTarget(self, action: #selector(onRecoveryCancelTapped), for: .touchUpInside)
        recoveryRetryButton.addTarget(self, action: #selector(onRecoveryRetryTapped), for: .touchUpInside)
        recoveryCloseButton.addTarget(self, action: #selector(onRecoveryCloseTapped), for: .touchUpInside)
    }

    @objc func onRecoveryCancelTapped() {
        HelpBotWebViewSession.shared.cancelAutoRecovery()
        showRecoveryBanner(message: "已取消网络重建。你可以继续等待网络恢复，或点击“关闭”。", inProgress: false, allowRetry: false)
    }

    @objc func onRecoveryRetryTapped() {
        HelpBotWebViewSession.shared.requestAutoRecoveryFromUser()
    }

    @objc func onRecoveryCloseTapped() {
        _ = HelpBot.hideConversation()
    }

    func showRecoveryBanner(message: String, inProgress: Bool, allowRetry: Bool) {
        DispatchQueue.main.async {
            self.recoveryLabel.text = message
            self.recoveryRetryButton.isHidden = !allowRetry
            if inProgress {
                self.recoverySpinner.startAnimating()
            } else {
                self.recoverySpinner.stopAnimating()
            }
            self.recoveryBanner.isHidden = false
        }
    }

    func hideRecoveryBanner() {
        DispatchQueue.main.async {
            self.recoveryBanner.isHidden = true
            self.recoverySpinner.stopAnimating()
        }
    }
}

// MARK: - Keyboard avoidance (WKWebView)

private extension HelpBotViewController {
    func setupKeyboardAvoidance() {
        if !keyboardObserverTokens.isEmpty { return }
        let center = NotificationCenter.default

        let t1 = center.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] n in
            self?.handleKeyboard(notification: n)
        }
        let t2 = center.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] n in
            self?.handleKeyboard(notification: n)
        }
        keyboardObserverTokens = [t1, t2]
    }

    func teardownKeyboardAvoidance() {
        if keyboardObserverTokens.isEmpty { return }
        let center = NotificationCenter.default
        keyboardObserverTokens.forEach { center.removeObserver($0) }
        keyboardObserverTokens.removeAll()
    }

    func handleKeyboard(notification: Notification) {
        guard let webView = HelpBotWebViewSession.shared.webView else { return }

        // capture base insets once（避免覆盖宿主/系统设置的 inset）
        if !hasCapturedBaseInsets {
            hasCapturedBaseInsets = true
            baseContentInset = webView.scrollView.contentInset
            baseIndicatorInset = webView.scrollView.scrollIndicatorInsets
        }

        let userInfo = notification.userInfo ?? [:]
        let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
        let curveRaw = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 7
        let options = UIView.AnimationOptions(rawValue: UInt(curveRaw) << 16)

        let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
        let endInView = view.convert(endFrame, from: nil)

        // 计算键盘与当前 view 的重叠高度（再扣掉 safeArea bottom，避免重复叠加）
        let overlap = max(0, view.bounds.maxY - endInView.minY)
        let bottomInset = max(0, overlap - view.safeAreaInsets.bottom)

        UIView.animate(withDuration: duration, delay: 0, options: [options, .beginFromCurrentState], animations: {
            var inset = self.baseContentInset
            inset.bottom = self.baseContentInset.bottom + bottomInset
            webView.scrollView.contentInset = inset

            var indicator = self.baseIndicatorInset
            indicator.bottom = self.baseIndicatorInset.bottom + bottomInset
            webView.scrollView.scrollIndicatorInsets = indicator
        }, completion: nil)

        // DOM 兜底：触发一次 activeElement.scrollIntoView，避免输入框仍被遮挡
        if bottomInset > 0 {
            webView.evaluateJavaScript(
                "(function(){try{var a=document.activeElement;if(a&&a.scrollIntoView){a.scrollIntoView({block:'center'});} }catch(e){} })();",
                completionHandler: nil
            )
        }
    }
}
