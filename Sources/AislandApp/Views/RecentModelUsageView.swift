import AppKit
import SwiftUI
import AislandCore

struct RecentModelUsageView: View {
    var model: AppModel

    @Environment(\.islandTheme) private var theme

    private var rows: [UsageAnalyticsHourlyModelBucket] {
        model.usageAnalyticsHourlyModelUsage
    }

    private var today: RecentUsageDay {
        RecentUsageDay.today(from: rows)
    }

    private var totalTokens: Int {
        today.totalTokens
    }

    private var totalCostUSD: Double {
        today.costUSD
    }

    var body: some View {
        heatmapPanel
            .frame(maxWidth: .infinity)
            .frame(height: 320)
        .onAppear {
            if rows.isEmpty {
                model.refreshUsageAnalytics()
            }
        }
    }

    private var heatmapPanel: some View {
        usageSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.lang.t("usage.surface.title"))
                        .font(IslandTheme.titleFont(size: 15))
                        .foregroundStyle(theme.text)

                    Spacer(minLength: 8)

                    Text(totalTokens.recentUsageTokenString)
                        .font(IslandTheme.bodyFont(size: 18, weight: .black))
                        .foregroundStyle(theme.primary)
                        .monospacedDigit()
                }

                if rows.isEmpty && totalTokens == 0 && totalCostUSD == 0 {
                    emptyState
                } else {
                    HourlyContributionHeatmap(
                        day: today,
                        theme: theme,
                        legend: model.lang.t("usage.surface.legend"),
                        lessLabel: model.lang.t("usage.surface.less"),
                        moreLabel: model.lang.t("usage.surface.more")
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)
            Label(model.lang.t("usage.surface.empty.title"), systemImage: "chart.bar.xaxis")
                .font(IslandTheme.labelFont(size: 12))
                .foregroundStyle(theme.text)
            if model.usageAnalyticsIsRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func usageSurfaceCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(theme.card.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(theme.outline.opacity(0.12))
            )
    }

}

private struct HourlyContributionHeatmap: View {
    var day: RecentUsageDay
    var theme: IslandThemePalette
    var legend: String
    var lessLabel: String
    var moreLabel: String

    private var maxTokens: Int {
        max(day.cells.map(\.totalTokens).max() ?? 1, 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let columnCount = proxy.size.width >= 430 ? 8 : 6
            let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: columnCount)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(day.detailLabel)
                        .font(IslandTheme.labelFont(size: 10.5))
                        .foregroundStyle(theme.textSecondary.opacity(0.9))
                    Spacer(minLength: 0)
                    Text("00-23")
                        .font(IslandTheme.labelFont(size: 10))
                        .foregroundStyle(theme.textTertiary)
                        .monospacedDigit()
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 7) {
                    ForEach(day.cells) { cell in
                        hourTile(for: cell)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.surfaceContainer.opacity(0.34))
                )

                HStack(spacing: 7) {
                    Text(legend)
                        .font(IslandTheme.labelFont(size: 10))
                        .foregroundStyle(theme.textSecondary)
                    Spacer(minLength: 0)
                    Text(lessLabel)
                    ForEach([0.08, 0.24, 0.44, 0.68, 1.0], id: \.self) { intensity in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(RecentUsageHeatmapColor.color(theme: theme, intensity: intensity))
                            .frame(width: 12, height: 12)
                    }
                    Text(moreLabel)
                }
                .font(IslandTheme.labelFont(size: 10))
                .foregroundStyle(theme.textSecondary)

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func hourTile(for cell: RecentUsageHourCell) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 4) {
                Text(String(format: "%02d", cell.hourOfDay))
                    .font(IslandTheme.labelFont(size: 9.5))
                    .foregroundStyle(cell.isFuture ? theme.textTertiary.opacity(0.62) : theme.text.opacity(0.92))
                    .monospacedDigit()
                Spacer(minLength: 0)
                if cell.isCurrentHour {
                    Circle()
                        .fill(theme.primary)
                        .frame(width: 5, height: 5)
                }
            }

            Spacer(minLength: 0)

            Text(cell.totalTokens > 0 ? cell.totalTokens.recentUsageTokenString : "·")
                .font(IslandTheme.bodyFont(size: 10.5, weight: .black))
                .foregroundStyle(cell.totalTokens > 0 ? theme.text : theme.textTertiary.opacity(0.58))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(minHeight: 44, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(fill(for: cell))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(stroke(for: cell), lineWidth: cell.isCurrentHour ? 1.1 : 0.65)
        )
        .help(cell.helpText)
    }

    private func fill(for cell: RecentUsageHourCell) -> Color {
        guard !cell.isFuture else {
            return theme.surfaceContainer.opacity(0.16)
        }
        guard cell.totalTokens > 0 || cell.costUSD > 0 else {
            return theme.surfaceContainer.opacity(0.44)
        }

        let intensity = sqrt(min(1, Double(cell.totalTokens) / Double(maxTokens)))
        return RecentUsageHeatmapColor.color(theme: theme, intensity: intensity)
    }

    private func stroke(for cell: RecentUsageHourCell) -> Color {
        if cell.isCurrentHour {
            return theme.primaryContainer.opacity(0.78)
        }
        return theme.text.opacity(cell.totalTokens > 0 ? 0.10 : 0.04)
    }
}

