//
//  Quote.swift
//  Sentience
//
//  Created by Alejandro Morel on 11/9/25.
//  turn finnhub json data into useful data


// Quote.swift
import Foundation

//provides data for each variable of each chosen ticker 
struct Quote: Codable {
    let current: Double
    let change: Double
    let percentChange: Double
    let high: Double
    let low: Double
    let open: Double
    let previousClose: Double

    enum CodingKeys: String, CodingKey {
        case current = "c"
        case change = "d"
        case percentChange = "dp"
        case high = "h"
        case low = "l"
        case open = "o"
        case previousClose = "pc"
    }
}

struct FinnhubErrorResponse: Codable, Error, LocalizedError {
    let error: String
    var errorDescription: String? { error }
}
