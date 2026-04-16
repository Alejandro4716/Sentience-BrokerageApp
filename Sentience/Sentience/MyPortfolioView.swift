//
//  MyPortfolioView.swift
//  Sentience
//

import SwiftUI

// MARK: - Theme colours (module-wide)
extension Color {
    static let vault    = Color(red: 0.714, green: 0.910, blue: 0.325)
    static let vaultBg  = Color(red: 0.09,  green: 0.09,  blue: 0.09)
    static let vaultCard = Color(red: 0.13, green: 0.13,  blue: 0.13)
}

// MARK: - Line chart

struct VaultLineChart: View {
    let prices: [Double]
    let color:  Color

    var body: some View {
        GeometryReader { geo in
            let pts = normalize(prices: prices, in: geo.size)
            if pts.count > 1 {
                ZStack {
                    areaPath(pts, h: geo.size.height)
                        .fill(LinearGradient(
                            colors: [color.opacity(0.35), color.opacity(0.0)],
                            startPoint: .top, endPoint: .bottom
                        ))
                    linePath(pts)
                        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    if let peakIdx = prices.indices.max(by: { prices[$0] < prices[$1] }),
                       peakIdx < pts.count {
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                            .position(pts[peakIdx])
                    }
                }
            }
        }
    }

    private func normalize(prices: [Double], in size: CGSize) -> [CGPoint] {
        guard prices.count > 1 else { return [] }
        let mn  = prices.min()!
        let mx  = prices.max()!
        let rng = mx - mn == 0 ? 1.0 : mx - mn
        let pad: CGFloat = 0.08
        return prices.enumerated().map { i, p in
            CGPoint(
                x: size.width * CGFloat(i) / CGFloat(prices.count - 1),
                y: size.height * (1 - pad) * (1 - CGFloat((p - mn) / rng)) + size.height * pad * 0.5
            )
        }
    }

    private func curve(_ pts: [CGPoint]) -> Path {
        var path = Path()
        guard pts.count > 1 else { return path }
        path.move(to: pts[0])
        for i in 1..<pts.count {
            let p0  = pts[max(0, i - 2)]
            let p1  = pts[i - 1]
            let p2  = pts[i]
            let p3  = pts[min(pts.count - 1, i + 1)]
            let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }
        return path
    }

    private func linePath(_ pts: [CGPoint]) -> Path { curve(pts) }

    private func areaPath(_ pts: [CGPoint], h: CGFloat) -> Path {
        guard let last = pts.last else { return Path() }
        var path = curve(pts)
        path.addLine(to: CGPoint(x: last.x, y: h))
        path.addLine(to: CGPoint(x: pts[0].x, y: h))
        path.closeSubpath()
        return path
    }
}

// MARK: - Portfolio dashboard

struct MyPortfolioView: View {
    @EnvironmentObject var portfolio: PortfolioStore
    @EnvironmentObject var flow:      AppFlowStore

    // Selected stock for chart
    @State private var selectedSymbol = ""

    // Always falls back to the first holding so the featured section never goes blank
    var displaySymbol: String {
        !selectedSymbol.isEmpty ? selectedSymbol : (portfolio.holdings.first?.symbol ?? "")
    }
    // Chart
    @State private var chartPrices:  [Double] = []
    @State private var chartLoading  = false
    @State private var selectedPeriod = "1M"
    // Sheets
    @State private var showBuy     = false
    @State private var showSell    = false
    @State private var showAccount = false
    @State private var showDeposit  = false
    @State private var showWithdraw = false

    let periods = ["1D", "1W", "1M", "3M", "1Y", "ALL"]

    // MARK: Body