private struct RecentUsageDay: Identifiable {
    var dayStartAt: Date
    var cells: [RecentUsageHourCell]

    var id: TimeInterval { dayStartAt.timeIntervalSince1970 }
    var totalTokens: Int { cells.reduce(0) { $0 + $1.totalTokens } }
    var costUSD: Double { cells.reduce(0) { $0 + $1.costUSD } }

    var isToday: Bool {
        Calendar.current.isDateInToday(dayStartAt)
    }

    var shortLabel: String {
        Self.shortFormatter.string(from: dayStartAt)
    }

    var detailLabel: String {
        Self.detailFormatter.string(from: dayStartAt)
    }

    static func today(from rows: [UsageAnalyticsHourlyModelBucket]) -> RecentUsageDay {
        completeRecentDays(from: rows, dayCount: 1).first ?? RecentUsageDay(
            dayStartAt: Calendar.current.startOfDay(for: .now),
            cells: []
        )
    }

    static func completeRecentDays(from rows: [UsageAnalyticsHourlyModelBucket], dayCount: Int) -> [RecentUsageDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let currentHour = calendar.dateInterval(of: .hour, for: .now)?.start ?? .now
        let grouped = Dictionary(grouping: rows) { row in
            calendar.dateInterval(of: .hour, for: row.hourStartAt)?.start ?? row.hourStartAt
        }

        return (0..<max(1, dayCount)).compactMap { dayOffset in
            guard let day = calendar.date(byAdding: .day, value: dayOffset - max(1, dayCount) + 1, to: today) else {
                return nil
            }

            let cells = (0..<24).compactMap { hourOffset -> RecentUsageHourCell? in
                guard let hour = calendar.date(byAdding: .hour, value: hourOffset, to: day) else {
                    return nil
                }
                let hourRows = (grouped[hour] ?? []).sorted { lhs, rhs in
                    if lhs.totalTokens == rhs.totalTokens { return lhs.modelDisplayName < rhs.modelDisplayName }
                    return lhs.totalTokens > rhs.totalTokens
                }
                return RecentUsageHourCell(hourStartAt: hour, rows: hourRows, isCurrentHour: hour == currentHour)
            }

            return RecentUsageDay(dayStartAt: day, cells: cells)
        }
    }

    private static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

    private static let detailFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()
}

private enum RecentUsageHeatmapColor {
    static func color(theme: IslandThemePalette, intensity: Double) -> Color {
        let clamped = min(max(intensity, 0), 1)
        guard let base = NSColor(theme.primary).usingColorSpace(.deviceRGB) else {
            return theme.primary.opacity(0.22 + 0.72 * clamped)
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        base.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return Color(
            hue: Double(hue),
            saturation: min(1, Double(max(0.18, saturation)) * (0.24 + 0.76 * clamped)),
            brightness: min(1, Double(max(0.42, brightness)) * (0.42 + 0.58 * clamped)),
            opacity: 0.38 + 0.58 * clamped
        )
    }
}

private struct RecentUsageHourCell: Identifiable {
    var hourStartAt: Date
    var rows: [UsageAnalyticsHourlyModelBucket]
    var isCurrentHour: Bool

    var id: TimeInterval { hourStartAt.timeIntervalSince1970 }
    var totalTokens: Int { rows.reduce(0) { $0 + $1.totalTokens } }
    var costUSD: Double { rows.reduce(0) { $0 + $1.costUSD } }
    var isFuture: Bool { hourStartAt > .now }
    var hourOfDay: Int { Calendar.current.component(.hour, from: hourStartAt) }

    var helpText: String {
        let modelText = rows.prefix(4)
            .map { "\($0.modelDisplayName): \($0.totalTokens.recentUsageTokenString), \($0.costUSD.recentUsageCurrencyString)" }
            .joined(separator: "\n")
        return "\(Self.longFormatter.string(from: hourStartAt))\n\(totalTokens.recentUsageTokenString) · \(costUSD.recentUsageCurrencyString)\n\(modelText)"
    }

    private static let longFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

private extension Int {
    var recentUsageTokenString: String {
        let value = Double(self)
        if self >= 1_000_000_000 { return String(format: "%.1fB", value / 1_000_000_000) }
        if self >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if self >= 1_000 { return String(format: "%.1fK", value / 1_000) }
        return formatted()
    }
}

private extension Double {
    var recentUsageCurrencyString: String {
        if self >= 100 { return String(format: "$%.0f", self) }
        if self >= 10 { return String(format: "$%.1f", self) }
        return String(format: "$%.2f", self)
    }
}
