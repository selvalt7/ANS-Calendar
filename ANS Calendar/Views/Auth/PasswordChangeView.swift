import SwiftUI

func passwordConfirmationMismatch(newPassword: String, confirmation: String) -> Bool {
    !confirmation.isEmpty && newPassword != confirmation
}

func passwordMeetsRules(_ password: String) -> Bool {
    password.range(of: "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{8,}$", options: .regularExpression) != nil
}

struct PasswordChangeView: View {
    @EnvironmentObject var api: VerbisAPI
    @Environment(\.dismiss) var dismiss

    @State private var oldPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @FocusState private var focusedField: PasswordField?

    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var passwordDidChange = false

    private var mustChangePassword: Bool { api.AuthError == .ExpiredPassword }
    private var passwordsMismatch: Bool { passwordConfirmationMismatch(newPassword: newPassword, confirmation: confirmPassword) }
    private var newPasswordIsValid: Bool { passwordMeetsRules(newPassword) }
    private var canSubmit: Bool {
        !oldPassword.isEmpty && newPasswordIsValid && !confirmPassword.isEmpty && !passwordsMismatch && !api.IsBusy
    }

    var body: some View {
        NavigationStack {
            Form {
                if mustChangePassword {
                    Section {
                        Label("Your password has expired. Choose a new one to continue.", systemImage: "exclamationmark.shield")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    SecureField("Current password", text: $oldPassword)
                        .textContentType(.password)
                        .focused($focusedField, equals: .current)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .new }
                }

                Section {
                    SecureField("New password", text: $newPassword)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .new)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .confirm }

                    SecureField("Confirm password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirm)
                        .submitLabel(.done)
                        .onSubmit(changePasswordAction)

                    if passwordsMismatch {
                        Label("Passwords do not match.", systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityAddTraits(.isStaticText)
                    }
                } footer: {
                    if !passwordsMismatch && !confirmPassword.isEmpty && newPassword == confirmPassword {
                        Text("Passwords match.")
                            .foregroundStyle(.green)
                    }
                }

                Section("New password must have") {
                    requirementRow("At least 8 characters", isMet: newPassword.count >= 8)
                    requirementRow("One uppercase letter", isMet: newPassword.range(of: "[A-Z]", options: .regularExpression) != nil)
                    requirementRow("One lowercase letter", isMet: newPassword.range(of: "[a-z]", options: .regularExpression) != nil)
                    requirementRow("One number", isMet: newPassword.range(of: #"\d"#, options: .regularExpression) != nil)
                }

                Section {
                    Button(action: changePasswordAction) {
                        HStack {
                            Spacer()
                            if api.IsBusy {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Change Password")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !mustChangePassword {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
        .interactiveDismissDisabled(mustChangePassword)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {
                if passwordDidChange {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }

    private func requirementRow(_ title: String, isMet: Bool) -> some View {
        Label(title, systemImage: isMet ? "checkmark.circle.fill" : "circle")
            .font(.subheadline)
            .foregroundStyle(isMet ? Color.green : Color.secondary)
    }

    private func changePasswordAction() {
        guard canSubmit else { return }
        focusedField = nil
        Task {
            do {
                try await api.ChangePassword(Old: oldPassword, New: newPassword, Confirm: confirmPassword)
                passwordDidChange = true
                alertTitle = "Password changed"
                alertMessage = "Your password has been changed."
                showAlert = true
            } catch let error as VerbisAPIError {
                passwordDidChange = false
                alertTitle = "Couldn't change password"
                alertMessage = error.localizedDescription
                showAlert = true
            } catch {
                passwordDidChange = false
                alertTitle = "Couldn't change password"
                alertMessage = "An unexpected error occurred."
                showAlert = true
            }
        }
    }
}

private enum PasswordField {
    case current
    case new
    case confirm
}

#Preview {
    PasswordChangeView()
        .environmentObject(VerbisAPI())
}
