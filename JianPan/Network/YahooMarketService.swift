import Foundation

enum MarketDataError: LocalizedError {
    case invalidURL
    case badResponse(Int)
    case emptyResult
    case malformedData
    case remote(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "行情地址无效"
        case let .badResponse(code): "行情服务返回错误（\(code)）"
        case .emptyResult: "暂无这只资产的行情"
        case .malformedData: "行情数据格式异常"
        case let .remote(message): message
        }
    }
}

struct YahooMarketService: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(asset: AssetDefinition, timeframe: Timeframe = .day) async throws -> QuoteSnapshot {
        var lastError: Error = MarketDataError.emptyResult

        for host in ["query1.finance.yahoo.com", "query2.finance.yahoo.com"] {
            do {
                return try await fetch(asset: asset, timeframe: timeframe, host: host)
            } catch {
                lastError = error
                if !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(180))
                }
            }
        }

        throw lastError
    }

    private func fetch(asset: AssetDefinition, timeframe: Timeframe, host: String) async throws -> QuoteSnapshot {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/v8/finance/chart/\(asset.symbol)"
        components.queryItems = [
            URLQueryItem(name: "interval", value: timeframe.interval),
            URLQueryItem(name: "range", value: timeframe.range),
            URLQueryItem(name: "includePrePost", value: "false"),
            URLQueryItem(name: "events", value: "div,splits")
        ]

        guard let url = components.url else { throw MarketDataError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadRevalidatingCacheData
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 JianPan/1.0",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw MarketDataError.malformedData }
        guard (200..<300).contains(http.statusCode) else { throw MarketDataError.badResponse(http.statusCode) }

        let envelope = try JSONDecoder().decode(YahooChartEnvelope.self, from: data)
        if let error = envelope.chart.error { throw MarketDataError.remote(error.description) }
        guard let result = envelope.chart.result?.first else { throw MarketDataError.emptyResult }
        guard let timestamps = result.timestamp,
              let quote = result.indicators.quote.first,
              let closes = quote.close else {
            throw MarketDataError.emptyResult
        }

        let count = [timestamps.count, closes.count, quote.open?.count ?? 0, quote.high?.count ?? 0, quote.low?.count ?? 0].min() ?? 0
        var candles: [Candle] = []
        candles.reserveCapacity(count)

        for index in 0..<count {
            guard let open = quote.open?[index],
                  let high = quote.high?[index],
                  let low = quote.low?[index],
                  let close = quote.close?[index] else { continue }
            let volume = quote.volume.flatMap { $0[safe: index] ?? nil } ?? 0
            candles.append(
                Candle(
                    date: Date(timeIntervalSince1970: timestamps[index]),
                    open: open,
                    high: high,
                    low: low,
                    close: close,
                    volume: volume
                )
            )
        }

        guard let lastClose = candles.last?.close ?? closes.compactMap({ $0 }).last else {
            throw MarketDataError.emptyResult
        }

        let price = result.meta.regularMarketPrice ?? lastClose
        let previousClose = result.meta.chartPreviousClose ?? result.meta.previousClose ?? candles.first?.open ?? price

        return QuoteSnapshot(
            asset: asset,
            price: price,
            previousClose: previousClose,
            currency: result.meta.currency ?? asset.market.currencySymbol,
            exchangeName: result.meta.exchangeName ?? asset.market.title,
            marketTimeZone: result.meta.exchangeTimezoneName ?? TimeZone.current.identifier,
            candles: candles,
            fetchedAt: .now
        )
    }
}

private struct YahooChartEnvelope: Decodable {
    let chart: YahooChartContainer
}

private struct YahooChartContainer: Decodable {
    let result: [YahooChartResult]?
    let error: YahooChartError?
}

private struct YahooChartError: Decodable {
    let code: String
    let description: String
}

private struct YahooChartResult: Decodable {
    let meta: YahooMeta
    let timestamp: [TimeInterval]?
    let indicators: YahooIndicators
}

private struct YahooMeta: Decodable {
    let currency: String?
    let exchangeName: String?
    let regularMarketPrice: Double?
    let previousClose: Double?
    let chartPreviousClose: Double?
    let exchangeTimezoneName: String?
}

private struct YahooIndicators: Decodable {
    let quote: [YahooQuoteValues]
}

private struct YahooQuoteValues: Decodable {
    let open: [Double?]?
    let high: [Double?]?
    let low: [Double?]?
    let close: [Double?]?
    let volume: [Double?]?
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
