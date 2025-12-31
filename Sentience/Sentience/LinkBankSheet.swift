//
//  LinkBankSheet.swift
//  Sentience
//
//  Created by Alejandro Morel on 12/17/25.
//


import SwiftUI

struct LinkBankSheet: View {
    @EnvironmentObject var portfolio: PortfolioStore
    @Environment(\.dismiss) private var dismiss

    @State private var routing = ""
    @State private var account = ""

    var body: some View {
        
        //helps add a bank acc
        //bank acc linked is required to use app
        NavigationStack {
            Form {
                Section("Link Bank (fake)") {
                    TextField("Routing number", text: $routing)
                        .keyboardType(.numberPad)
                    TextField("Account number", text: $account)
                        .keyboardType(.numberPad)
                }

                if let err = portfolio.errorMessage {
                    Text(err).foregroundStyle(.red)
                }

                Button("Link Bank") {
                    Task {
                        await portfolio.linkBankBackend(routing: routing, account: account)
                        if portfolio.hasBank { dismiss() }
                    }
                }
                .disabled(routing.isEmpty || account.isEmpty)
            }
            .navigationTitle("Bank Account")
        }
    }
}
