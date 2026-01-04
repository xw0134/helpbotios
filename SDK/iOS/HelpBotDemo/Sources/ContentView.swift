import SwiftUI
import HelpBotSDK

struct ContentView: View {
    @StateObject private var vm = HelpBotDemoViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                Form {
                    Section(header: Text("配置")) {
                        TextField("channelId", text: $vm.channelId)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)

                        TextField("domain (https://host[:port])", text: $vm.domain)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)

                        TextField("preGeneratedToken (JWT)", text: $vm.token)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }

                    Section(header: Text("操作")) {
                        Button("install") { vm.install() }
                        Button("login") { vm.login() }
                        Button("showConversation") { vm.showConversation() }
                        Button("hideConversation") { vm.hideConversation() }
                        Button("logout") { vm.logout() }
                    }

                    Section(header: Text("状态")) {
                        Text(vm.statusText).font(.footnote)
                    }

                    Section(header: Text("事件日志")) {
                        ForEach(vm.logs.indices, id: \.self) { i in
                            Text(vm.logs[i]).font(.caption2)
                        }
                    }
                }
            }
            .navigationTitle("HelpBotDemo")
        }
    }
}


