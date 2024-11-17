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
    @Binding var LoginData: LoginResult
    
    var body: some View {
        VStack() {
            Form {
                TextField("Nr. albumu", text: $username)
                    .autocorrectionDisabled(true)
                    .textContentType(.username)
                    .border(.secondary)
                SecureField("Hasło", text: $password)
                    .border(.secondary)
                Button("Login"){
                    Task {
                        LoginData = await Login(user: username, pass: password)
                    }
                }
            }
            
        }
        .padding()
    }
}



//<a role="menuitem" href="/ppuz-stud-app/ledge/view/stud.schedule.SchedulePage?idosoby=26998&amp;nrtury=1">Plan zajęć</a>

//#Preview {
//    @Previewable @State var success = false
//    LoginView(LoginSucces: $success)
//}
