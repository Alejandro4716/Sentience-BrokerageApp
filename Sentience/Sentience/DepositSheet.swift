import SwiftUI

struct DepositSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    var onDeposit: (Double) -> Void

    private var amount: Double? { Double(text) }
    private var canDeposit: Bool { (amount ?? 0) > 0 }

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
                    Text("DEPOSIT")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.vault)
                    Spacer()
                    Text("Cancel").font(.system(size: 14)).foregroundColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 28)

                // Amount card
                VStack(alignment: .leading, spacing: 8) {
                    Text("AMOUNT")
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

                Spacer()

                // Deposit button
                Button {
                    if let amt = amount { onDeposit(amt) }
                    dismiss()
                } label: {
                    Text("DEPOSIT FUNDS")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(canDeposit ? .black : Color(white: 0.3))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(canDeposit ? Color.vault : Color(white: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!canDeposit)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }
}
