//
//  LoginView.swift
//  ANS Calendar
//
//  Created by Stanisław on 16/11/2024.
//

import SwiftUI

struct LoginView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @EnvironmentObject var VerbisANSApi: VerbisAPI
    
    var body: some View {
        VStack(alignment: .center) {
            Form {
                TextField("Nr. albumu", text: $username)
                    .autocorrectionDisabled(true)
                    .textContentType(.username)
                SecureField("Hasło", text: $password)
                Button("Login"){
                    Task {
                        try await VerbisANSApi.Login(user: username, pass: password)
                        
                        print(VerbisANSApi.JSessionID)
                    }
                }
            }
        }
        .frame(alignment: .center)
    }
}

#Preview {
    LoginView()
        .environmentObject(VerbisAPI())
}
