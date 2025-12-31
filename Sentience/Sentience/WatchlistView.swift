//
//  WatchlistView.swift
//  Sentience
//
//  Created by Alejandro Morel on 11/9/25.
//


// WatchlistView.swift
import SwiftUI

struct WatchlistView: View {
    @State private var showAdd = false
    @EnvironmentObject var watchlist: WatchlistStore

    var body: some View {
        List {
            //list stocks in watchlist
            //each ticker listed can be tapped on to view
            ForEach(watchlist.symbols, id: \.self) { sym in
                NavigationLink(value: sym) {
                    WatchlistRow(symbol: sym)
                }
            }
            .onDelete(perform: watchlist.remove)
        }
        .navigationTitle("Watchlist")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true  //shows add sheet when pressed
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) { //add sheet pops up
            AddTickerSheet { newSym in
                watchlist.add(newSym)
            }
            .presentationDetents([.fraction(0.35)])
        }
        .navigationDestination(for: String.self) { sym in
            StockDetailView(symbol: sym)    //navigates to chosen stock
        }
    }
}


//shows each stock and info when clicked on 
private struct WatchlistRow: View {
    let symbol: String
    @StateObject private var vm = QuoteVM()

    var body: some View {
        HStack {
            Text(symbol).bold()
            Spacer()
            if let q = vm.quote {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(q.current, format: .currency(code: "USD"))
                        .font(.subheadline).bold()
                    Text(String(format: "%.2f%%", q.percentChange))
                        .font(.caption)
                        .foregroundStyle(q.percentChange >= 0 ? .green : .red)
                }
            } else if vm.isLoading {
                ProgressView()
            } else if let err = vm.errorText {
                Text(err).foregroundStyle(.secondary).font(.caption)
            } else {
                Text("--").foregroundStyle(.secondary)
            }
        }
        .onAppear { if vm.quote == nil { vm.load(symbol: symbol) } }
    }
}


