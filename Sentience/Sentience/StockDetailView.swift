import SwiftUI

struct StockDetailView: View {
    let symbol: String
    @EnvironmentObject var portfolio: PortfolioStore
    @State private var showBuy  = false
    @State private var showSell = false
    @StateObject private var vm = QuoteVM()

    // Chart
    @State private var chartPrices:  [Double] = []
    @State private var chartLoading  = false
    @State private var selectedPeriod = "1M"
    let periods = ["1D", "1W", "1M", "3M", "1Y"]

    var ownedShares: Int {
        portfolio.holdings.first(where: { $0.symbol == symbol })?.shares ?? 0
    }

    var body: some View {
        ZStack {
            Color.vaultBg.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    priceHeader
                    chartSection
                    if ownedShares > 0 { positionCard }
                    Spacer(minLength: 32)
                    actionButtons
                }
            }
            .refreshable {
                vm.load(symbol: symbol)
                await loadChart()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(symbol)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.vault)
            }
        }
        .onAppear { vm.load(symbol: symbol) }
        .task { await loadChart() }
        .onChange(of: selectedPeriod) { _, _ in Task { await loadChart() } }
        .sheet(isPresented: $showBuy) {
            if let price = vm.quote?.current {
                BuySheet(symbol: symbol, currentPrice: price) { shares in
                    Task { await portfolio.buyBackend(symbol: symbol, shares: shares, price: price) }
                }
                .presentationDetents([.fraction(0.65)])
            } else {
                ZStack { Color.vaultBg.ignoresSafeArea(); ProgressView().tint(.vault) }
                    .presentationDetents([.fraction(0.35)])
            }
        }
        .sheet(isPresented: $showSell) {
            if let price = vm.quote?.current {
                SellSheet(symbol: symbol, currentPrice: price, maxShares: ownedShares) { shares in
                    Task { await portfolio.sellBackend(symbol: symbol, shares: shares, price: price) }
                }
                .presentationDetents([.fraction(0.65)])
            } else {
                ZStack { Color.vaultBg.ignoresSafeArea(); ProgressView().tint(.vault) }
                    .presentationDetents([.fraction(0.35)])
            }
        }
    }

    // MARK: - Price header

    var priceHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let q = vm.quote {
                HStack(alignment: .center, spacing: 12) {
                    Text(q.current, format: .currency(code: "USD"))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                    changeBadge(q: q)
                    Spacer()
                }
                Text(String(format: "H $%.2f  ·  L $%.2f  ·  PREV $%.2f", q.high, q.low, q.previousClose))
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.38))
            } else if let err = vm.errorText {
                Text(err)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            } else {
                HStack(spacing: 10) {
                    Text("—")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(Color(white: 0.25))
                    ProgressView().tint(.vault).scaleEffect(0.8)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Chart

    var chartSection: some View {
        VStack(spacing: 0) {
            // Chart area
            ZStack {
                Color(red: 0.10, green: 0.10, blue: 0.10)
                if chartLoading {
                    ProgressView().tint(.vault)
                } else if chartPrices.count > 1 {
                    let up = (chartPrices.last ?? 0) >= (chartPrices.first ?? 0)
                    VaultLineChart(prices: chartPrices, color: up ? .vault : .red)
                        .padding(.vertical, 10)
                } else {
                    Text("No chart data")
                        .font(.caption)
                        .foregroundColor(Color(white: 0.28))
                }
            }
            .frame(height: 160)

            // Period picker
            HStack(spacing: 2) {
                ForEach(periods, id: \.self) { p in
                    Button(p) { selectedPeriod = p }
                        .font(.system(size: 12, weight: selectedPeriod == p ? .semibold : .regular))
                        .foregroundColor(selectedPeriod == p ? .black : Color(white: 0.42))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedPeriod == p ? Color.vault : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
            .padding(4)
            .background(Color(red: 0.11, green: 0.11, blue: 0.11))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Position card

    var positionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR POSITION")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(white: 0.38))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                infoRow(label: "Shares Owned") {
                    Text("\(ownedShares)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                if let q = vm.quote {
                    let mktValue = q.current * Double(ownedShares)
                    let avgCost  = portfolio.holdings.first(where: { $0.symbol == symbol })?.avgPrice ?? 0
                    let pnl      = (q.current - avgCost) * Double(ownedShares)
                    let pnlUp    = pnl >= 0

                    Divider().background(Color(white: 0.12))
                    infoRow(label: "Market Value") {
                        Text(mktValue, format: .currency(code: "USD"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.vault)
                    }
                    Divider().background(Color(white: 0.12))
                    infoRow(label: "Unrealised P&L") {
                        Text(String(format: "%@$%.2f", pnlUp ? "+" : "-", abs(pnl)))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(pnlUp ? .vault : .red)
                    }
                }
            }
            .background(Color.vaultCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Action buttons

    var actionButtons: some View {
        VStack(spacing: 10) {
            Button { showBuy = true } label: {
                Text("BUY \(symbol)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.vault)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            if ownedShares > 0 {
                Button { showSell = true } label: {
                    Text("SELL \(symbol)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(white: 0.28), lineWidth: 1.5)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
    }

    // MARK: - Helpers

    @ViewBuilder
    func changeBadge(q: Quote) -> some View {
        let up = q.percentChange >= 0
        HStack(spacing: 3) {
            Image(systemName: up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 8))
            Text(String(format: "%.2f%%", abs(q.percentChange)))
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.black)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(up ? Color.vault : Color.red)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    @ViewBuilder
    func infoRow<V: View>(label: String, @ViewBuilder value: () -> V) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.55))
            Spacer()
            value()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Chart loader

    func loadChart() async {
        chartLoading = true
        defer { chartLoading = false }
        let now = Int(Date().timeIntervalSince1970)
        let (resolution, from): (String, Int)
        switch selectedPeriod {
        case "1D": resolution = "60"; from = now - 86_400
        case "1W": resolution = "D";  from = now - 7 * 86_400
        case "3M": resolution = "D";  from = now - 90 * 86_400
        case "1Y": resolution = "W";  from = now - 365 * 86_400
        default:   resolution = "D";  from = now - 30 * 86_400  // 1M
        }
        chartPrices = (try? await APIClient.shared.fetchCandles(
            symbol: symbol, resolution: resolution, from: from, to: now
        )) ?? []
    }
}
