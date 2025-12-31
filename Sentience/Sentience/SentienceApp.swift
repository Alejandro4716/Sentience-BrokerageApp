//
//  SentienceApp.swift
//  Sentience
//
//  Created by Alejandro Morel on 12/17/25.
//

import SwiftUI

@main
struct SentienceApp: App {
    @StateObject private var portfolio = PortfolioStore()
    @StateObject private var flow = AppFlowStore()
    @StateObject private var watchlist = WatchlistStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(portfolio)
                .environmentObject(flow)
                .environmentObject(watchlist)
        }
    }
}