    var body: some View {
        ZStack {
            Color.vaultBg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        featuredSection
                        Divider().background(Color(white: 0.10))
                        statsSection
                        Divider().background(Color(white: 0.10))
                        holdingsSection
                        actionButtons
                    }
                }
                .refreshable {
                    await portfolio.refreshBackend()
                    await portfolio.refreshLiveQuotes()
                    await loadChart()
                }
            }
        }
        .sheet(isPresented: $showBuy) {
            if !selectedSymbol.isEmpty, let price = portfolio.liveQuotes[selectedSymbol]?.current {
                BuySheet(symbol: selectedSymbol, currentPrice: price) { shares in
                    Task { await portfolio.buyBackend(symbol: selectedSymbol, shares: shares, price: price) }
                }
                .presentationDetents([.fraction(0.65)])
            } else {
                Text("Price loading…").padding()
            }
        }
        .sheet(isPresented: $showSell) {
            let owned = portfolio.holdings.first(where: { $0.symbol == selectedSymbol })?.shares ?? 0
            if !selectedSymbol.isEmpty, let price = portfolio.liveQuotes[selectedSymbol]?.current, owned > 0 {
                SellSheet(symbol: selectedSymbol, currentPrice: price, maxShares: owned) { shares in
                    Task { await portfolio.sellBackend(symbol: selectedSymbol, shares: shares, price: price) }
                }
                .presentationDetents([.fraction(0.65)])
            } else {
                Text(owned == 0 ? "You don't own \(selectedSymbol)." : "Price loading…").padding()
            }
        }
        .sheet(isPresented: $showAccount) {
            NavigationView { AccountView() }
                .environmentObject(portfolio)
                .environmentObject(flow)
        }
        .sheet(isPresented: $showDeposit) {
            DepositSheet { amt in Task { await portfolio.depositBackend(amt) } }
                .presentationDetents([.fraction(0.75)])
        }
        .sheet(isPresented: $showWithdraw) {
            WithdrawSheet(availableBalance: portfolio.cashBalance) { amt in
                Task { await portfolio.withdrawBackend(amt) }
            }
            .presentationDetents([.fraction(0.75)])
        }
        .task {
            if selectedSymbol.isEmpty, let first = portfolio.holdings.first {
                selectedSymbol = first.symbol
            }
            await portfolio.refreshLiveQuotes()
            await loadChart()
        }
        .onChange(of: portfolio.holdings) { _, new in
            if selectedSymbol.isEmpty, let first = new.first { selectedSymbol = first.symbol }
            Task {
                await portfolio.refreshLiveQuotes()
                await loadChart()
            }
        }
        .onChange(of: selectedPeriod) { _, _ in Task { await loadChart() } }
    }

    // MARK: - Header

    var header: some View {
        HStack(alignment: .center) {
            Text("SENTIENCE")
                .font(.system(size: 20, weight: .black))
                .foregroundColor(.vault)

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(isMarketOpen ? Color.vault : Color.red)
                    .frame(width: 7, height: 7)
                Text(isMarketOpen ? "NYSE OPEN" : "NYSE CLOSED")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isMarketOpen ? .vault : .red)
            }

            Spacer()

            Button { showAccount = true } label: {
                Circle()
                    .fill(Color.vault)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Text(portfolio.avatarInitials)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Featured stock

    var featuredSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !displaySymbol.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(companyName(displaySymbol))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(white: 0.42))

                    HStack(alignment: .center, spacing: 12) {
                        if let q = portfolio.liveQuotes[displaySymbol] {
                            Text(q.current, format: .currency(code: "USD"))
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)
                            changeBadge(q: q)
                        } else {
                            Text("—")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(Color(white: 0.25))
                            ProgressView().tint(.vault).scaleEffect(0.7)
                        }
                        Spacer()
                    }

                    if let q = portfolio.liveQuotes[displaySymbol],
                       let h = portfolio.holdings.first(where: { $0.symbol == displaySymbol }) {
                        Text(String(format: "H $%.2f  ·  L $%.2f  ·  AVG $%.2f", q.high, q.low, h.avgPrice))
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.38))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
            }

            // Chart area
            ZStack {
                Color(red: 0.10, green: 0.10, blue: 0.10)
                if chartLoading {
                    ProgressView().tint(.vault)
                } else if chartPrices.count > 1 {
                    VaultLineChart(prices: chartPrices, color: .vault)
                        .padding(.vertical, 10)
                } else {
                    Text("No chart data")
                        .font(.caption)
                        .foregroundColor(Color(white: 0.28))
                }
            }
            .frame(height: 150)
            .padding(.top, 14)

            // Period picker
            HStack(spacing: 2) {
                ForEach(periods, id: \.self) { p in
                    Button { selectedPeriod = p } label: {
                        Text(p)
                            .font(.system(size: 12, weight: selectedPeriod == p ? .semibold : .regular))
                            .foregroundColor(selectedPeriod == p ? .black : Color(white: 0.42))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedPeriod == p ? Color.vault : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color(red: 0.11, green: 0.11, blue: 0.11))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Stats cards

    var statsSection: some View {
        HStack(spacing: 10) {
            statCard(
                label: "PORTFOLIO",
                value: formatK(portfolio.totalEquityValue + portfolio.cashBalance),
                valueColor: .white
            )
            statCard(
                label: "DAY P&L",
                value: String(format: "%@$%.0f", portfolio.dayPnL >= 0 ? "+" : "−", abs(portfolio.dayPnL)),
                valueColor: portfolio.dayPnL >= 0 ? .vault : .red
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    func statCard(label: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(white: 0.38))
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.vaultCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Holdings

    var holdingsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("HOLDINGS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(white: 0.38))
                Spacer()
                Text("\(portfolio.holdings.count) POSITIONS")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.28))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            if portfolio.holdings.isEmpty {
                Text("No holdings yet — use Trade to buy your first stock.")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.3))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 30)
            } else {
                ForEach(portfolio.holdings) { h in
                    Button { selectHolding(h.symbol) } label: {
                        holdingRow(h)
                    }
                    .buttonStyle(.plain)
                    Divider()
                        .background(Color(white: 0.10))
                        .padding(.horizontal, 20)
                }
            }
        }
    }

    func holdingRow(_ h: Holding) -> some View {
        let q       = portfolio.liveQuotes[h.symbol]
        let price   = q?.current ?? h.avgPrice
        let value   = price * Double(h.shares)
        let pct     = q?.percentChange ?? 0
        let isUp    = pct >= 0
        let weight  = portfolio.totalEquityValue > 0 ? value / portfolio.totalEquityValue : 0

        return VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(h.symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(String(format: "$%.0f", value))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text(String(format: "%@%.2f%%", isUp ? "+" : "", pct))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isUp ? .vault : .red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((isUp ? Color.vault : Color.red).opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }

            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(white: 0.15))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(isUp ? Color.vault : Color.red.opacity(0.8))
                            .frame(width: max(geo.size.width * CGFloat(weight), 0), height: 3)
                    }
                }
                .frame(width: 64, height: 3)

                Text(companyName(h.symbol))
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.32))
                Spacer()
            }
            .padding(.top, 6)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .background(selectedSymbol == h.symbol ? Color(white: 0.105) : Color.clear)
        .animation(.easeInOut(duration: 0.15), value: selectedSymbol)
    }

    // MARK: - Action buttons

    var actionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                actionButton("BUY") { showBuy = true }
                actionButton("SELL") { showSell = true }
            }
            HStack(spacing: 12) {
                actionButton("DEPOSIT") { showDeposit = true }
                actionButton("WITHDRAW") { showWithdraw = true }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    func actionButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(white: 0.28), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    var isMarketOpen: Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let comps   = cal.dateComponents([.weekday, .hour, .minute], from: Date())
        let weekday = comps.weekday ?? 0
        guard weekday >= 2 && weekday <= 6 else { return false }
        let mins = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        return mins >= 570 && mins < 960
    }

    func formatK(_ v: Double) -> String {
        if abs(v) >= 1_000_000 { return String(format: "$%.1fM", v / 1_000_000) }
        if abs(v) >= 1_000     { return String(format: "$%.1fK", v / 1_000) }
        return String(format: "$%.2f", v)
    }

    func companyName(_ sym: String) -> String {
        let map: [String: String] = [
            "AAPL": "Apple Inc.",         "TSLA": "Tesla Inc.",
            "NVDA": "Nvidia Corp.",       "MSFT": "Microsoft Corp.",
            "AMZN": "Amazon.com Inc.",    "GOOGL": "Alphabet Inc.",
            "GOOG": "Alphabet Inc.",      "META": "Meta Platforms",
            "NFLX": "Netflix Inc.",       "AMD":  "AMD Inc.",
            "JPM":  "JPMorgan Chase",     "V":    "Visa Inc.",
            "MA":   "Mastercard",         "UNH":  "UnitedHealth Group",
            "BRK.B":"Berkshire Hathaway", "DIS":  "Walt Disney Co.",
            "PYPL": "PayPal Holdings",    "INTC": "Intel Corp.",
            "CRM":  "Salesforce Inc.",    "BABA": "Alibaba Group"
        ]
        return map[sym] ?? sym
    }

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

    func selectHolding(_ sym: String) {
        guard sym != selectedSymbol else { return }
        selectedSymbol = sym
        Task { await loadChart() }
    }

    // MARK: - Async loaders

    func loadChart() async {
        guard !selectedSymbol.isEmpty else { return }
        chartLoading = true
        defer { chartLoading = false }
        let now = Int(Date().timeIntervalSince1970)
        let (resolution, from): (String, Int)
        switch selectedPeriod {
        case "1D": resolution = "60"; from = now - 86400
        case "1W": resolution = "D";  from = now - 7 * 86400
        case "3M": resolution = "D";  from = now - 90 * 86400
        case "1Y": resolution = "W";  from = now - 365 * 86400
        case "ALL": resolution = "M"; from = now - 1825 * 86400
        default:   resolution = "D";  from = now - 30 * 86400 // 1M
        }
        chartPrices = (try? await APIClient.shared.fetchCandles(
            symbol: selectedSymbol, resolution: resolution, from: from, to: now
        )) ?? []
    }

}

#Preview {
    MyPortfolioView()
        .environmentObject(PortfolioStore())
        .environmentObject(AppFlowStore())
}
