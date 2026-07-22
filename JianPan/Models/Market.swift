import Foundation

enum Market: String, CaseIterable, Codable, Identifiable, Sendable {
    case aShare
    case hongKong
    case unitedStates
    case crypto

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aShare: "A 股"
        case .hongKong: "港股"
        case .unitedStates: "美股"
        case .crypto: "加密"
        }
    }

    var shortTitle: String {
        switch self {
        case .aShare: "CN"
        case .hongKong: "HK"
        case .unitedStates: "US"
        case .crypto: "COIN"
        }
    }

    var currencySymbol: String {
        switch self {
        case .aShare: "¥"
        case .hongKong: "HK$"
        case .unitedStates, .crypto: "$"
        }
    }
}

struct AssetDefinition: Identifiable, Hashable, Codable, Sendable {
    let symbol: String
    let name: String
    let market: Market

    var id: String { symbol }

    var displaySymbol: String {
        switch market {
        case .aShare, .hongKong:
            symbol.components(separatedBy: ".").first ?? symbol
        case .unitedStates:
            symbol
        case .crypto:
            symbol.replacingOccurrences(of: "-USD", with: "")
        }
    }
}

enum AssetCatalog {
    static let all: [AssetDefinition] = [
        .init(symbol: "000001.SS", name: "上证指数", market: .aShare),
        .init(symbol: "000300.SS", name: "沪深 300", market: .aShare),
        .init(symbol: "600519.SS", name: "贵州茅台", market: .aShare),
        .init(symbol: "300750.SZ", name: "宁德时代", market: .aShare),
        .init(symbol: "002594.SZ", name: "比亚迪", market: .aShare),
        .init(symbol: "601318.SS", name: "中国平安", market: .aShare),
        .init(symbol: "0700.HK", name: "腾讯控股", market: .hongKong),
        .init(symbol: "^HSI", name: "恒生指数", market: .hongKong),
        .init(symbol: "9988.HK", name: "阿里巴巴-W", market: .hongKong),
        .init(symbol: "1810.HK", name: "小米集团-W", market: .hongKong),
        .init(symbol: "3690.HK", name: "美团-W", market: .hongKong),
        .init(symbol: "AAPL", name: "Apple", market: .unitedStates),
        .init(symbol: "NVDA", name: "NVIDIA", market: .unitedStates),
        .init(symbol: "TSLA", name: "Tesla", market: .unitedStates),
        .init(symbol: "MSFT", name: "Microsoft", market: .unitedStates),
        .init(symbol: "^GSPC", name: "标普 500", market: .unitedStates),
        .init(symbol: "BTC-USD", name: "Bitcoin", market: .crypto),
        .init(symbol: "ETH-USD", name: "Ethereum", market: .crypto),
        .init(symbol: "SOL-USD", name: "Solana", market: .crypto),
        .init(symbol: "BNB-USD", name: "BNB", market: .crypto),
        .init(symbol: "DOGE-USD", name: "Dogecoin", market: .crypto)
    ]

    static let defaults: [AssetDefinition] = [
        .init(symbol: "000300.SS", name: "沪深 300", market: .aShare),
        .init(symbol: "600519.SS", name: "贵州茅台", market: .aShare),
        .init(symbol: "^HSI", name: "恒生指数", market: .hongKong),
        .init(symbol: "0700.HK", name: "腾讯控股", market: .hongKong),
        .init(symbol: "AAPL", name: "Apple", market: .unitedStates),
        .init(symbol: "NVDA", name: "NVIDIA", market: .unitedStates),
        .init(symbol: "BTC-USD", name: "Bitcoin", market: .crypto),
        .init(symbol: "ETH-USD", name: "Ethereum", market: .crypto)
    ]

    static func customAsset(code rawCode: String, market: Market) -> AssetDefinition? {
        var code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return nil }

        switch market {
        case .aShare:
            if !code.contains(".") {
                let suffix = ["5", "6", "9"].contains(String(code.prefix(1))) ? ".SS" : ".SZ"
                code += suffix
            }
        case .hongKong:
            if !code.contains(".") {
                if code.allSatisfy(\.isNumber), code.count < 4 {
                    code = String(repeating: "0", count: 4 - code.count) + code
                }
                code += ".HK"
            }
        case .unitedStates:
            break
        case .crypto:
            code = code.replacingOccurrences(of: "/", with: "-")
            if !code.contains("-") { code += "-USD" }
        }

        if let known = all.first(where: { $0.symbol == code }) { return known }
        return AssetDefinition(symbol: code, name: code.components(separatedBy: ".").first ?? code, market: market)
    }
}

enum MarketFilter: String, CaseIterable, Identifiable {
    case all
    case aShare
    case hongKong
    case unitedStates
    case crypto

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .aShare: "A 股"
        case .hongKong: "港股"
        case .unitedStates: "美股"
        case .crypto: "加密"
        }
    }

    func includes(_ market: Market) -> Bool {
        switch self {
        case .all: true
        case .aShare: market == .aShare
        case .hongKong: market == .hongKong
        case .unitedStates: market == .unitedStates
        case .crypto: market == .crypto
        }
    }
}
