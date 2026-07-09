import SwiftUI

public struct DonutView: View {
    let percent: Double // 0...100
    var lineWidth: CGFloat = 5
    var showLabel: Bool = true
    var color: Color = .accentColor

    public init(percent: Double, lineWidth: CGFloat = 5, showLabel: Bool = true, color: Color = .accentColor) {
        self.percent = percent
        self.lineWidth = lineWidth
        self.showLabel = showLabel
        self.color = color
    }

    private var clamped: Double { min(max(percent, 0), 100) }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.35), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped / 100)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showLabel {
                Text("\(Int(clamped.rounded()))%")
                    .font(.caption2.monospacedDigit())
                    .fontWeight(.semibold)
            }
        }
    }
}

extension DonutView {
    public static func color(for percent: Double) -> Color {
        switch percent {
        case ..<50: return .green
        case ..<80: return .yellow
        default: return .red
        }
    }
}
