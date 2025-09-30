//
//  PasswordChangeView.swift
//  ANS Calendar
//
//  Created by Stanisław on 08/03/2025.
//

import SwiftUI

struct PasswordChangeView: View {
    @State private var OldPassword: String = ""
    @State private var NewPassword: String = ""
    @State private var ConfirmPassword: String = ""
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Password Change")
                .font(.title)
                .fontWeight(.bold)
            SecureField("Old Password", text: $OldPassword)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
            SecureField("New Password", text: $NewPassword)
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)
            SecureField("Confirm Password", text: $ConfirmPassword)
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)
            Button("Change Password") {
                
            }
            .buttonStyle(.bordered)
        }
        .interactiveDismissDisabled()
    }
}

#Preview {
    PasswordChangeView()
}
