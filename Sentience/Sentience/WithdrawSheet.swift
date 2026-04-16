import SwiftUI

struct WithdrawSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    let availableBalance: Double
    var onWithdraw: (Double) -> Void

    private var amount: Double? { Double(text) }
    private var canWithdraw: Bool {
        guard let amt = amount else { return false }
        return amt > 0 && amt <= availableBalance
    }

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
                    Text("WITHDRAW")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.vault)
                    Spacer()
                    Text("Cancel").font(.system(size: 14)).foregroundColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 28)

                VStack(spacing: 16) {
                    // Available balance card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AVAILABLE CASH")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(white: 0.38))
                            .padding(.horizontal, 4)
                        HStack {
                            Text("Balance")
                                .font(.system(size: 14))
                                .foregroundColor(Color(white: 0.55))
                            Spacer()
                            Text(availableBalance, format: .currency(code: "USD"))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.vaultCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 16)

                    // Amount input card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WITHDRAW AMOUNT")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(white: 0.38))
                            .padding(.horizontal, 4)
                        HStack {
                            Text("$")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color(white: 0.38))
                            TextField("0.00", text: $text)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .background(Color.vaultCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 16)

                    if let amt = amount, amt > availableBalance {
                        Text("Exceeds available balance.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                    }
                }

                Spacer()

                // Withdraw button
                Button {
                    if let amt = amount, amt > 0 { onWithdraw(amt) }
                    dismiss()
                } label: {
                    Text("WITHDRAW FUNDS")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(canWithdraw ? .black : Color(white: 0.3))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(canWithdraw ? Color.vault : Color(white: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!canWithdraw)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }
}
