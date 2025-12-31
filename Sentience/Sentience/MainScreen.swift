import SwiftUI

struct MainScreen: View {
    @EnvironmentObject var watchlist: WatchlistStore

    @EnvironmentObject var portfolio: PortfolioStore

    @State private var showAdd = false
    @State private var selectedTab = 0

    @State private var showAuth = false
    
    @EnvironmentObject var flow: AppFlowStore


    //main screen of app, contains tabs to navigate to other screens
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // TAB 1: Watchlist
            NavigationView {
                List {
                    ForEach(watchlist.symbols, id: \.self) { sym in
                        NavigationLink(destination: StockDetailView(symbol: sym)) {
                            //QuoteRow(symbol: sym)
                            Text(sym).font(.headline)
                        }
                    }
                    .onDelete(perform: watchlist.remove)
                }
                .navigationTitle("Watchlist")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("Add") { showAdd = true } }
                    ToolbarItem(placement: .topBarLeading) { EditButton() }
                }
                .sheet(isPresented: $showAdd) {
                    AddTickerSheet { newSym in watchlist.add(newSym) }
                        .presentationDetents([.fraction(0.35)])
                }
            }
            .tabItem {
                Label("Watchlist", systemImage: "list.bullet")
            }
            .tag(0)
            
            // TAB 2: My Portfolio
            NavigationView {
                MyPortfolioView()
            }
            .tabItem {
                Label("My Stocks", systemImage: "chart.pie")
            }
            .tag(1)
            
            // TAB 3: My Account
            NavigationView {
                AccountView()
            }
            .tabItem {
                Label("My Account", systemImage: "person.crop.circle")
            }
            .tag(2)
        }
        .task {
            await portfolio.refreshBackend()
            showAuth = !portfolio.isLoggedIn

        }
        //ensures log in or sign up first
        .sheet(isPresented: $showAuth) {
            AuthGateView().environmentObject(portfolio)
        }
        //ensures a bank acc is linked before using app
        .sheet(isPresented: .constant(portfolio.needsBankLink)) {
            LinkBankSheet()
                .environmentObject(portfolio)
                .interactiveDismissDisabled()
        }
        .onChange(of: portfolio.authToken) { _, _ in
            showAuth = !portfolio.isLoggedIn

        }
    }
}



#Preview {
    MainScreen()
        .environmentObject(AppFlowStore())
        .environmentObject(PortfolioStore())
        .environmentObject(WatchlistStore())
}
