//
//  MyPortfolioView.swift
//  Sentience
//
//  Created by Alejandro Morel on 11/1/25.
//


import SwiftUI

struct MyPortfolioView: View {
    @EnvironmentObject var portfolio: PortfolioStore
    @State private var showDeposit = false
    @State private var showWithdraw = false

    //displays portfolio information
    var body: some View {
        List {
            //shows cash balance and deposit/withdraw buttons
            Section("Cash") {
                HStack {
                    Text("Balance")
                    Spacer()
                    Text(portfolio.cashBalance, format: .currency(code: "USD"))
                        .bold()
                }
                
                
                Button("Deposit") { showDeposit = true }
                Button("Withdraw") { showWithdraw = true}
            }
            
            //shows owned stocks
            Section("Holdings") {
                if portfolio.holdings.isEmpty {
                    Text("No stocks yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(portfolio.holdings) { h in
                        HStack {
                            Text(h.symbol)
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(h.shares) shares").font(.caption)
                                Text(h.avgPrice, format: .currency(code: "USD"))
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
            //displays an error message if error occurs
            if let err = portfolio.errorMessage {
                Section("Status") {
                    Text(err).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("My Portfolio")
        .sheet(isPresented: $showDeposit) {
            DepositSheet { amt in
                Task {
                    await portfolio.depositBackend(amt)
                }
            }
            .presentationDetents([.fraction(0.75)])
        }
        .sheet(isPresented: $showWithdraw) {
            WithdrawSheet(
                availableBalance: portfolio.cashBalance
            ) { amt in
                Task {
                    await portfolio.withdrawBackend(amt)
                }
            }
            .presentationDetents([.fraction(0.75)])
        }


    }
}

#Preview {
    MyPortfolioView()
        .environmentObject(PortfolioStore())
}
