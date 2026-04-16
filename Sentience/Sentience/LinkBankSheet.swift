import SwiftUI

struct LinkBankSheet: View {
    @EnvironmentObject var portfolio: PortfolioStore
    @Environment(\.dismiss) private var dismiss

    @State private var routing = ""
    @State private var account = ""

    private var canLink: Bool { !routing.isEmpty && !account.isEmpty }

    var body: some View {
        ZStack {
            Color.vaultBg.ignoresSafeArea()
            VStack(spacing: 0) {

                // Header
                VStack(spacing: 6) {
                    Text("LINK BANK")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.vault)
                    Text("Connect your bank to deposit and withdraw funds.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 36)
                .padding(.bottom, 32)

                VStack(spacing: 16) {
                    // Routing number
                    inputCard(title: "ROUTING NUMBER", placeholder: "9-digit routing number", text: $routing, keyboard: .numberPad)

                    // Account number
                    inputCard(title: "ACCOUNT NUMBER", placeholder: "Account number", text: $account, keyboard: .numberPad)

                    if let err = portfolio.errorMessage {
                        Text(err)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 16)

                Spacer()

                // Link button
                Button {
                    Task {
                        await portfolio.linkBankBackend(routing: routing, account: account)
                        if portfolio.hasBank { dismiss() }
                    }
                } label: {
                    Text("LINK BANK ACCOUNT")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(canLink ? .black : Color(white: 0.3))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(canLink ? Color.vault : Color(white: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!canLink)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }

    @ViewBuilder
    func inputCard(title: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(white: 0.38))
                .padding(.horizontal, 4)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color.vaultCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
