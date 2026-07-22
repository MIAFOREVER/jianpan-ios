import SwiftUI

struct DetailView: View {
    let asset: AssetDefinition
    @EnvironmentObject private var store: MarketStore
    @State private var timeframe: Timeframe = .day
    @State private var snapshot: QuoteSnapshot?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var tint: Color {
        guard let snapshot else { return JPTheme.secondaryText }
        return snapshot.isRising ? JPTheme.positive : JPTheme.negative
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                priceHeader
                timeframePicker
                chartCard
                sessionCard
                sourceNote
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 36)
        }
        .background(JPTheme.background.ignoresSafeArea())
        .navigationTitle(asset.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task(id: timeframe) { await load() }
    }

    private var priceHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(asset.displaySymbol)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(JPTheme.secondaryText)
                Text(asset.market.title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(JPTheme.secondaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.07), in: Capsule())
            }

            if let snapshot {
                Text(snapshot.price.priceText)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(JPTheme.primaryText)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .contentTransition(.numericText())

                HStack(spacing: 10) {
                    Text(snapshot.change.signedPriceText)
                    Text(snapshot.changePercent.signedPercentText)
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
            } else {
                Text("—")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(JPTheme.secondaryText)
            }
        }
        .padding(.top, 12)
    }

    private var timeframePicker: some View {
        HStack(spacing: 6) {
            ForEach(Timeframe.allCases) { item in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { timeframe = item }
                } label: {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(timeframe == item ? JPTheme.background : JPTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(timeframe == item ? JPTheme.primaryText : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(JPTheme.surface, in: Capsule())
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("价格走势")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(JPTheme.primaryText)
                Spacer()
                if isLoading { ProgressView().controlSize(.small).tint(JPTheme.primaryText) }
            }

            if let candles = snapshot?.candles, candles.count > 1 {
                CandlestickChart(candles: candles)
                    .frame(height: 290)
            } else if let errorMessage {
                ContentUnavailableView("暂时无法加载", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                    .frame(height: 260)
            } else {
                ProgressView()
                    .tint(JPTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
            }
        }
        .padding(16)
        .jpCard()
    }

    private var sessionCard: some View {
        let candles = snapshot?.candles ?? []
        let high = candles.map(\.high).max()
        let low = candles.map(\.low).min()
        let open = candles.first?.open
        let volume = candles.last?.volume

        return VStack(spacing: 0) {
            metricRow(label: "区间开盘", value: open?.priceText ?? "—", label2: "区间最高", value2: high?.priceText ?? "—")
            Divider().overlay(JPTheme.line).padding(.vertical, 14)
            metricRow(label: "区间最低", value: low?.priceText ?? "—", label2: "最新成交量", value2: volume.flatMap { $0 > 0 ? compactNumber($0) : nil } ?? "—")
        }
        .padding(18)
        .jpCard()
    }

    private func metricRow(label: String, value: String, label2: String, value2: String) -> some View {
        HStack {
            metric(label: label, value: value)
            Spacer()
            metric(label: label2, value: value2)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(JPTheme.secondaryText)
            Text(value).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(JPTheme.primaryText)
        }
    }

    private var sourceNote: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "clock.badge.exclamationmark")
            Text("行情可能延迟，仅供信息参考，不构成任何投资建议。")
        }
        .font(.caption)
        .foregroundStyle(JPTheme.secondaryText)
        .padding(.horizontal, 4)
    }

    private func load() async {
        if snapshot == nil { snapshot = store.quotes[asset.id] }
        isLoading = true
        errorMessage = nil
        do {
            snapshot = try await store.fetchHistory(for: asset, timeframe: timeframe)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func compactNumber(_ value: Double) -> String {
        value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
    }
}
