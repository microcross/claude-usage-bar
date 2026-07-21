import SwiftUI
import UsageWidgetCore
import UsageWidgetUI

// Frosted panel shown from the status item. The NSPopover supplies the
// translucent material background; everything here layers on top of it, so
// tints use Color.primary opacities to adapt to light/dark vibrancy.
struct DetailView: View {
    @ObservedObject var model: UsageModel
    @State private var manualKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Claude Usage")
                .font(.system(size: 13, weight: .semibold))

            HStack(spacing: 10) {
                metricColumn(title: "Session (5h)", window: model.session)
                metricColumn(title: "Weekly", window: model.weekly)
            }

            if model.needsLogin {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste your Claude session key to connect.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        SecureField("session key", text: $manualKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        Button("Save") {
                            model.saveManualKey(manualKey)
                            manualKey = ""
                        }
                        .font(.caption)
                        .disabled(manualKey.isEmpty)
                    }
                    Link("Where do I find my session key?",
                         destination: URL(string: "https://github.com/microcross/claude-usage-bar#setup")!)
                        .font(.caption2)
                }
            }

            Divider()

            HStack {
                if let error = model.errorMessage, !model.needsLogin {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                } else if let updated = model.lastUpdated {
                    Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    model.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    @ViewBuilder
    private func metricColumn(title: String, window: UsageWindow?) -> some View {
        VStack(spacing: 6) {
            FrostedDonut(percent: window?.utilizationPct ?? 0)
                .frame(width: 60, height: 60)
                .padding(.top, 2)
            Text(title)
                .font(.system(size: 11, weight: .medium))
            HStack(spacing: 3) {
                Image(systemName: "clock")
                    .font(.system(size: 9))
                Text(window?.resetsAt.map(Self.resetLabel) ?? "—")
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.08), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 0.5)
        )
    }

    // "42m" / "3h 12m" inside a day; "Thu 7 PM" beyond that.
    static func resetLabel(for date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return "now" }
        if interval < 24 * 3600 {
            let minutes = Int(interval / 60)
            let h = minutes / 60
            let m = minutes % 60
            return h > 0 ? "\(h)h \(m)m" : "\(m)m"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h a"
        return formatter.string(from: date)
    }
}

// Gradient-stroked donut for the panel (the shared DonutView stays flat for
// the tests and any simpler uses).
struct FrostedDonut: View {
    let percent: Double

    private var clamped: Double { min(max(percent, 0), 100) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.14), lineWidth: 5)
            Circle()
                .trim(from: 0, to: clamped / 100)
                .stroke(gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(clamped.rounded()))%")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
        }
    }

    private var gradient: LinearGradient {
        let colors: [Color]
        switch clamped {
        case ..<50: colors = [Color(red: 0.49, green: 0.89, blue: 0.63), Color(red: 0.18, green: 0.66, blue: 0.42)]
        case ..<80: colors = [Color(red: 1.0, green: 0.85, blue: 0.44), Color(red: 0.89, green: 0.60, blue: 0.18)]
        default:    colors = [Color(red: 1.0, green: 0.45, blue: 0.40), Color(red: 0.82, green: 0.18, blue: 0.16)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
