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
    
    //persists the auth token
    @AppStorage("authToken") var authToken: String = ""

    //UI updates if these changes
    @Published var availableFunds: Double = 0
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
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    //logs in, stores token, refreshes
    func loginBackend(email: String, password: String) async {
        do {
            let auth = try await BackendAPI.shared.login(email: email, password: password)
            authToken = auth.token
            await refreshBackend()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    //signs up, stores token, refreshes
    func signupBackend(email: String, password: String) async {
        do {
            let auth = try await BackendAPI.shared.signup(email: email, password: password)
            authToken = auth.token
            await refreshBackend()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    //clears session and resets UI
    func logoutBackend() {
        authToken = ""
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
    

}

//local app model
struct Holding: Identifiable, Codable {
    var id: String { symbol }
    let symbol: String
    var shares: Int
    var avgPrice: Double
}

