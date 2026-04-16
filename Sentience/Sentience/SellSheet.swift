import SwiftUI

struct SellSheet: View {
    let symbol: String
    let currentPrice: Double
    let maxShares: Int
    var onSell: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var sharesText = ""
    @State private var showConfirm = false
    @FocusState private var sharesFocused: Bool

    private var shares: Int? { Int(sharesText) }
    private var proceeds: Double { Double(shares ?? 0) * currentPrice }
    private var canReview: Bool { (shares ?? 0) > 0 && (shares ?? 0) <= maxShares }

    var body: some View {
        ZStack {
            Color.vaultBg.ignoresSafeArea()
            VStack(spacing: 0) {

                // Header
                HStack {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(white: 0.5))
                    Spacer()
                    Text("SELL \(symbol)")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.vault)
                    Spacer()
                    Text("Cancel").font(.system(size: 14)).foregroundColor(.clear) // balance
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 28)

                VStack(spacing: 16) {
                    // Market price card
                    cardSection(title: "MARKET PRICE") {
                        infoRow(label: "Price") {
                            Text(currentPrice, format: .currency(code: "USD"))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    // You own card
                    cardSection(title: "YOU OWN") {
                        infoRow(label: "Available Shares") {
                            Text("\(maxShares)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    // Order card
                    cardSection(title: "ORDER") {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Shares to Sell")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(white: 0.55))
                                Spacer()
                                TextField("0", text: $sharesText)
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.trailing)
                                    .focused($sharesFocused)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                            .onTapGesture { sharesFocused = true }

                            Divider().background(Color(white: 0.12))

                            infoRow(label: "Estimated Proceeds") {
                                Text(proceeds, format: .currency(code: "USD"))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.vault)
                            }
                        }
                    }

                    if let s = shares, s > maxShares {
                        Text("You only own \(maxShares) shares.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 16)

                Spacer()

                // Review button
                Button { showConfirm = true } label: {
                    Text("REVIEW ORDER")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(canReview ? .black : Color(white: 0.3))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(canReview ? Color.vault : Color(white: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!canReview)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .alert("Confirm Order", isPresented: $showConfirm) {
            Button("Confirm Sell") {
                if let s = shares, s > 0, s <= maxShares { onSell(s); dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Sell \(shares ?? 0) \(symbol) @ \(currentPrice, format: .currency(code: "USD"))\nProceeds: \(proceeds, format: .currency(code: "USD"))")
        }
    }

    @ViewBuilder
    func cardSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(white: 0.38))
                .padding(.horizontal, 4)
            content()
                .background(Color.vaultCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    func infoRow<V: View>(label: String, @ViewBuilder value: () -> V) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.55))
            Spacer()
            value()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
