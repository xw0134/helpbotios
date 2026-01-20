//
//  ContentView.swift
//  HelpBotSDKTester
//
//  Created by lang7 on 2026/1/13.
//

import SwiftUI
import UIKit
import HelpBotSDK

extension UIApplication {
    func hbTopViewController() -> UIViewController? {
        guard let window = hbKeyWindow() else { return nil }
        return hbTopViewController(from: window.rootViewController)
    }

    private func hbTopViewController(from root: UIViewController?) -> UIViewController? {
        if let nav = root as? UINavigationController {
            return hbTopViewController(from: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return hbTopViewController(from: tab.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return hbTopViewController(from: presented)
        }
        return root
    }

    private func hbKeyWindow() -> UIWindow? {
        // iOS 13+ 多 Scene 兼容
        if #available(iOS 13.0, *) {
            return connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return keyWindow
        }
    }
}


struct ContentView: View {
    @State private var token = ""
    
    var body: some View {
        VStack {
            Button("gen_token", systemImage: "globe", action: genToken).padding()
            Button("init_login_show", systemImage: "arrow.up", action: initLoginShow)
            
        }.buttonStyle(.bordered)
    }
    
    func initLoginShow() {
        print("initLoginShow clicked. Current token: '\(self.token)'")
        
        if self.token.isEmpty {
            print("⚠️ Token is empty! Please click 'gen_token' first.")
            return
        }

        // 初始化
        let configMap: [String: Any] = [
            "fullPrivacyMode": false,
            "showTitleBar": true,
            "enableSseNotification": true,
            "initTimeout": 30_000,
            "webViewLoadTimeout": 15_000
        ]

        HelpBot.install(channelId: "appc-20251126114209308-u59kqf625z2i326", domain: "dev-bot-server.yuedongcs.com", configMap: configMap, callback: nil)
        
        // 登陆
        HelpBot.login(self.token)
        print("HelpBot.login called")
        
        // 对齐 Android：无需宿主获取 topVC，直接调用 showConversation()
        DispatchQueue.main.async {
            let r = HelpBot.showConversation()
            print("HelpBot.showConversation result: success=\(r.isSuccess) err=\(r.errorMessage ?? "")")
        }
    }
    


    
    func genToken() {
        
        print("genToken starting..")
        
        let url = URL(string: "https://cn-serverlist.locojoy.com/mta/generate_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let loginData: [String: Any] = [
            "identities": [
                [
                    "identifier": "uid",
                    "value": "123456"
                ]
            ]
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: loginData, options: []) {
            request.httpBody = jsonData
        }

        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let data = data {
                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] {
                        print("Login Response: \(json)")
                        if let tokenValue = json["token"] as? String {
                            DispatchQueue.main.async {
                               self.token = tokenValue
                            }
                        }
                    }
                }
            }
            

        }
        print("genToken before resume..")
        task.resume()
        print("genToken after resume..")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
