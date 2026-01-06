import SwiftUI
import HelpBotSDK

/**
 iOS Demo UI：按 Android Demo（activity_main.xml）1:1 结构对齐。
 */
struct ContentView: View {
    @ObservedObject private var vm = HelpBotDemoViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("HelpBot SDK 测试台（兼容性 / 安全性 / 稳定性 / 网络波动）")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer().frame(height: 8)

                Text("建议流程：①一键自检 → ②Install → ③GenToken/Login → ④OpenConversation → ⑤安全扫描/网络抖动/压力回归")
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // ====== 基础参数 ======
                Spacer().frame(height: 16)
                sectionTitle("基础参数")

                Spacer().frame(height: 8)
                hbTextField(hint: "channelId（必填）", text: $vm.channelId)

                Spacer().frame(height: 8)
                hbTextField(hint: "domain(baseURL)（必填，仅 https，支持传 host 自动补全）", text: $vm.domain)

                Spacer().frame(height: 8)
                HStack(spacing: 12) {
                    hbTextField(hint: "identity.identifier", text: $vm.identityIdentifier)
                    hbTextField(hint: "identity.value", text: $vm.identityValue)
                }

                Spacer().frame(height: 8)
                hbTextField(hint: "Token 生成接口（Demo）", text: $vm.tokenUrl, keyboard: .URL)

                // ====== 质量保障 ======
                Spacer().frame(height: 16)
                sectionTitle("质量保障")

                Spacer().frame(height: 8)
                HStack(spacing: 8) {
                    hbButton("一键自检") { vm.runSelfCheck() }
                    hbButton("安全基线扫描") { vm.runSecurityBaselineAudit() }
                    hbButton("负向用例") { vm.runNegativeTests() }
                }

                // ====== 核心流程 ======
                Spacer().frame(height: 16)
                sectionTitle("核心流程")

                Spacer().frame(height: 8)
                HStack(spacing: 8) {
                    hbButton("Install") { vm.install() }
                    hbButton("GenToken") { vm.genToken() }
                        .simultaneousGesture(LongPressGesture().onEnded { _ in
                            vm.testDataUpdateAPIs()
                        })
                    hbButton("Login") { vm.login() }
                }

                Spacer().frame(height: 8)
                hbFullWidthButton("OpenConversation（打开会话）") { vm.showConversation() }
                    .simultaneousGesture(LongPressGesture().onEnded { _ in
                        vm.testOtherUIAPIs()
                    })

                Spacer().frame(height: 8)
                HStack(spacing: 8) {
                    hbButton("复制Token（脱敏显示）") { vm.copyTokenToClipboard() }
                    hbButton("清理WebView缓存") { vm.clearWebViewData() }
                }

                Spacer().frame(height: 8)
                Text(vm.tokenMaskedText)
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // ====== 网络波动/压力测试 ======
                Spacer().frame(height: 16)
                sectionTitle("网络波动与稳定性回归")

                Spacer().frame(height: 8)
                HStack(spacing: 8) {
                    Toggle("监听网络变化（自动记录）", isOn: $vm.networkMonitorEnabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("网络恢复后自动重试Install", isOn: $vm.autoRetryEnabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer().frame(height: 8)
                HStack(spacing: 8) {
                    hbButton("开始压力回归（open/hide循环）") { vm.startStressTest() }
                    hbButton("停止压力回归") { vm.stopStressTest() }
                }

                Spacer().frame(height: 8)
                hbFullWidthButton("测试：destroy 后重新安装（install-reinstall）") { vm.testReinstallation() }

                // ====== 工具：状态/日志/报告 ======
                Spacer().frame(height: 16)
                sectionTitle("状态 / 日志 / 报告")

                Spacer().frame(height: 8)
                HStack(spacing: 8) {
                    hbButton("读取健康快照") { vm.dumpHealthSnapshot() }
                    hbButton("导出报告（复制）") { vm.exportReportToClipboard() }
                }

                Spacer().frame(height: 8)
                HStack(spacing: 8) {
                    hbButton("清空日志") { vm.clearLog() }
                    hbButton("复制日志") { vm.copyLogToClipboard() }
                }

                Spacer().frame(height: 8)
                Text(vm.statusText)
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer().frame(height: 8)
                SelectableTextView(text: vm.logText)
                    .frame(height: 260)
                    .background(Color.black.opacity(0.07))
                    .cornerRadius(6)

                Spacer().frame(height: 24)
            }
            .padding(16)
        }
    }

    // MARK: - UI Helpers（对齐 Android：按钮等宽、文本输入高度 48）

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hbTextField(hint: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        TextField(hint, text: text)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .keyboardType(keyboard)
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(6)
    }

    private func hbButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .background(Color(UIColor.systemGray5))
        .cornerRadius(6)
    }

    private func hbFullWidthButton(_ title: String, action: @escaping () -> Void) -> some View {
        hbButton(title, action: action)
            .frame(maxWidth: .infinity)
    }
}


