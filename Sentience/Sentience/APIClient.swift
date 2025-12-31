//
//  APIClient.swift
//  Sentience
//
//  Created by Alejandro Morel on 11/1/25.
//

import Foundation

enum Secrets {
    static var finnhubAPIKey: String {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
            let key = dict["FINNHUB_API_KEY"] as? String,
            !key.isEmpty
        else {
            fatalError("Missing FINNHUB_API_KEY in Secrets.plist")
        }
        return key
    }
}





//define class
final class APIClient {
    //make 1 instance
    static let shared = APIClient()
    private init() {}

    //Finnhub API key
    private let apiKey = Secrets.finnhubAPIKey

    //functions search Finnhub for given ticker
    //and returns json data
    func fetchQuote(symbol: String) async throws -> Quote {
        
        //prevention
        guard let encodedSym = symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw URLError(.badURL)
        }
        
        //make url string
        let urlStr = "https://finnhub.io/api/v1/quote?symbol=\(encodedSym)&token=\(apiKey)"
        
        //convert to url object
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }

        let (data, resp) = try await URLSession.shared.data(from: url)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0

        guard code == 200 else {
            if let serverErr = try? JSONDecoder().decode(FinnhubErrorResponse.self, from: data) {
                throw serverErr
            }
            throw URLError(.badServerResponse)
        }

        //convert json into Quote model
        return try JSONDecoder().decode(Quote.self, from: data)
    }
}
