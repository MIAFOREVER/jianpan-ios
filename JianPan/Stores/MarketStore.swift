import Foundation

@MainActor
final class MarketStore: ObservableObject {
    @Published private(set) var watchlist: [AssetDefinition]
    @Published private(set) var quotes: [String: QuoteSnapshot] = [:]
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?

    let service: YahooMarketService

    private let defaults: UserDefaults
    private let watchlistKey = "jianpan.watchlist.v1"
    private let quoteCacheKey = "jianpan.quotes.v1"

    init(service: YahooMarketService = YahooMarketService(), defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults

        if let data = defaults.data(forKey: watchlistKey),
           let decoded = try? JSONDecoder().decode([AssetDefinition].self, from: data),
           !decoded.isEmpty {
            watchlist = decoded
        } else {
            watchlist = AssetCatalog.defaults
        }

        if let data = defaults.data(forKey: quoteCacheKey),
           let decoded = try? JSONDecoder().decode([String: QuoteSnapshot].self, from: data) {
            quotes = decoded
            lastUpdated = decoded.values.map(\.fetchedAt).max()
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        var successful = 0
        var failures: [Error] = []

        for start in stride(from: 0, to: watchlist.count, by: 3) {
            let end = min(start + 3, watchlist.count)
            let assets = Array(watchlist[start..<end])

            await withTaskGroup(of: Result<QuoteSnapshot, Error>.self) { group in
                for asset in assets {
                    group.addTask { [service] in
                        do { return .success(try await service.fetch(asset: asset)) }
                        catch { return .failure(error) }
                    }
                }

                for await result in group {
                    switch result {
                    case let .success(snapshot):
                        quotes[snapshot.asset.id] = snapshot
                        successful += 1
                    case let .failure(error):
                        failures.append(error)
                    }
                }
            }
        }

        if successful > 0 {
            lastUpdated = .now
            persistQuoteCache()
        }
        if !failures.isEmpty {
            errorMessage = successful == 0
                ? (failures.first?.localizedDescription ?? "行情暂时不可用")
                : "部分行情暂时未更新，已保留上次数据"
        }
        isRefreshing = false
    }

    func add(_ asset: AssetDefinition) {
        guard !watchlist.contains(asset) else { return }
        watchlist.append(asset)
        persistWatchlist()
        Task { await refreshAsset(asset) }
    }

    func remove(_ asset: AssetDefinition) {
        watchlist.removeAll { $0.id == asset.id }
        quotes[asset.id] = nil
        persistWatchlist()
        persistQuoteCache()
    }

    func contains(_ asset: AssetDefinition) -> Bool {
        watchlist.contains { $0.id == asset.id }
    }

    func fetchHistory(for asset: AssetDefinition, timeframe: Timeframe) async throws -> QuoteSnapshot {
        try await service.fetch(asset: asset, timeframe: timeframe)
    }

    private func refreshAsset(_ asset: AssetDefinition) async {
        do {
            quotes[asset.id] = try await service.fetch(asset: asset)
            lastUpdated = .now
            persistQuoteCache()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistWatchlist() {
        guard let data = try? JSONEncoder().encode(watchlist) else { return }
        defaults.set(data, forKey: watchlistKey)
    }

    private func persistQuoteCache() {
        guard let data = try? JSONEncoder().encode(quotes) else { return }
        defaults.set(data, forKey: quoteCacheKey)
    }
}

