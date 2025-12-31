//
//  RootView.swift
//  Sentience
//
//  Created by Alejandro Morel on 12/17/25.
//  chooses which screen is being shown 

import SwiftUI

struct RootView: View {
    @EnvironmentObject var flow: AppFlowStore
    @EnvironmentObject var portfolio: PortfolioStore
    @EnvironmentObject var watchlist: WatchlistStore

    var body: some View {
        if flow.showMain {
            MainScreen()
                .environmentObject(portfolio)
                .environmentObject(flow)
                .environmentObject(watchlist)
        } else {
            ContentView()
                .environmentObject(flow)
        }
    }
}


#Preview {
    RootView()
        .environmentObject(AppFlowStore())
        .environmentObject(PortfolioStore())
        .environmentObject(WatchlistStore())
}
