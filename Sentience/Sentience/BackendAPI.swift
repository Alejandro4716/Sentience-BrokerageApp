//
//  BackendAPI.swift
//  Sentience
//
//  Created by Alejandro Morel on 12/17/25.
//  Commands backend

import Foundation

//custom errors
enum BackendError: Error, LocalizedError {
    case badURL
    case badStatus(Int, String)
    case decode(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Bad backend URL"
        case .badStatus(let code, let msg): return "Backend HTTP \(code): \(msg)"
        case .decode(let msg): return "Backend decode error: \(msg)"
        }
    }
}

final class BackendAPI {
    static let shared = BackendAPI()
    private init() {}

    private let base = "https://sentience-brokerageapp-production.up.railway.app"

    private func makeRequest(path: String, method: String, token: String? = nil, body: Data? = nil) throws -> URLRequest {
        
        //build url
        guard let url = URL(string: base + path) else { throw BackendError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
        return req
    }

    //send request and decode
    private func run<T: Decodable>(_ req: URLRequest, as: T.Type) async throws -> T {
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1

        if !(200...299).contains(code) {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw BackendError.badStatus(code, msg)
        }

        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw BackendError.decode(error.localizedDescription) }
    }

    //signs up user
    func signup(email: String, password: String) async throws -> BackendAuthResponse {
        let body = try JSONEncoder().encode(BackendSignupRequest(email: email, password: password))
        let req = try makeRequest(path: "/auth/signup", method: "POST", body: body)
        return try await run(req, as: BackendAuthResponse.self)
    }

    //logs user in
    func login(email: String, password: String) async throws -> BackendAuthResponse {
        let body = try JSONEncoder().encode(BackendLoginRequest(email: email, password: password))
        let req = try makeRequest(path: "/auth/login", method: "POST", body: body)
        return try await run(req, as: BackendAuthResponse.self)
    }

    //returns account data: balance, holdings
    func account(token: String) async throws -> BackendAccountResponse {
        let req = try makeRequest(path: "/account", method: "GET", token: token)
        return try await run(req, as: BackendAccountResponse.self)
    }

    //allows deposits
    func deposit(amount: Double, token: String) async throws -> BackendAccountResponse {
        let body = try JSONEncoder().encode(BackendAmountRequest(amount: amount))
        let req = try makeRequest(path: "/deposit", method: "POST", token: token, body: body)
        return try await run(req, as: BackendAccountResponse.self)
    }

    //allows withdrawals
    func withdraw(amount: Double, token: String) async throws -> BackendAccountResponse {
        let body = try JSONEncoder().encode(BackendAmountRequest(amount: amount))
        let req = try makeRequest(path: "/withdraw", method: "POST", token: token, body: body)
        return try await run(req, as: BackendAccountResponse.self)
    }

    //buys stocks
    func buy(symbol: String, shares: Int, price: Double, token: String) async throws -> BackendAccountResponse {
        let body = try JSONEncoder().encode(BackendTradeRequest(symbol: symbol, shares: shares, price: price))
        let req = try makeRequest(path: "/trade/buy", method: "POST", token: token, body: body)
        return try await run(req, as: BackendAccountResponse.self)
    }

    //sells stocks
    func sell(symbol: String, shares: Int, price: Double, token: String) async throws -> BackendAccountResponse {
        let body = try JSONEncoder().encode(BackendTradeRequest(symbol: symbol, shares: shares, price: price))
        let req = try makeRequest(path: "/trade/sell", method: "POST", token: token, body: body)
        return try await run(req, as: BackendAccountResponse.self)
    }


    //links bank accounts
    func linkBank(routing: String, account: String, token: String) async throws -> BackendBankAccountResponse {
        let body = try JSONEncoder().encode(BackendBankAccountCreate(routing_number: routing, account_number: account))
        let req = try makeRequest(path: "/bank-accounts", method: "POST", token: token, body: body)
        return try await run(req, as: BackendBankAccountResponse.self)
    }

    //lists bank accs
    func listBanks(token: String) async throws -> [BackendBankAccountResponse] {
        let req = try makeRequest(path: "/bank-accounts", method: "GET", token: token)
        return try await run(req, as: [BackendBankAccountResponse].self)
    }

    //stores transactions 
    func transactions(token: String) async throws -> [BackendTransaction] {
        let req = try makeRequest(path: "/transactions", method: "GET", token: token)
        return try await run(req, as: [BackendTransaction].self)
    }
}
