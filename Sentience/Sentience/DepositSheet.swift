//
//  DepositSheet.swift
//  Sentience
//
//  Created by Alejandro Morel on 11/1/25.
//


import SwiftUI

struct DepositSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    var onDeposit: (Double) -> Void

    var body: some View {
        
        //allows deposits
        //calls backend deposit function
        NavigationStack {
            Form {
                TextField("Amount (e.g., 1000)", text: $text)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Deposit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let amt = Double(text) { onDeposit(amt) }
                        dismiss()
                    }
                    .disabled(Double(text) == nil || (Double(text) ?? 0) <= 0)
                }
            }
        }
    }
}
