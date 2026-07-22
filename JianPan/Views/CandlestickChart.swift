import Charts
import SwiftUI

struct CandlestickChart: View {
    let candles: [Candle]

    private var yDomain: ClosedRange<Double> {
        let minimum = candles.map(\.low).min() ?? 0
        let maximum = candles.map(\.high).max() ?? 1
        let padding = max((maximum - minimum) * 0.12, maximum * 0.002)
        return (minimum - padding)...(maximum + padding)
    }

    private var isIntraday: Bool {
        guard let first = candles.first?.date, let last = candles.last?.date else { return false }
        return last.timeIntervalSince(first) < 60 * 60 * 48
    }

    var body: some View {
        Chart(candles) { candle in
            RuleMark(
                x: .value("时间", candle.date),
                yStart: .value("最低", candle.low),
                yEnd: .value("最高", candle.high)
            )
            .foregroundStyle(candle.isRising ? JPTheme.positive : JPTheme.negative)
            .lineStyle(StrokeStyle(lineWidth: 1))

            RectangleMark(
                x: .value("时间", candle.date),
                yStart: .value("开盘", candle.open),
                yEnd: .value("收盘", candle.close),
                width: .fixed(candles.count > 90 ? 2 : candles.count > 40 ? 4 : 7)
            )
            .foregroundStyle(candle.isRising ? JPTheme.positive : JPTheme.negative)
        }
        .chartYScale(domain: yDomain)
        .chartPlotStyle { plotArea in
            plotArea.background(JPTheme.background.opacity(0.34))
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(JPTheme.line)
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(axisLabel(for: date))
                    }
                }
                    .foregroundStyle(JPTheme.secondaryText)
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine().foregroundStyle(JPTheme.line)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(number.priceText)
                    }
                }
                .foregroundStyle(JPTheme.secondaryText)
                .font(.caption2)
            }
        }
        .accessibilityLabel("\(candles.count) 根 K 线")
    }

    private func axisLabel(for date: Date) -> String {
        if isIntraday {
            return date.formatted(.dateTime.hour().minute())
        }
        return date.formatted(.dateTime.month(.defaultDigits).day())
    }
}
