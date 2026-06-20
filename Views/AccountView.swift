import SwiftUI

/// Login / register screen that links the app to the Firashome Tasks API.
struct AccountView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.modelContext) private var context

    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var mode: Mode = .login
    @ObservedObject private var theme = ThemeManager.shared

    private enum Mode: String, CaseIterable { case login = "Sign in", register = "Create account" }

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $theme.raw) {
                    ForEach(AppTheme.allCases, id: \.rawValue) { t in
                        Text(t.label).tag(t.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("theme-picker")
            }
            Section("Backend") {
                TextField("API URL", text: $auth.baseURL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("account-api-url")
            }
            if auth.isLoggedIn {
                Section("Account") {
                    LabeledContent("Email", value: auth.email ?? "—")
                }
                Section("Sync") {
                    Text(auth.status).font(.subheadline).foregroundStyle(TK.secondary)
                    Button {
                        Task { await auth.syncNow(context: context) }
                    } label: {
                        HStack { Image(systemName: "arrow.triangle.2.circlepath"); Text(auth.isBusy ? "Syncing…" : "Sync now") }
                    }
                    .disabled(auth.isBusy)
                    .accessibilityIdentifier("account-sync")
                }
                Section { Button("Sign out", role: .destructive) { auth.logout() } }
            } else {
                Section {
                    if mode == .register {
                        TextField("Name", text: $name).accessibilityIdentifier("account-name")
                    }
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never).keyboardType(.emailAddress)
                        .accessibilityIdentifier("account-email")
                    SecureField("Password", text: $password).accessibilityIdentifier("account-password")
                }
                Section {
                    Button {
                        Task {
                            if mode == .login { _ = await auth.login(email: email, password: password) }
                            else { _ = await auth.register(email: email, password: password, name: name) }
                        }
                    } label: { Text(mode.rawValue).font(.headline) }
                        .frame(maxWidth: .infinity)
                        .disabled(email.isEmpty || password.count < 6 || auth.isBusy)
                        .accessibilityIdentifier("account-submit")
                    if !auth.status.isEmpty {
                        Text(auth.status).font(.footnote).foregroundStyle(TK.accent)
                    }
                }
                Section {
                    Picker("", selection: $mode) { ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        .pickerStyle(.segmented)
                }
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.large)
    }
}
