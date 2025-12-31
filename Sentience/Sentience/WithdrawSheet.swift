//
//  WithdrawSheet.swift
//  Sentience
//
//  Created by Alejandro Morel on 12/18/25.
//
//helps calculate withdrawals

import SwiftUI

struct WithdrawSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    let availableBalance: Double
    var onWithdraw: (Double) -> Void

    var body: some View {
        NavigationStack {
            //shows available balance
            Form {
                Section("Available Cash") {
                    HStack {
                        Text("Balance")
                        Spacer()
                        Text(availableBalance, format: .currency(code: "USD"))
                            .bold()
                    }
                }

                //asks for how much to withdraw
                Section("Withdraw Amount") {
                    TextField("Amount (e.g. 500)", text: $text)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Withdraw")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Withdraw") {
                        if let amt = Double(text), amt > 0 {
                            onWithdraw(amt)
                        }
                        dismiss()
                    }
                    .disabled(
                        Double(text) == nil ||
                        (Double(text) ?? 0) <= 0 ||
                        (Double(text) ?? 0) > availableBalance
                    )
                }
            }
        }
    }
}
