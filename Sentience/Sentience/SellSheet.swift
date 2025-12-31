//
//  SellSheet.swift
//  Sentience
//
//  Created by Alejandro Morel on 12/18/25.
//
//used to sell data
//shows how much each share is worth, how many shares you have,
//how much x shares will be sold for, confirms if you want to sell

import SwiftUI

struct SellSheet: View {
    let symbol: String
    let currentPrice: Double
    let maxShares: Int
    var onSell: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var sharesText = ""
    @State private var showConfirm = false

    private var shares: Int? { Int(sharesText) }
    private var proceeds: Double { Double(shares ?? 0) * currentPrice }

    var body: some View {
        NavigationStack {
            Form {
                Section("Market Price") {
                    HStack {
                        Text("Price")
                        Spacer()
                        Text(currentPrice, format: .currency(code: "USD")).bold()
                    }
                }

                Section("You Own") {
                    HStack {
                        Text("Max Shares")
                        Spacer()
                        Text("\(maxShares)").bold()
                    }
                }

                Section("Order") {
                    TextField("Shares to sell", text: $sharesText)
                        .keyboardType(.numberPad)

                    HStack {
                        Text("Estimated Proceeds")
                        Spacer()
                        Text(proceeds, format: .currency(code: "USD")).bold()
                    }
                }
            }
            .navigationTitle("Sell \(symbol)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Review") { showConfirm = true }
                        .disabled((shares ?? 0) <= 0 || (shares ?? 0) > maxShares)
                }
            }
            .alert("Confirm Order", isPresented: $showConfirm) {
                Button("Confirm Sell") {
                    if let s = shares, s > 0, s <= maxShares {
                        onSell(s)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Sell \(shares ?? 0) \(symbol) @ \(currentPrice, format: .currency(code: "USD"))\nProceeds: \(proceeds, format: .currency(code: "USD"))")
            }
        }
    }
}
