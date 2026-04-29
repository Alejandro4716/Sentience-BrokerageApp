//
//  APIClient.swift
//  Sentience
//
//  Created by Alejandro Morel on 11/1/25.
//

import Foundation

private let marketDataBase = "https://sentience-brokerageapp-production.up.railway.app"

struct CandleData: Codable {
    let c: [Double]?
    let t: [Int]?
    let s: String
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    func fetchQuote(symbol: String) async throws -> Quote {
        try await get("\(marketDataBase)/market/quote?symbol=\(pct(symbol))")
    }

    func fetchCandles(symbol: String, resolution: String, from: Int, to: Int) async throws -> [Double] {
        let url = "\(marketDataBase)/market/candles?symbol=\(pct(symbol))&resolution=\(resolution)&from_time=\(from)&to=\(to)"
        let candle: CandleData = try await get(url)
        guard candle.s == "ok", let closes = candle.c, !closes.isEmpty else {
            throw FinnhubErrorResponse(error: "No chart data for \(symbol)")
        }
        return closes
    }

    private func get<T: Decodable>(_ urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            if let e = try? JSONDecoder().decode(FinnhubErrorResponse.self, from: data) { throw e }
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func pct(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }
}
