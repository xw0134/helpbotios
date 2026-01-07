import SwiftUI
import UIKit

/**
 可选中文本视图（用于日志面板，iOS 13 兼容）。

 设计目标：
 - TextView 日志区域：可选中复制、等宽字体、固定高度
 - 只读，不参与键盘输入
 */
struct SelectableTextView: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isScrollEnabled = true
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        tv.textContainer.lineFragmentPadding = 0
        tv.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        tv.text = text
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // 仅在内容变更时刷新，避免频繁 setText 造成光标/滚动抖动
        if uiView.text != text {
            uiView.text = text
        }
    }
}


