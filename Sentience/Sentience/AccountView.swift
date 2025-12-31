//
//  AccountView.swift
//  Sentience
//
//  Created by Alejandro Morel on 12/18/25.
//


import SwiftUI

struct AccountView: View {
    @EnvironmentObject var portfolio: PortfolioStore
    @EnvironmentObject var flow: AppFlowStore

    @State private var showLinkBank = false

    var body: some View {
        List {
            
            //creates a section label
            Section("Session") {
                if portfolio.isLoggedIn {
                    Text("Status: Logged in")
                        .foregroundStyle(.green)
                } else {
                    Text("Status: Logged out")
                        .foregroundStyle(.secondary)
                }
                
                //button to sign out
                Button(role: .destructive) {
                    portfolio.logoutBackend()
                    flow.showMain = false   //back to opening screen
                } label: {
                    Text("Sign Out")
                }
                .disabled(!portfolio.isLoggedIn)
            }

            //section displaying bank accounts
            Section("Linked Bank Accounts") {
                if portfolio.banks.isEmpty {
                    Text("No bank accounts linked")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(portfolio.banks) { b in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Routing •••• \(b.routing_last4)")
                            Text("Account •••• \(b.account_last4)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }

                //button to add bank accounts
                Button("Add Bank Account…") {
                    showLinkBank = true
                }
                .disabled(!portfolio.isLoggedIn)
            }

            //shows backend errors
            if let err = portfolio.errorMessage {
                Section("Status") {
                    Text(err).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("My Account")
        .task {
            // keep it fresh when tab opens
            if portfolio.isLoggedIn {
                await portfolio.refreshBackend()
            }
        }
        .sheet(isPresented: $showLinkBank) {
            LinkBankSheet()
                .environmentObject(portfolio)
        }
    }
}

//preview account screen
#Preview {
    AccountView()
        .environmentObject(AppFlowStore())
        .environmentObject(PortfolioStore())
        .environmentObject(WatchlistStore())
}
