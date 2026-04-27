import SwiftUI
import AislandCore

struct RecentModelUsageView: View {
    var model: AppModel

    @Environment(\.islandTheme) private var theme

    private var rows: [UsageAnalyticsHourlyModelBucket] {
        model.usageAnalyticsHourlyModelUsage
    }

    private var days: [RecentUsageDay] {
        RecentUsageDay.completeRecentDays(from: rows, dayCount: 7)
    }

    private var totalTokens: Int {
        rows.reduce(0) { $0 + $1.totalTokens }
    }

    private var totalCostUSD: Double {
        rows.reduce(0) { $0 + $1.costUSD }
    }

    private var latestRow: UsageAnalyticsHourlyModelBucket? {
        rows
            .filter { $0.totalTokens > 0 || $0.costUSD > 0 }
            .sorted {
                ($0.lastSeenAt ?? $0.hourStartAt) > ($1.lastSeenAt ?? $1.hourStartAt)
            }
            .first
    }

    private var topModel: RecentUsageModelSummary? {
        Dictionary(grouping: rows, by: \.modelIdentifier)
            .map { modelIdentifier, rows in
                RecentUsageModelSummary(
                    modelIdentifier: modelIdentifier,
                    modelDisplayName: rows.first?.modelDisplayName ?? modelIdentifier,
                    provider: rows.first?.provider,
                    totalTokens: rows.reduce(0) { $0 + $1.totalTokens },
                    costUSD: rows.reduce(0) { $0 + $1.costUSD }
                )
            }
            .filter { $0.totalTokens > 0 || $0.costUSD > 0 }
            .sorted { lhs, rhs in
                if lhs.totalTokens == rhs.totalTokens { return lhs.modelDisplayName < rhs.modelDisplayName }
                return lhs.totalTokens > rhs.totalTokens
            }
            .first
    }

    var body: some View {
        GeometryReader { proxy in
            let summaryWidth = max(150, proxy.size.width * 0.25)

            HStack(alignment: .center, spacing: 12) {
                heatmapPanel
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)

                summaryPanel
                    .frame(width: summaryWidth)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(height: 500)
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
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.lang.t("usage.surface.title"))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.text)
                        Text(model.lang.t("usage.surface.subtitle"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                    }

                    Spacer(minLength: 8)

                    Text(totalTokens.recentUsageTokenString)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(theme.primary)
                        .monospacedDigit()
                }

