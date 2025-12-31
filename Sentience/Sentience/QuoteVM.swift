//
//  QuoteVM.swift
//  Sentience
//
//  Created by Alejandro Morel on 11/9/25.
//


//get into finnhub, fetch data, updates quote struct
import Foundation

@MainActor
final class QuoteVM: ObservableObject {
    @Published var quote: Quote?
    @Published var errorText: String?
    @Published var isLoading = false

    func load(symbol: String) {
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let q = try await APIClient.shared.fetchQuote(symbol: symbol)
                self.quote = q
                self.errorText = nil
            } catch {
                self.quote = nil
                self.errorText = (error as? LocalizedError)?.errorDescription
                                 ?? String(describing: error)
            }
        }
    }
}
