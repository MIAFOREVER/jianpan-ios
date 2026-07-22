import Foundation

struct Candle: Identifiable, Codable, Hashable, Sendable {
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double

    var id: Date { date }
    var isRising: Bool { close >= open }
}

struct QuoteSnapshot: Identifiable, Codable, Sendable {
    let asset: AssetDefinition
    let price: Double
    let previousClose: Double
    let currency: String
    let exchangeName: String
    let marketTimeZone: String
    let candles: [Candle]
    let fetchedAt: Date

    var id: String { asset.id }
    var change: Double { price - previousClose }
    var changePercent: Double { previousClose == 0 ? 0 : change / previousClose * 100 }
    var isRising: Bool { change >= 0 }

    var sparkline: [Double] {
        candles.map(\.close)
    }
}

enum Timeframe: String, CaseIterable, Identifiable {
    case fiveMinutes
    case day
    case week
    case month
    case threeMonths
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fiveMinutes: "5分"
        case .day: "1日"
        case .week: "1周"
        case .month: "1月"
        case .threeMonths: "3月"
        case .year: "1年"
        }
    }

    var interval: String {
        switch self {
        case .fiveMinutes: "5m"
        case .day: "15m"
        case .week: "30m"
        case .month, .threeMonths: "1d"
        case .year: "1wk"
        }
    }

    var range: String {
        switch self {
        case .fiveMinutes, .day: "1d"
        case .week: "5d"
        case .month: "1mo"
        case .threeMonths: "3mo"
        case .year: "1y"
        }
    }
}
