import SwiftUI

struct MarketRow: View {
    let asset: AssetDefinition
    let quote: QuoteSnapshot?

    private var tint: Color {
        guard let quote else { return JPTheme.secondaryText }
        return quote.isRising ? JPTheme.positive : JPTheme.negative
    }

    var body: some View {
        HStack(spacing: 14) {
            assetMark

            VStack(alignment: .leading, spacing: 5) {
                Text(asset.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(JPTheme.primaryText)
                    .lineLimit(1)

                HStack(spacing: 7) {
                    Text(asset.displaySymbol)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(JPTheme.secondaryText)
                    Text(asset.market.shortTitle)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(JPTheme.secondaryText)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.07), in: Capsule())
                }
            }

            Spacer(minLength: 4)

            MiniLineChart(values: quote?.sparkline ?? [], color: tint)
                .frame(width: 68, height: 30)

            VStack(alignment: .trailing, spacing: 5) {
                if let quote {
                    Text(quote.price.priceText)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(JPTheme.primaryText)
                        .contentTransition(.numericText())
                    Text(quote.changePercent.signedPercentText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(tint)
                } else {
                    Text("—")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(JPTheme.secondaryText)
                    Text("等待更新")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(JPTheme.secondaryText)
                }
            }
            .frame(width: 82, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }

    private var assetMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
            Text(String(asset.displaySymbol.prefix(1)))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(JPTheme.primaryText)
        }
        .frame(width: 42, height: 42)
    }
}

