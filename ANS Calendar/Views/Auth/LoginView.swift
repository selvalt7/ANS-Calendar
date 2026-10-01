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
    @FocusState private var focusedField: LoginField?
    @EnvironmentObject var VerbisANSApi: VerbisAPI

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                signInCard
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
            .padding(.bottom, 24)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .onChange(of: username) { _, _ in clearSignInError() }
        .onChange(of: password) { _, _ in clearSignInError() }
    }

    private var header: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("ANS Calendar")
                    .font(.largeTitle.bold())
                Text("Sign in with your student account")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 12)
    }

    private var signInCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            LoginFieldRow(systemImage: "person.text.rectangle") {
                TextField("Album number", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .album)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
            }

            LoginFieldRow(systemImage: "lock") {
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(signIn)
            }

            if let message = signInMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isStaticText)
            }

            Button(action: signIn) {
                Group {
                    if VerbisANSApi.IsBusy {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Sign In")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 22)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSignIn)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        }
    }

    private var canSignIn: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty && !VerbisANSApi.IsBusy
    }

    private var signInMessage: String? {
        switch VerbisANSApi.AuthError {
        case .BadPassword, .NoUser, .SignInFailed:
            return VerbisANSApi.AuthError?.localizedDescription
        default:
            return nil
        }
    }

    private func clearSignInError() {
        switch VerbisANSApi.AuthError {
        case .BadPassword, .NoUser, .SignInFailed:
            VerbisANSApi.AuthError = nil
        default:
            break
        }
    }

    private func signIn() {
        let album = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !album.isEmpty, !password.isEmpty, !VerbisANSApi.IsBusy else { return }
        focusedField = nil
        Task {
            try await VerbisANSApi.Login(user: album, pass: password)
        }
    }
}

private enum LoginField {
    case album
    case password
}

private struct LoginFieldRow<Field: View>: View {
    var systemImage: String
    @ViewBuilder var field: () -> Field

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 22)
                .accessibilityHidden(true)
            field()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    LoginView()
        .environmentObject(VerbisAPI())
}
