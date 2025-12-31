//
//  FinnhubAPI.swift
//  Sentience
//
//  Created by Alejandro Morel on 11/9/25.
//

import Foundation

struct Quote: Identifiable, Decodable {
    var id: String { symbol }
    let symbol: String
    let price: Double
    let change: Double
    let changePercent: Double
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case c, d, dp, t
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        price = try container.decode(Double.self, forKey: .c)
        change = try container.decodeIfPresent(Double.self, forKey: .d) ?? 0
        changePercent = try container.decodeIfPresent(Double.self, forKey: .dp) ?? 0
        let ts = try container.decodeIfPresent(Double.self, forKey: .t) ?? Date().timeIntervalSince1970
        timestamp = Date(timeIntervalSince1970: ts)
        symbol = "N/A" // placeholder, we'll set it later
    }

    init(symbol: String, price: Double, change: Double, changePercent: Double, timestamp: Date) {
        self.symbol = symbol
        self.price = price
        self.change = change
        self.changePercent = changePercent
        self.timestamp = timestamp
    }
}

final class FinnhubAPI {
    private let apiKey = Bundle.main.object(forInfoDictionaryKey: "FINNHUB_API_KEY") as? String

    func fetchQuote(for symbol: String) async throws -> Quote {
        guard let key = apiKey, !key.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }

        let urlString = "https://finnhub.io/api/v1/quote?symbol=\(symbol)&token=\(key)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        let decoded = try JSONDecoder().decode(Quote.self, from: data)
        // reattach symbol since Finnhub doesn’t return it
        return Quote(symbol: symbol.uppercased(),
                     price: decoded.price,
                     change: decoded.change,
                     changePercent: decoded.changePercent,
                     timestamp: decoded.timestamp)
    }
}
