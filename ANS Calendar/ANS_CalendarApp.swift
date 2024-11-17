//
//  ANS_CalendarApp.swift
//  ANS Calendar
//
//  Created by Stanisław on 15/11/2024.
//

import SwiftUI
import Security

@main
struct ANS_CalendarApp: App {
    @State private var LoginData: LoginResult = LoginResult(Success: false, JSessionID: "", StudentID: 0)
    @AppStorage("JSessionID") var JSessionID: String = ""
    @AppStorage("LoginGood") var CredsValid: Bool = false
    @AppStorage("Login") var User: String = ""

    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if (LoginData.Success) {
                    TabbedView()
                } else {
                    LoginView(LoginData: $LoginData)
                }
            }.task {
                print(CredsValid, Login)
                if (CredsValid) {
                    // Set query
                    let query: [String: Any] = [
                        kSecClass as String: kSecClassGenericPassword,
                        kSecAttrAccount as String: User,
                        kSecMatchLimit as String: kSecMatchLimitOne,
                        kSecReturnAttributes as String: true,
                        kSecReturnData as String: true,
                    ]
                    var item: CFTypeRef?
                    // Check if user exists in the keychain
                    if SecItemCopyMatching(query as CFDictionary, &item) == noErr {
                        // Extract result
                        if let existingItem = item as? [String: Any],
                           let username = existingItem[kSecAttrAccount as String] as? String,
                           let passwordData = existingItem[kSecValueData as String] as? Data,
                           let password = String(data: passwordData, encoding: .utf8)
                        {
                            LoginData = await Login(user: username, pass: password)
                        }
                    } else {
                        print("Something went wrong trying to find the user in the keychain")
                    }
                }
            }
        }
    }
}
