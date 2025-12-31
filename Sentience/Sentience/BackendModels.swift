//
//  BackendModels.swift
//  Sentience
//
//  Created by Alejandro Morel on 12/17/25.
//

import Foundation

// Auth
struct BackendSignupRequest: Codable { let email: String; let password: String }
struct BackendLoginRequest: Codable { let email: String; let password: String }

struct BackendAuthResponse: Codable {
    let token: String
    let user_id: String
}

// Bank accounts
struct BackendBankAccountCreate: Codable {
    let routing_number: String
    let account_number: String
}

struct BackendBankAccountResponse: Codable, Identifiable {
    let id: String
    let routing_last4: String
    let account_last4: String
}

// Account + holdings
struct BackendHolding: Codable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let shares: Int
    let avg_price: Double
}

struct BackendAccountResponse: Codable {
    let account_id: String
    let cash_balance: Double
    let holdings: [BackendHolding]
}

// Money actions (deposit/withdraw)
struct BackendAmountRequest: Codable { let amount: Double }

// Trades
struct BackendTradeRequest: Codable {
    let symbol: String
    let shares: Int
    let price: Double
}

// Transactions
struct BackendTransaction: Codable, Identifiable {
    let id: String
    let type: String
    let symbol: String?
    let shares: Int?
    let price: Double?
    let amount: Double
    let created_at: String
}
