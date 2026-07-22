import SwiftUI

enum JPTheme {
    static let background = Color(red: 0.035, green: 0.039, blue: 0.047)
    static let surface = Color(red: 0.078, green: 0.086, blue: 0.102)
    static let raisedSurface = Color(red: 0.108, green: 0.118, blue: 0.137)
    static let line = Color.white.opacity(0.09)
    static let primaryText = Color(red: 0.96, green: 0.96, blue: 0.93)
    static let secondaryText = Color.white.opacity(0.52)
    static let positive = Color(red: 0.21, green: 0.91, blue: 0.56)
    static let negative = Color(red: 1.0, green: 0.36, blue: 0.40)
}

extension View {
    func jpCard(cornerRadius: CGFloat = 22) -> some View {
        self
            .background(JPTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(JPTheme.line, lineWidth: 1)
            }
    }
}

extension Double {
    var priceText: String {
        let magnitude = abs(self)
        let digits = magnitude >= 1_000 ? 2 : magnitude >= 1 ? 2 : 4
        return formatted(.number.precision(.fractionLength(0...digits)).grouping(.automatic))
    }

    var signedPriceText: String {
        let prefix = self >= 0 ? "+" : ""
        return prefix + priceText
    }

    var signedPercentText: String {
        let prefix = self >= 0 ? "+" : ""
        return prefix + formatted(.number.precision(.fractionLength(2))) + "%"
    }
}

