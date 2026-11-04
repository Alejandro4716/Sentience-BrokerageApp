import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject var portfolio: PortfolioStore
    @Environment(\.dismiss) private var dismiss

    @State private var isSignup = false
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false

    private var canSubmit: Bool {
        let hasCredentials = !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
        if !isSignup { return hasCredentials }
        return hasCredentials
            && !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Color.vaultBg.ignoresSafeArea()

            RadialGradient(
                colors: [Color.vault.opacity(0.06), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 360
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Text("SENTIENCE")
                            .font(.system(size: 32, weight: .black))
                            .foregroundColor(.vault)
                        Text(isSignup ? "Create your brokerage profile" : "Welcome back")
                            .font(.system(size: 13))
                            .foregroundColor(Color(white: 0.42))
                    }
                    .padding(.top, 58)
                    .padding(.bottom, 36)

                    VStack(spacing: 16) {
                        if isSignup {
                            HStack(spacing: 12) {
                                inputCard(
                                    title: "FIRST NAME",
                                    placeholder: "First",
                                    text: $firstName,
                                    keyboard: .default,
                                    secure: false,
                                    capitalization: .words
                                )
                                inputCard(
                                    title: "LAST NAME",
                                    placeholder: "Last",
                                    text: $lastName,
                                    keyboard: .default,
                                    secure: false,
                                    capitalization: .words
                                )
                            }
                        }

                        inputCard(
                            title: "EMAIL",
                            placeholder: "you@example.com",
                            text: $email,
                            keyboard: .emailAddress,
                            secure: false
                        )

                        inputCard(
                            title: "PASSWORD",
                            placeholder: "••••••••",
                            text: $password,
                            keyboard: .default,
                            secure: true
                        )

                        if let err = portfolio.errorMessage {
                            Text(err)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 48)

                    VStack(spacing: 14) {
                        Button { submit() } label: {
                            Group {
                                if isLoading {
                                    ProgressView().tint(.black)
                                } else {
                                    Text(isSignup ? "CREATE ACCOUNT" : "LOG IN")
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

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSignup.toggle()
                                portfolio.errorMessage = nil
                            }
                        } label: {
                            Text(isSignup ? "ALREADY HAVE AN ACCOUNT? LOG IN" : "NEW TO SENTIENCE? CREATE ACCOUNT")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(white: 0.55))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func submit() {
        isLoading = true
        Task {
            if isSignup {
                await portfolio.signupBackend(
                    firstName: firstName.trimmingCharacters(in: .whitespaces),
                    lastName: lastName.trimmingCharacters(in: .whitespaces),
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            } else {
                await portfolio.loginBackend(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            }
            isLoading = false
            if portfolio.isLoggedIn { dismiss() }
        }
    }

    @ViewBuilder
    private func inputCard(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        secure: Bool,
        capitalization: TextInputAutocapitalization = .never
    ) -> some View {
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
                        .textInputAutocapitalization(capitalization)
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
        .frame(maxWidth: .infinity)
    }
}
