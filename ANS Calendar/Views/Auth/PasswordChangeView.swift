import SwiftUI

struct PasswordChangeView: View {
    @EnvironmentObject var api: VerbisAPI // Access the API instance
    @Environment(\.dismiss) var dismiss
    
    @State private var OldPassword: String = ""
    @State private var NewPassword: String = ""
    @State private var ConfirmPassword: String = ""
    
    // Alert state variables
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Password Change")
                .font(.title)
                .fontWeight(.bold)
                .padding(.bottom, 10)
            
            SecureField("Old Password", text: $OldPassword)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
            
            SecureField("New Password", text: $NewPassword)
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)
            
            SecureField("Confirm Password", text: $ConfirmPassword)
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)
            
            // Helpful text letting the user know the requirements
            Text("Must be at least 8 characters, with 1 uppercase, 1 lowercase, and 1 number.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                changePasswordAction()
            } label: {
                if api.IsBusy {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Change Password")
                }
            }
            .buttonStyle(.borderedProminent) // Use prominent style for primary actions
            .disabled(OldPassword.isEmpty || NewPassword.isEmpty || ConfirmPassword.isEmpty || api.IsBusy)
            .padding(.top, 10)
        }
        .padding()
        .interactiveDismissDisabled()
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func changePasswordAction() {
        Task {
            do {
                try await api.ChangePassword(Old: OldPassword, New: NewPassword, Confirm: ConfirmPassword)
                
                // On success
                alertTitle = "Success"
                alertMessage = "Your password has been changed successfully."
                showAlert = true
                
                // Optional: Clear fields on success
                OldPassword = ""
                NewPassword = ""
                ConfirmPassword = ""
                dismiss()
                
            } catch let error as VerbisAPIError {
                alertTitle = "Error"
                alertMessage = error.localizedDescription
                showAlert = true
            } catch {
                alertTitle = "Error"
                alertMessage = "An unexpected error occurred."
                showAlert = true
            }
        }
    }
}

#Preview {
    PasswordChangeView()
        .environmentObject(VerbisAPI()) // Inject a mock/test object for the preview
}
