import SwiftUI

struct AccountView: View {
    @EnvironmentObject var portfolio: PortfolioStore
    @EnvironmentObject var flow: AppFlowStore

    @State private var showLinkBank = false

    var body: some View {
        ZStack {
            Color.vaultBg.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {

                    // Header
                    Text("ACCOUNT")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.vault)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    // Avatar + email
                    VStack(spacing: 10) {
                        Circle()
                            .fill(Color.vault)
                            .frame(width: 64, height: 64)
                            .overlay(
                                Text(portfolio.avatarInitials)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.black)
                            )
                        if !portfolio.userEmail.isEmpty {
                            Text(portfolio.userEmail)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(white: 0.55))
                        }
                    }
                    .padding(.top, 12)

                    // Session section
                    sectionCard(title: "SESSION") {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Status")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(white: 0.55))
                                Spacer()
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(portfolio.isLoggedIn ? Color.vault : Color.red)
                                        .frame(width: 7, height: 7)
                                    Text(portfolio.isLoggedIn ? "Active" : "Logged out")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(portfolio.isLoggedIn ? .vault : .red)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                    }

                    // Bank accounts section
                    sectionCard(title: "LINKED BANK ACCOUNTS") {
                        VStack(spacing: 0) {
                            if portfolio.banks.isEmpty {
                                Text("No bank accounts linked")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(white: 0.35))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                            } else {
                                ForEach(portfolio.banks) { b in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Routing •••• \(b.routing_last4)")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white)
                                            Text("Account •••• \(b.account_last4)")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(white: 0.4))
                                        }
                                        Spacer()
                                        Image(systemName: "building.columns.fill")
                                            .foregroundColor(Color(white: 0.3))
                                            .font(.system(size: 16))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    Divider().background(Color(white: 0.12))
                                }
                            }

                            Button {
                                showLinkBank = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.vault)
                                    Text("Add Bank Account")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.vault)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            .disabled(!portfolio.isLoggedIn)
                        }
                    }

                    // Error section
                    if let err = portfolio.errorMessage {
                        sectionCard(title: "STATUS") {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                        }
                    }

                    // Sign out
                    Button {
                        portfolio.logoutBackend()
                        flow.showMain = false
                    } label: {
                        Text("SIGN OUT")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                            )
                    }
                    .disabled(!portfolio.isLoggedIn)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            if portfolio.isLoggedIn { await portfolio.refreshBackend() }
        }
        .sheet(isPresented: $showLinkBank) {
            LinkBankSheet().environmentObject(portfolio)
        }
    }

    @ViewBuilder
    func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(white: 0.38))
                .padding(.horizontal, 4)
            content()
                .background(Color.vaultCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    NavigationView {
        AccountView()
            .environmentObject(AppFlowStore())
            .environmentObject(PortfolioStore())
    }
}
