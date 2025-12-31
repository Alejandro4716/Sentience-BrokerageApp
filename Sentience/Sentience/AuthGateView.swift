//
//  AuthGateView.swift
//  Sentience
//
//  Created by Alejandro Morel on 12/17/25.
//


import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject var portfolio: PortfolioStore
    @Environment(\.dismiss) private var dismiss

    //required to open account
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                //enter email and password
                Section("Login / Sign Up") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                }

                if let err = portfolio.errorMessage {
                    Text(err).foregroundStyle(.red)
                }

                Button("Login") {
                    Task {
                        await portfolio.loginBackend(email: email, password: password)
                        if portfolio.isLoggedIn { dismiss() }
                    }
                }

                Button("Sign Up") {
                    Task {
                        await portfolio.signupBackend(email: email, password: password)
                        if portfolio.isLoggedIn { dismiss() }
                    }
                }
            }
            .navigationTitle("Account")
        }
    }
}
