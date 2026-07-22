import Foundation

struct SymbolSearchService: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String) async -> [AssetDefinition] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 2 else { return [] }

        async let tencentResult = searchTencent(query: normalized)
        async let yahooResult = searchYahoo(query: normalized)

        let sources = await [
            (try? tencentResult) ?? [],
            (try? yahooResult) ?? []
        ]

        var seen = Set<String>()
        return sources.flatMap { $0 }.filter { seen.insert($0.id).inserted }
    }

    private func searchTencent(query: String) async throws -> [AssetDefinition] {
        var components = URLComponents(string: "https://smartbox.gtimg.cn/s3/")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "t", value: "all")
        ]
        guard let url = components?.url else { throw MarketDataError.invalidURL }

        let data = try await load(url: url)
        guard let body = String(data: data, encoding: .utf8),
              let firstQuote = body.firstIndex(of: "\""),
              let lastQuote = body.lastIndex(of: "\""),
              firstQuote < lastQuote else { return [] }

        let encodedString = String(body[firstQuote...lastQuote])
        guard let encodedData = encodedString.data(using: .utf8),
              let hint = try? JSONDecoder().decode(String.self, from: encodedData),
              hint != "N" else { return [] }

        return hint.split(separator: "^").compactMap { item in
            let fields = item.split(separator: "~", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 5, fields[4] == "GP" else { return nil }

            let exchange = fields[0].lowercased()
            let rawCode = fields[1]
            let name = fields[2]

            switch exchange {
            case "sh":
                return AssetDefinition(symbol: rawCode.uppercased() + ".SS", name: name, market: .aShare)
            case "sz":
                return AssetDefinition(symbol: rawCode.uppercased() + ".SZ", name: name, market: .aShare)
            case "hk":
                let yahooCode = rawCode.count == 5 && rawCode.hasPrefix("0") ? String(rawCode.dropFirst()) : rawCode
                return AssetDefinition(symbol: yahooCode.uppercased() + ".HK", name: name, market: .hongKong)
            case "us":
                let yahooCode = rawCode.components(separatedBy: ".").first?.uppercased() ?? rawCode.uppercased()
                return AssetDefinition(symbol: yahooCode, name: name, market: .unitedStates)
            default:
                return nil
            }
        }
    }

    private func searchYahoo(query: String) async throws -> [AssetDefinition] {
        var lastError: Error = MarketDataError.emptyResult

        for host in ["query1.finance.yahoo.com", "query2.finance.yahoo.com"] {
            do {
                var components = URLComponents()
                components.scheme = "https"
                components.host = host
                components.path = "/v1/finance/search"
                components.queryItems = [
                    URLQueryItem(name: "q", value: query),
                    URLQueryItem(name: "quotesCount", value: "12"),
                    URLQueryItem(name: "newsCount", value: "0"),
                    URLQueryItem(name: "enableFuzzyQuery", value: "true")
                ]
                guard let url = components.url else { throw MarketDataError.invalidURL }

                let data = try await load(url: url)
                let response = try JSONDecoder().decode(YahooSearchResponse.self, from: data)
                return response.quotes.compactMap(mapYahooQuote)
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    private func mapYahooQuote(_ quote: YahooSearchQuote) -> AssetDefinition? {
        let symbol = quote.symbol.uppercased()
        let name = quote.longname ?? quote.shortname ?? symbol

        if symbol.hasSuffix(".SS") || symbol.hasSuffix(".SZ") {
            return AssetDefinition(symbol: symbol, name: name, market: .aShare)
        }
        if symbol.hasSuffix(".HK") {
            return AssetDefinition(symbol: symbol, name: name, market: .hongKong)
        }
        if symbol.hasSuffix("-USD") || quote.quoteType == "CRYPTOCURRENCY" {
            return AssetDefinition(symbol: symbol, name: name, market: .crypto)
        }

        let supportedUSExchanges: Set<String> = ["NMS", "NYQ", "NGM", "NCM", "ASE", "PCX", "BTS"]
        guard quote.quoteType == "EQUITY" || quote.quoteType == "INDEX",
              quote.exchange.map(supportedUSExchanges.contains) ?? symbol.hasPrefix("^") else { return nil }
        return AssetDefinition(symbol: symbol, name: name, market: .unitedStates)
    }

    private func load(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 JianPan/1.0",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json,text/plain,*/*", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw MarketDataError.malformedData }
        guard (200..<300).contains(http.statusCode) else { throw MarketDataError.badResponse(http.statusCode) }
        return data
    }
}

private struct YahooSearchResponse: Decodable {
    let quotes: [YahooSearchQuote]
}

private struct YahooSearchQuote: Decodable {
    let exchange: String?
    let shortname: String?
    let quoteType: String?
    let symbol: String
    let longname: String?
}
