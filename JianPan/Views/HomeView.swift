import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: MarketStore
    @State private var filter: MarketFilter = .all
    @State private var showsAddSheet = false
    @State private var showsSettings = false

    private var filteredAssets: [AssetDefinition] {
        store.watchlist.filter { filter.includes($0.market) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    masthead
                    marketPulse
                    filterBar
                    errorBanner
                    watchlist
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 36)
            }
            .background(JPTheme.background.ignoresSafeArea())
            .refreshable { await store.refresh() }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AssetDefinition.self) { asset in
                DetailView(asset: asset)
            }
        }
        .tint(JPTheme.primaryText)
        .sheet(isPresented: $showsAddSheet) { AddSymbolView() }
        .sheet(isPresented: $showsSettings) { SettingsView() }
        .task {
            if store.quotes.isEmpty { await store.refresh() }
        }
    }

    private var masthead: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text("简盘")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(JPTheme.primaryText)
                Text("今天的市场，一目了然。")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(JPTheme.secondaryText)
            }

            Spacer()

            HStack(spacing: 8) {
                circleButton(icon: "plus") { showsAddSheet = true }
                circleButton(icon: "slider.horizontal.3") { showsSettings = true }
            }
        }
        .padding(.top, 18)
    }

    private func circleButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(JPTheme.primaryText)
                .frame(width: 40, height: 40)
                .background(JPTheme.surface, in: Circle())
                .overlay { Circle().stroke(JPTheme.line, lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    private var marketPulse: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                pulseCard(title: "沪深 300", symbol: "000300.SS", market: "CN")
                pulseCard(title: "恒生指数", symbol: "^HSI", market: "HK")
                pulseCard(title: "标普 500", symbol: "^GSPC", market: "US")
                pulseCard(title: "Bitcoin", symbol: "BTC-USD", market: "COIN")
            }
        }
        .contentMargins(.horizontal, 0, for: .scrollContent)
    }

    private func pulseCard(title: String, symbol: String, market: String) -> some View {
        let quote = store.quotes[symbol]
        let color = quote?.isRising == false ? JPTheme.negative : JPTheme.positive

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(market)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(JPTheme.secondaryText)
                Spacer()
                Circle().fill(quote == nil ? JPTheme.secondaryText : color).frame(width: 6, height: 6)
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(JPTheme.primaryText)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline) {
                Text(quote?.price.priceText ?? "—")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(JPTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: 10)
                Text(quote?.changePercent.signedPercentText ?? "—")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(quote == nil ? JPTheme.secondaryText : color)
            }
        }
        .padding(14)
        .frame(width: 160)
        .jpCard(cornerRadius: 18)
    }

    private var filterBar: some View {
        VStack(spacing: 13) {
            HStack {
                Text("我的自选")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(JPTheme.primaryText)
                Spacer()
                if store.isRefreshing {
                    ProgressView().controlSize(.small).tint(JPTheme.primaryText)
                } else if let date = store.lastUpdated {
                    Text(date, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(JPTheme.secondaryText)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MarketFilter.allCases) { item in
                        Button {
                            withAnimation(.easeOut(duration: 0.18)) { filter = item }
                        } label: {
                            Text(item.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(filter == item ? JPTheme.background : JPTheme.secondaryText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(filter == item ? JPTheme.primaryText : JPTheme.surface, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let message = store.errorMessage {
            HStack(spacing: 10) {
                Image(systemName: "wifi.exclamationmark")
                Text(message).frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .font(.caption)
            .foregroundStyle(JPTheme.secondaryText)
            .padding(12)
            .background(JPTheme.raisedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private var watchlist: some View {
        if filteredAssets.isEmpty {
            Button { showsAddSheet = true } label: {
                ContentUnavailableView("这里还没有行情", systemImage: "plus.circle", description: Text("添加一只股票或加密币"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }
            .buttonStyle(.plain)
            .jpCard()
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredAssets.enumerated()), id: \.element.id) { index, asset in
                    NavigationLink(value: asset) {
                        MarketRow(asset: asset, quote: store.quotes[asset.id])
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) { store.remove(asset) } label: {
                            Label("移出自选", systemImage: "trash")
                        }
                    }
                    if index < filteredAssets.count - 1 {
                        Divider().overlay(JPTheme.line).padding(.leading, 72)
                    }
                }
            }
            .jpCard()
        }
    }
}
