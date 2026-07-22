import SwiftUI

struct MiniLineChart: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                guard values.count > 1,
                      let minimum = values.min(),
                      let maximum = values.max() else { return }

                let spread = max(maximum - minimum, 0.000_001)
                let step = size.width / CGFloat(values.count - 1)
                var path = Path()

                for (index, value) in values.enumerated() {
                    let x = CGFloat(index) * step
                    let normalized = (value - minimum) / spread
                    let y = size.height - CGFloat(normalized) * (size.height - 3) - 1.5
                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }

                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}

