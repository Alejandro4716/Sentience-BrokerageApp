import SwiftUI

struct MainScreen: View {
    @EnvironmentObject var watchlist: WatchlistStore
    @EnvironmentObject var portfolio: PortfolioStore
    @EnvironmentObject var flow: AppFlowStore

    @State private var selectedTab = 0
    @State private var showAuth = false

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)
        let green = UIColor(red: 0.714, green: 0.910, blue: 0.325, alpha: 1)
        let gray  = UIColor(white: 0.38, alpha: 1)
        let sm9   = UIFont.systemFont(ofSize: 9, weight: .semibold)
        let sm9r  = UIFont.systemFont(ofSize: 9, weight: .regular)
        for layout in [appearance.stackedLayoutAppearance,
                       appearance.inlineLayoutAppearance,
                       appearance.compactInlineLayoutAppearance] {
            layout.selected.iconColor = green
            layout.selected.titleTextAttributes  = [.foregroundColor: green, .font: sm9]
            layout.normal.iconColor = gray
            layout.normal.titleTextAttributes    = [.foregroundColor: gray,  .font: sm9r]
        }
        UITabBar.appearance().standardAppearance    = appearance
        UITabBar.appearance().scrollEdgeAppearance  = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {

            MyPortfolioView()
                .tabItem { Label("PORTFOLIO", systemImage: "chart.bar.fill") }
                .tag(0)

            MarketsView()
                .tabItem { Label("MARKETS", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(1)

            TradeView()
                .tabItem { Label("TRADE", systemImage: "plus.circle") }
                .tag(2)

            AccountView()
                .tabItem { Label("ACCOUNT", systemImage: "person.circle") }
                .tag(3)
        }
        .task {
            await portfolio.refreshBackend()
            showAuth = !portfolio.isLoggedIn
        }
        .sheet(isPresented: $showAuth) {
            AuthGateView().environmentObject(portfolio)
        }
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

// MARK: - Markets Tab

struct MarketsView: View {
    @EnvironmentObject var watchlist: WatchlistStore
    @EnvironmentObject var portfolio: PortfolioStore

    @State private var showAdd   = false
    @State private var allQuotes: [String: Quote] = [:]
    @State private var failedSymbols: Set<String> = []
    let indexSymbols = ["SPY", "QQQ", "DIA", "IVV"]

    var body: some View {
        NavigationView {
            ZStack {
                Color.vaultBg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("MARKETS")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(.vault)
                        Spacer()
                        Button { showAdd = true } label: {
                            Image(systemName: "plus")
                                .foregroundColor(.vault)
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 16)

                    ScrollView {
                        VStack(spacing: 16) { // pull-to-refresh below
                            sectionBlock(title: "INDICES") {
                                ForEach(indexSymbols, id: \.self) { sym in
                                    marketRow(sym: sym, quote: allQuotes[sym])
                                    if sym != indexSymbols.last {
                                        Divider().background(Color(white: 0.12)).padding(.horizontal, 20)
                                    }
                                }
                            }

                            sectionBlock(title: "WATCHLIST") {
                                if watchlist.symbols.isEmpty {
                                    Text("No symbols — tap + to add")
                                        .font(.caption)
                                        .foregroundColor(Color(white: 0.35))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                } else {
                                    ForEach(watchlist.symbols, id: \.self) { sym in
                                        NavigationLink(destination: StockDetailView(symbol: sym).environmentObject(portfolio)) {
                                            marketRow(sym: sym, quote: allQuotes[sym])
                                        }
                                        .buttonStyle(.plain)
                                        if sym != watchlist.symbols.last {
                                            Divider().background(Color(white: 0.12)).padding(.horizontal, 20)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
                .refreshable { await loadQuotes() }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showAdd) {
            AddTickerSheet { sym in
                watchlist.add(sym)
                Task { await loadQuotes() }
            }
            .presentationDetents([.fraction(0.35)])
        }
        .task { await loadQuotes() }
        .onChange(of: watchlist.symbols) { _, _ in Task { await loadQuotes() } }
    }

    @ViewBuilder
    func sectionBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(white: 0.38))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            VStack(spacing: 0) { content() }
                .background(Color.vaultCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    func marketRow(sym: String, quote: Quote?) -> some View {
        HStack {
            Text(sym)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 52, alignment: .leading)
            Spacer()
            if let q = quote {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(q.current, format: .currency(code: "USD"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    let up = q.percentChange >= 0
                    Text(String(format: "%@%.2f%%", up ? "+" : "", q.percentChange))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(up ? .vault : .red)
                }
            } else if failedSymbols.contains(sym) {
                Text("—")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(white: 0.28))
            } else {
                ProgressView().tint(.vault).scaleEffect(0.7)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
    }

    func loadQuotes() async {
        let symbols = Array(Set(indexSymbols + watchlist.symbols))
        var results: [String: Quote] = [:]
        var failed:  Set<String>     = []
        await withTaskGroup(of: (String, Quote?).self) { group in
            for sym in symbols {
                group.addTask { (sym, try? await APIClient.shared.fetchQuote(symbol: sym)) }
            }
            for await (sym, q) in group {
                if let q { results[sym] = q } else { failed.insert(sym) }
            }
        }
        allQuotes      = results
        failedSymbols  = failed
    }
}

// MARK: - Trade Tab

struct TradeView: View {
    @EnvironmentObject var portfolio: PortfolioStore

    @State private var searchText   = ""
    @State private var committedSym: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.vaultBg.ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("TRADE")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.vault)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(white: 0.4))
                        TextField("Enter ticker (e.g. AAPL)", text: $searchText)
                            .foregroundColor(.white)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            .onSubmit { commit() }
                        if !searchText.isEmpty {
                            Button { commit() } label: {
                                Text("GO")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.vault)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .background(Color.vaultCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20)

                    Spacer()
                    Text("Search a ticker to view price and trade")
                        .font(.caption)
                        .foregroundColor(Color(white: 0.28))
                    Spacer()
                }
            }
            .navigationDestination(item: $committedSym) { sym in
                StockDetailView(symbol: sym).environmentObject(portfolio)
            }
            .navigationBarHidden(true)
        }
    }

    func commit() {
        let sym = searchText.trimmingCharacters(in: .whitespaces).uppercased()
        guard !sym.isEmpty else { return }
        committedSym = sym
    }
}

#Preview {
    MainScreen()
        .environmentObject(AppFlowStore())
        .environmentObject(PortfolioStore())
        .environmentObject(WatchlistStore())
}
