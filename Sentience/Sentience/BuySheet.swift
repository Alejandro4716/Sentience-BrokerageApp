import SwiftUI

struct BuySheet: View {
    let symbol: String
    let currentPrice: Double
    var onBuy: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var sharesText = ""
    @State private var showConfirm = false

    private var shares: Int? { Int(sharesText) }
    private var totalCost: Double {
        Double(shares ?? 0) * currentPrice
    }

    var body: some View {
        NavigationStack {
            Form {
                
                //shows price of ticker
                Section("Market Price") {
                    HStack {
                        Text("Price")
                        Spacer()
                        Text(currentPrice, format: .currency(code: "USD"))
                            .bold()
                    }
                }

                //asks for number of shares wanted
                Section("Order") {
                    TextField("Shares", text: $sharesText)
                        .keyboardType(.numberPad)

                    //calculates cost of x shares to be bought
                    HStack {
                        Text("Estimated Cost")
                        Spacer()
                        Text(totalCost, format: .currency(code: "USD"))
                            .bold()
                    }
                }
            }
            .navigationTitle("Buy \(symbol)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Review") {
                        showConfirm = true
                    }
                    .disabled((shares ?? 0) <= 0)
                }
            }
            //confirmation
            .alert("Confirm Order", isPresented: $showConfirm) {
                Button("Confirm Buy", role: .none) {
                    if let s = shares, s > 0 {
                        onBuy(s)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Buy \(shares ?? 0) \(symbol) @ \(currentPrice, format: .currency(code: "USD"))\nTotal: \(totalCost, format: .currency(code: "USD"))")
            }
        }
    }
}
