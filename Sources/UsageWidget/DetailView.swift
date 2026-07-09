import SwiftUI
import UsageWidgetCore
import UsageWidgetUI

struct DetailView: View {
    @ObservedObject var model: UsageModel
    @State private var manualKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Claude Usage")
                .font(.headline)

            HStack(spacing: 20) {
                donutColumn(title: "Session (5h)", window: model.session)
                donutColumn(title: "Weekly", window: model.weekly)
            }
            .frame(maxWidth: .infinity)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                barRow(title: "5-hour session", window: model.session)
                barRow(title: "7-day (all models)", window: model.weekly)
                if let opus = model.weeklyOpus {
                    barRow(title: "7-day (Opus)", window: opus)
                }
            }

            Divider()

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

            HStack {
                if let error = model.errorMessage, !model.needsLogin {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(3)
                } else if let updated = model.lastUpdated {
                    Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh") { model.refresh() }
                    .font(.caption)
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .font(.caption)
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    @ViewBuilder
    private func donutColumn(title: String, window: UsageWindow?) -> some View {
        VStack(spacing: 6) {
            let pct = window?.utilizationPct ?? 0
            DonutView(percent: pct, lineWidth: 6, color: DonutView.color(for: pct))
                .frame(width: 64, height: 64)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let reset = window?.resetsAt {
                Text("resets \(reset.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func barRow(title: String, window: UsageWindow?) -> some View {
        let pct = window?.utilizationPct ?? 0
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.caption)
                Spacer()
                Text("\(Int(pct.rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(DonutView.color(for: pct))
                        .frame(width: geo.size.width * min(max(pct, 0), 100) / 100)
                }
            }
            .frame(height: 6)
        }
    }
}
