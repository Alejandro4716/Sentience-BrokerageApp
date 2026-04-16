import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject var portfolio: PortfolioStore
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false

    private var canSubmit: Bool { !email.isEmpty && !password.isEmpty }

    var body: some View {
        ZStack {
            Color.vaultBg.ignoresSafeArea()
            VStack(spacing: 0) {

                // Logo / title
                VStack(spacing: 8) {
                    Text("SENTIENCE")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.vault)
                    Text("Your intelligent brokerage")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.38))
                }
                .padding(.top, 56)
                .padding(.bottom, 40)

                VStack(spacing: 16) {
                    // Email field
                    inputCard(title: "EMAIL", placeholder: "you@example.com", text: $email, keyboard: .emailAddress, secure: false)

                    // Password field
                    inputCard(title: "PASSWORD", placeholder: "••••••••", text: $password, keyboard: .default, secure: true)

                    if let err = portfolio.errorMessage {
                        Text(err)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 16)

                Spacer()

                VStack(spacing: 12) {
                    // Login
                    Button {
                        isLoading = true
                        Task {
                            await portfolio.loginBackend(email: email, password: password)
                            isLoading = false
                            if portfolio.isLoggedIn { dismiss() }
                        }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView().tint(.black)
                            } else {
                                Text("LOG IN")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(canSubmit ? .black : Color(white: 0.3))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(canSubmit ? Color.vault : Color(white: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(!canSubmit || isLoading)

                    // Sign up
                    Button {
                        isLoading = true
                        Task {
                            await portfolio.signupBackend(email: email, password: password)
                            isLoading = false
                            if portfolio.isLoggedIn { dismiss() }
                        }
                    } label: {
                        Text("CREATE ACCOUNT")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(canSubmit ? .white : Color(white: 0.3))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(canSubmit ? Color(white: 0.3) : Color(white: 0.15), lineWidth: 1.5)
                            )
                    }
                    .disabled(!canSubmit || isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }

    @ViewBuilder
    func inputCard(title: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType, secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(white: 0.38))
                .padding(.horizontal, 4)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.vaultCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
