//
//  WatchlistStore.swift
//  Sentience
//
//  Created by Alejandro Morel on 11/1/25.
//


import Foundation
import Combine

final class WatchlistStore: ObservableObject {
    
    //list of tickers, UI updates when changed
    @Published var symbols: [String] = [] {
        didSet { save() }
    }

    private let key = "watchlist.symbols.v1"

    //loads tickers or adds default ones if none are saved
    init() {
        load()
        if symbols.isEmpty {
            symbols = ["AAPL", "MSFT", "NVDA"]   // seed some examples
        }
    }

    //adds a ticker
    func add(_ raw: String) {
        let s = raw.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, !symbols.contains(s) else { return }
        symbols.append(s)
    }

    //removes a ticker
    func remove(at offsets: IndexSet) {
        symbols.remove(atOffsets: offsets)
    }

    //saves chosen tickers
    private func save() {
        if let data = try? JSONEncoder().encode(symbols) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    //loads saved tickers 
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let arr = try? JSONDecoder().decode([String].self, from: data)
        else { return }
        symbols = arr
    }
}

