//
//  PortfolioStore.swift
//  Sentience
//
//  Created by Alejandro Morel on 11/1/25.
//  Uses BackendAPI functions and updates UI

import SwiftUI
import Foundation
import Combine

final class PortfolioStore: ObservableObject {

    @Published var authToken: String = "" {
        didSet {
            if authToken.isEmpty {
                KeychainHelper.shared.delete(for: "authToken")
            } else {
                KeychainHelper.shared.save(authToken, for: "authToken")
            }
        }
    }

    @AppStorage("userEmail") var userEmail: String = ""

    init() {
        let keychainToken = KeychainHelper.shared.load(for: "authToken")
        if !keychainToken.isEmpty {
            // Already in Keychain — use it directly (skip didSet)
            _authToken = Published(initialValue: keychainToken)
        } else {
            // Migrate legacy UserDefaults token to Keychain on first launch after update
            let legacy = UserDefaults.standard.string(forKey: "authToken") ?? ""
            _authToken = Published(initialValue: legacy)
            if !legacy.isEmpty {
                KeychainHelper.shared.save(legacy, for: "authToken")
                UserDefaults.standard.removeObject(forKey: "authToken")
            }
        }
    }

    var avatarInitials: String {
        let parts = userEmail.components(separatedBy: "@").first?
            .components(separatedBy: CharacterSet(charactersIn: "._-")) ?? []
        let letters = parts.compactMap { $0.first?.uppercased() }
        if letters.count >= 2 { return letters[0] + letters[1] }
        return userEmail.prefix(2).uppercased()
    }

    //UI updates if these changes
    @Published var banks: [BackendBankAccountResponse] = [] //list of bank accounts
    @Published var txns: [BackendTransaction] = []  //list of transactions
    @Published var errorMessage: String? = nil  //error messages
    
    //requires bank acc linked
    var needsBankLink: Bool {
        isLoggedIn && banks.isEmpty
    }

    
    
    @MainActor
    //takes backend AccountResponse and converts it into Holding model
    private func apply(_ acct: BackendAccountResponse) {
        cashBalance = acct.cash_balance

        holdings = acct.holdings.map { BackendHolding in
            Holding(symbol: BackendHolding.symbol,
                    shares: BackendHolding.shares,
                    avgPrice: BackendHolding.avg_price)
        }
    }

    
    @MainActor
    //fetches latest data from backend and keeps things updated
    func refreshBackend() async {
        guard isLoggedIn else { return }
        do {
            let acct = try await BackendAPI.shared.account(token: authToken)
            apply(acct)
            banks = try await BackendAPI.shared.listBanks(token: authToken)
            txns = try await BackendAPI.shared.transactions(token: authToken)
            errorMessage = nil
        } catch {
            if isUnauthorized(error) {
                logoutBackend()                 // clears authToken + state
                errorMessage = "Session expired. Please log in again."
                return
            }
            errorMessage = error.localizedDescription
        }

    }

    @MainActor
    func loginBackend(email: String, password: String) async {
        do {
            let auth = try await BackendAPI.shared.login(email: email, password: password)
            authToken = auth.token
            userEmail = email
            await refreshBackend()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func signupBackend(email: String, password: String) async {
        do {
            let auth = try await BackendAPI.shared.signup(email: email, password: password)
            authToken = auth.token
            userEmail = email
            await refreshBackend()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func logoutBackend() {
        authToken = ""
        userEmail = ""
        banks = []
        txns = []
        cashBalance = 0
        holdings = []
        errorMessage = nil
    }

    @MainActor
    //sends bank acc to backend
    func linkBankBackend(routing: String, account: String) async {
        guard isLoggedIn else { return }
        do {
            _ = try await BackendAPI.shared.linkBank(routing: routing, account: account, token: authToken)
            banks = try await BackendAPI.shared.listBanks(token: authToken)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    //deposit logic for backend
    func depositBackend(_ amount: Double) async {
        guard isLoggedIn else { return }
        do {
            let acct = try await BackendAPI.shared.deposit(amount: amount, token: authToken)
            apply(acct)
            txns = try await BackendAPI.shared.transactions(token: authToken)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    //withdraw logic for backend
    func withdrawBackend(_ amount: Double) async {
        guard isLoggedIn else { return }
        do {
            let acct = try await BackendAPI.shared.withdraw(amount: amount, token: authToken)
            apply(acct)
            txns = try await BackendAPI.shared.transactions(token: authToken)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    //back end logics to buy stocks
    func buyBackend(symbol: String, shares: Int, price: Double) async {
        guard isLoggedIn else { return }
        do {
            let acct = try await BackendAPI.shared.buy(symbol: symbol, shares: shares, price: price, token: authToken)
            apply(acct)
            txns = try await BackendAPI.shared.transactions(token: authToken)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    //backend logic to sell stocks
    func sellBackend(symbol: String, shares: Int, price: Double) async {
        guard isLoggedIn else { return }
        do {
            let acct = try await BackendAPI.shared.sell(symbol: symbol, shares: shares, price: price, token: authToken)
            apply(acct)
            txns = try await BackendAPI.shared.transactions(token: authToken)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    

    var isLoggedIn: Bool { !authToken.isEmpty }
    var hasBank: Bool { !banks.isEmpty }

    @Published var cashBalance: Double = 0
    @Published var holdings: [Holding] = []
    @Published var liveQuotes: [String: Quote] = [:]

    var totalEquityValue: Double {
        holdings.reduce(0.0) { sum, h in
            sum + (liveQuotes[h.symbol]?.current ?? h.avgPrice) * Double(h.shares)
        }
    }

    var dayPnL: Double {
        holdings.reduce(0.0) { sum, h in
            sum + (liveQuotes[h.symbol]?.change ?? 0) * Double(h.shares)
        }
    }

    @MainActor
    func refreshLiveQuotes() async {
        let syms = holdings.map(\.symbol)
        guard !syms.isEmpty else { return }
        var result: [String: Quote] = [:]
        await withTaskGroup(of: (String, Quote?).self) { group in
            for sym in syms {
                group.addTask { (sym, try? await APIClient.shared.fetchQuote(symbol: sym)) }
            }
            for await (sym, q) in group {
                if let q { result[sym] = q }
            }
        }
        liveQuotes = result
    }

}

//local app model
struct Holding: Identifiable, Codable, Equatable {
    var id: String { symbol }
    let symbol: String
    var shares: Int
    var avgPrice: Double
}


private func isUnauthorized(_ error: Error) -> Bool {
    if let backendError = error as? BackendError {
        switch backendError {
        case .badStatus(let code, _):
            return code == 401
        default:
            return false
        }
    }
    return false
}

