//
//  ContentView.swift
//  HelpBotSDKTester
//
//  Created by lang7 on 2026/1/13.
//

import SwiftUI
import UIKit
import HelpBotSDK

struct ContentView: View {
    @State private var token = ""
    @State private var loginStatus = ""  // Track login status
    @State private var isLoggingIn = false  // Track if login is in progress

    var body: some View {
        VStack {
            // 兼容 iOS 13 / 旧 Xcode：不使用 Button(systemImage:) 语法
            Button(action: genToken) {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                    Text("gen_token")
                }
            }
            .padding()
            
            Button(action: initLoginShow) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up")
                    Text("init_login_show")
                }
            }
            .disabled(isLoggingIn)

            if isLoggingIn {
                ProgressView("Logging in...")
                    .padding()
            }

            Text(loginStatus)
                .foregroundColor(loginStatus.contains("成功") ? .green : .red)
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding()

        }.buttonStyle(.bordered)
    }
    
    func initLoginShow() {
        // 初始化
        let configMap: [String: Any] = [
            "fullPrivacyMode": false,
            "showTitleBar": true,
            "enableSseNotification": true,
            "initTimeout": 30_000,
            "webViewLoadTimeout": 15_000
        ]

        HelpBot.install(
            channelId: "appc-20251118211237141-wlpm187bdovx50b",
            domain: "locojoy.yuedongcs.com",
            configMap: configMap,
            callback: nil
        )

        // 登录（不要求 success 才能 showConversation，对齐 Android：show 由 SDK 入队/自动补执行）
        isLoggingIn = true
        loginStatus = "Attempting to log in..."

        HelpBot.login(self.token) { result in
            DispatchQueue.main.async {
                self.isLoggingIn = false

                if result.isSuccess {
                    self.loginStatus = "Login successful!"
                    print("Login successful!")
                } else {
                    let errorMessage = result.errorMessage ?? "Unknown error"
                    self.loginStatus = "Login failed: \(errorMessage)"
                    print("Login failed with error code: \(String(describing: result.errorCode)), message: \(errorMessage)")
                }
            }
        }
        
        // 关键：立即 show（无需等待 login success），SDK 会根据 install/login 状态入队并在条件满足后自动展示
        DispatchQueue.main.async {
            let r = HelpBot.showConversation()
            print("HelpBot.showConversation queued/immediate: success=\(r.isSuccess) err=\(r.errorMessage ?? \"\")")
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

// 兼容旧 Xcode：使用传统 PreviewProvider（不使用 #Preview）
struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}
