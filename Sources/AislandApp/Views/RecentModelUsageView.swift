import SwiftUI
import AislandCore

struct RecentModelUsageView: View {
    var model: AppModel

    @Environment(\.islandTheme) private var theme

    private var rows: [UsageAnalyticsHourlyModelBucket] {
        model.usageAnalyticsHourlyModelUsage
    }

    private var hours: [RecentUsageHour] {
        RecentUsageHour.completeLast24Hours(from: rows)
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
        .frame(height: 244)
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
                    HourlyUsageHeatmap(
                        hours: hours,
                        theme: theme,
                        legend: model.lang.t("usage.surface.legend")
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
                    detail: model.lang.t("usage.surface.last24h")
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

private struct HourlyUsageHeatmap: View {
    var hours: [RecentUsageHour]
    var theme: IslandThemePalette
    var legend: String

    private var maxTokens: Int {
        max(hours.map(\.totalTokens).max() ?? 1, 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let cellSpacing: CGFloat = 4
            let cellWidth = max(8, (proxy.size.width - CGFloat(hours.count - 1) * cellSpacing) / CGFloat(hours.count))

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .bottom, spacing: cellSpacing) {
                    ForEach(hours) { hour in
                        VStack(spacing: 5) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: min(8, cellWidth * 0.4), style: .continuous)
                                .fill(fill(for: hour))
                                .frame(width: cellWidth, height: height(for: hour, maxHeight: 116))
                                .overlay(
                                    RoundedRectangle(cornerRadius: min(8, cellWidth * 0.4), style: .continuous)
                                        .strokeBorder(theme.text.opacity(hour.totalTokens > 0 ? 0.10 : 0.04), lineWidth: 0.6)
                                )
                                .help(hour.helpText)

                            Text(hour.shortLabel)
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(theme.textSecondary.opacity(hour.isMajorTick ? 0.86 : 0.34))
                                .lineLimit(1)
                                .frame(width: cellWidth + 2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

                HStack(spacing: 7) {
                    heatmapLegendSwatch(opacity: 0.18)
                    heatmapLegendSwatch(opacity: 0.42)
                    heatmapLegendSwatch(opacity: 0.70)
                    Text(legend)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func height(for hour: RecentUsageHour, maxHeight: CGFloat) -> CGFloat {
        guard hour.totalTokens > 0 else { return 14 }
        return max(18, maxHeight * CGFloat(hour.totalTokens) / CGFloat(maxTokens))
    }

    private func fill(for hour: RecentUsageHour) -> LinearGradient {
        guard hour.totalTokens > 0 else {
            return LinearGradient(
                colors: [theme.surfaceContainer.opacity(0.34), theme.surfaceContainer.opacity(0.28)],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        let intensity = min(1, Double(hour.totalTokens) / Double(maxTokens))
        return LinearGradient(
            colors: [
                theme.primary.opacity(0.28 + 0.52 * intensity),
                theme.secondary.opacity(0.22 + 0.42 * intensity),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func heatmapLegendSwatch(opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(theme.primary.opacity(opacity))
            .frame(width: 12, height: 8)
    }
}

private struct RecentUsageHour: Identifiable {
    var hourStartAt: Date
    var rows: [UsageAnalyticsHourlyModelBucket]

    var id: TimeInterval { hourStartAt.timeIntervalSince1970 }
    var totalTokens: Int { rows.reduce(0) { $0 + $1.totalTokens } }
    var costUSD: Double { rows.reduce(0) { $0 + $1.costUSD } }

    var isMajorTick: Bool {
        Calendar.current.component(.hour, from: hourStartAt) % 6 == 0
    }

    var shortLabel: String {
        isMajorTick ? Self.hourFormatter.string(from: hourStartAt) : " "
    }

    var helpText: String {
        let modelText = rows.prefix(4)
            .map { "\($0.modelDisplayName): \($0.totalTokens.recentUsageTokenString), \($0.costUSD.recentUsageCurrencyString)" }
            .joined(separator: "\n")
        return "\(Self.longFormatter.string(from: hourStartAt))\n\(totalTokens.recentUsageTokenString) · \(costUSD.recentUsageCurrencyString)\n\(modelText)"
    }

    static func completeLast24Hours(from rows: [UsageAnalyticsHourlyModelBucket]) -> [RecentUsageHour] {
        let calendar = Calendar.current
        let currentHour = calendar.dateInterval(of: .hour, for: .now)?.start ?? .now
        let grouped = Dictionary(grouping: rows) { row in
            calendar.dateInterval(of: .hour, for: row.hourStartAt)?.start ?? row.hourStartAt
        }

        return (0..<24).compactMap { offset in
            guard let hour = calendar.date(byAdding: .hour, value: offset - 23, to: currentHour) else {
                return nil
            }
            let hourRows = (grouped[hour] ?? []).sorted { lhs, rhs in
                if lhs.totalTokens == rhs.totalTokens { return lhs.modelDisplayName < rhs.modelDisplayName }
                return lhs.totalTokens > rhs.totalTokens
            }
            return RecentUsageHour(hourStartAt: hour, rows: hourRows)
        }
    }

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("ha")
        return formatter
    }()

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
