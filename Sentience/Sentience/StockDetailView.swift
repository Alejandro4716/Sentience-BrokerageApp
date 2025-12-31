//
//  StockDetailView.swift
//  Sentience
//
//  Created by Alejandro Morel on 11/1/25.
//
// when a stock is pressed and viewed:
        //shows current price
        //% change
        //option to buy
        //option to sell if shares are owned


import SwiftUI

struct StockDetailView: View {
    let symbol: String
    @EnvironmentObject var portfolio: PortfolioStore
    @State private var showBuy = false
    @State private var showSell = false
    @StateObject private var vm = QuoteVM()

    var ownedShares: Int {
        portfolio.holdings.first(where: { $0.symbol == symbol })?.shares ?? 0
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(symbol).font(.largeTitle).bold()

            if let q = vm.quote {
                VStack(spacing: 4) {
                    Text(q.current, format: .currency(code: "USD")).font(.title).bold()
                    Text("Δ \(q.change, specifier: "%.2f") (\(q.percentChange, specifier: "%.2f")%)")
                        .foregroundStyle(q.percentChange >= 0 ? .green : .red)
                }
            } else if let err = vm.errorText {
                Text(err).foregroundStyle(.red)
            } else {
                Text("Loading…").foregroundStyle(.secondary)
            }

            Button("Buy \(symbol)") { showBuy = true } // (your existing buy button)
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.yellow)
                .foregroundStyle(.black)
                .clipShape(Capsule())
                .padding(.top, 20)
            
            if ownedShares > 0 {
                Button("Sell \(symbol)") { showSell = true }
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.black.opacity(0.1))
                    .clipShape(Capsule())
            }

        }
        .onAppear { vm.load(symbol: symbol) }
        .padding()
        .navigationTitle(symbol)
        .navigationBarTitleDisplayMode(.inline)
        
        .sheet(isPresented: $showBuy) {
            if let price = vm.quote?.current {
                BuySheet(symbol: symbol, currentPrice: price) { shares in
                    Task { await portfolio.buyBackend(symbol: symbol, shares: shares, price: price) }
                }
                .presentationDetents([.fraction(0.65)])
            } else {
                Text("Loading price…")
                    .padding()
            }
        }
        
        .sheet(isPresented: $showSell) {
            if let price = vm.quote?.current {
                SellSheet(
                    symbol: symbol,
                    currentPrice: price,
                    maxShares: ownedShares
                ) { shares in
                    Task {
                        await portfolio.sellBackend(
                            symbol: symbol,
                            shares: shares,
                            price: price
                        )
                    }
                }
                .presentationDetents([.fraction(0.65)])
            } else {
                Text("Loading price…").padding()
            }
        }



    }
}