                if totalTokens == 0 && totalCostUSD == 0 {
                    emptyState
                } else {
                    HourlyContributionHeatmap(
                        days: days,
                        theme: theme,
                        legend: model.lang.t("usage.surface.legend"),
                        lessLabel: model.lang.t("usage.surface.less"),
                        moreLabel: model.lang.t("usage.surface.more")
                    )
                }
            }
        }
    }

    private var summaryPanel: some View {
        usageSurfaceCard {
            VStack(alignment: .leading, spacing: 9) {
                summaryCard(
                    title: model.lang.t("usage.surface.latest"),
                    value: latestRow.map { $0.totalTokens.recentUsageTokenString } ?? "0",
                    detail: latestRow.map { Self.relativeTime($0.lastSeenAt ?? $0.hourStartAt) }
                        ?? model.lang.t("usage.surface.noRecent")
                )

                summaryCard(
                    title: model.lang.t("usage.surface.model"),
                    value: topModel?.modelDisplayName ?? "—",
                    detail: topModel?.provider?.displayName ?? model.lang.t("usage.surface.noModel")
                )

                summaryCard(
                    title: model.lang.t("usage.surface.cost"),
                    value: totalCostUSD.recentUsageCurrencyString,
                    detail: model.lang.t("usage.surface.recentDays")
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)
            Label(model.lang.t("usage.surface.empty.title"), systemImage: "chart.bar.xaxis")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.text)
            Text(model.lang.t("usage.surface.empty.subtitle"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)
            if model.usageAnalyticsIsRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(theme.textSecondary.opacity(0.82))
                .lineLimit(1)
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            Text(detail)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(theme.surfaceContainer.opacity(0.48), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private static func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

private struct HourlyContributionHeatmap: View {
    var days: [RecentUsageDay]
    var theme: IslandThemePalette
    var legend: String
    var lessLabel: String
    var moreLabel: String

    private var maxTokens: Int {
        max(days.flatMap(\.cells).map(\.totalTokens).max() ?? 1, 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let labelWidth: CGFloat = 42
            let cellSpacing: CGFloat = 3
            let availableCellWidth = proxy.size.width - labelWidth - CGFloat(23) * cellSpacing
            let cellSize = min(16, max(8, availableCellWidth / 24))

            VStack(alignment: .leading, spacing: 12) {
                hourHeader(labelWidth: labelWidth, cellSize: cellSize, spacing: cellSpacing)

                VStack(alignment: .leading, spacing: cellSpacing) {
                    ForEach(days) { day in
                        HStack(spacing: cellSpacing) {
                            Text(day.shortLabel)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(theme.textSecondary.opacity(day.isToday ? 0.95 : 0.62))
                                .lineLimit(1)
                                .frame(width: labelWidth, alignment: .trailing)

                            ForEach(day.cells) { cell in
                                RoundedRectangle(cornerRadius: cellSize * 0.24, style: .continuous)
                                    .fill(fill(for: cell))
                                    .frame(width: cellSize, height: cellSize)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: cellSize * 0.24, style: .continuous)
                                            .strokeBorder(stroke(for: cell), lineWidth: 0.55)
                                    )
                                    .help(cell.helpText)
                            }
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.surfaceContainer.opacity(0.34))
                )

                HStack(spacing: 7) {
                    Text(legend)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                    Spacer(minLength: 0)
                    Text(lessLabel)
                    ForEach([0.16, 0.30, 0.48, 0.66, 0.84], id: \.self) { opacity in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(theme.primary.opacity(opacity))
                            .frame(width: 12, height: 12)
                    }
                    Text(moreLabel)
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

                RecentUsageDayTotals(days: days, theme: theme)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func hourHeader(labelWidth: CGFloat, cellSize: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            Color.clear.frame(width: labelWidth, height: 1)
            ForEach(0..<24, id: \.self) { hour in
                Text(hour % 6 == 0 ? String(format: "%02d", hour) : "")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textSecondary.opacity(0.58))
                    .frame(width: cellSize)
            }
        }
    }

    private func fill(for cell: RecentUsageHourCell) -> Color {
        guard !cell.isFuture else {
            return theme.surfaceContainer.opacity(0.16)
        }
        guard cell.totalTokens > 0 || cell.costUSD > 0 else {
            return theme.surfaceContainer.opacity(0.44)
        }

        let intensity = min(1, Double(cell.totalTokens) / Double(maxTokens))
        return theme.primary.opacity(0.18 + 0.70 * intensity)
    }

    private func stroke(for cell: RecentUsageHourCell) -> Color {
        if cell.isCurrentHour {
            return theme.text.opacity(0.48)
        }
        return theme.text.opacity(cell.totalTokens > 0 ? 0.10 : 0.04)
    }
}

private struct RecentUsageDayTotals: View {
    var days: [RecentUsageDay]
    var theme: IslandThemePalette

    private var maxTokens: Int {
        max(days.map(\.totalTokens).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(days) { day in
                HStack(spacing: 8) {
                    Text(day.longLabel)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 46, alignment: .leading)
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(theme.primary.opacity(day.totalTokens > 0 ? 0.28 : 0.08))
                            .frame(width: max(day.totalTokens > 0 ? 3 : 0, proxy.size.width * CGFloat(day.totalTokens) / CGFloat(maxTokens)))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 8)
                    Text(day.totalTokens.recentUsageTokenString)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct RecentUsageDay: Identifiable {
    var dayStartAt: Date
    var cells: [RecentUsageHourCell]

    var id: TimeInterval { dayStartAt.timeIntervalSince1970 }
    var totalTokens: Int { cells.reduce(0) { $0 + $1.totalTokens } }

    var isToday: Bool {
        Calendar.current.isDateInToday(dayStartAt)
    }

    var shortLabel: String {
        Self.shortFormatter.string(from: dayStartAt)
    }

    var longLabel: String {
        Self.longFormatter.string(from: dayStartAt)
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

    private static let longFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter
    }()
}

private struct RecentUsageHourCell: Identifiable {
    var hourStartAt: Date
    var rows: [UsageAnalyticsHourlyModelBucket]
    var isCurrentHour: Bool

    var id: TimeInterval { hourStartAt.timeIntervalSince1970 }
    var totalTokens: Int { rows.reduce(0) { $0 + $1.totalTokens } }
    var costUSD: Double { rows.reduce(0) { $0 + $1.costUSD } }
    var isFuture: Bool { hourStartAt > .now }

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

private struct RecentUsageModelSummary {
    var modelIdentifier: String
    var modelDisplayName: String
    var provider: UsageLogProvider?
    var totalTokens: Int
    var costUSD: Double
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
