import AppKit
import SwiftUI
import AislandCore

struct UsageAnalyticsPane: View {
    var model: AppModel

    @Environment(\.islandTheme) private var theme
    @State private var selectedHourID: TimeInterval?

    private var lang: LanguageManager { model.lang }
    private var hourlyUsage: [UsageAnalyticsHourlyModelBucket] { model.usageAnalyticsHourlyModelUsage }
    private var heatmapDays: [UsageHeatmapDay] { UsageHeatmapDay.completeRecentDays(from: hourlyUsage, dayCount: 7) }
    private var heatmapCells: [UsageHeatmapHourCell] { heatmapDays.flatMap(\.cells) }

    private var totalTokens: Int { heatmapCells.reduce(0) { $0 + $1.totalTokens } }
    private var totalCostUSD: Double { heatmapCells.reduce(0) { $0 + $1.costUSD } }
    private var activeHourCount: Int { heatmapCells.filter(\.hasUsage).count }

    private var peakCell: UsageHeatmapHourCell? {
        heatmapCells
            .filter { $0.hasUsage && !$0.isFuture }
            .max { lhs, rhs in
                if lhs.totalTokens == rhs.totalTokens { return lhs.costUSD < rhs.costUSD }
                return lhs.totalTokens < rhs.totalTokens
            }
    }

    private var selectedCell: UsageHeatmapHourCell? {
        guard let selectedHourID else { return peakCell }
        return heatmapCells.first { $0.id == selectedHourID } ?? peakCell
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                usageToolbar
                recentPeakHeatmapSection
                modelBreakdownSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .islandSettingsPaneBackground()
        .navigationTitle(lang.t("settings.tab.usage"))
        .onAppear {
            if hourlyUsage.isEmpty {
                model.refreshUsageAnalytics()
            }
            selectedHourID = selectedHourID ?? peakCell?.id
        }
        .onChange(of: hourlyUsage) { _, _ in
            selectedHourID = selectedHourID ?? peakCell?.id
        }
    }

    private var usageToolbar: some View {
        HStack(alignment: .center, spacing: 10) {
            if model.usageAnalyticsIsRefreshing {
                Label(lang.t("usage.refreshing"), systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            } else if let refreshedAt = model.usageAnalyticsLastRefreshedAt {
                Text(refreshedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer(minLength: 12)

            Button(lang.t("usage.refresh")) {
                model.refreshUsageAnalytics()
            }
            .buttonStyle(.bordered)
            .disabled(model.usageAnalyticsIsRefreshing)
        }
    }

    private var recentPeakHeatmapSection: some View {
        usagePanel {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeading(
                    title: lang.t("usage.heatmap.title"),
                    subtitle: lang.t("usage.heatmap.subtitle")
                )

                if hourlyUsage.isEmpty {
                    emptyState
                } else {
                    HeatmapSummaryStrip(
                        totalTokens: totalTokens,
                        totalCostUSD: totalCostUSD,
                        activeHourCount: activeHourCount,
                        peakCell: peakCell,
                        lang: lang,
                        theme: theme
                    )

                    SevenDayHourlyHeatmap(
                        days: heatmapDays,
                        selectedHourID: $selectedHourID,
                        theme: theme,
                        legend: lang.t("usage.heatmap.legend"),
                        lessLabel: lang.t("usage.heatmap.less"),
                        moreLabel: lang.t("usage.heatmap.more")
                    )

                    if let selectedCell {
                        UsageHourDetail(cell: selectedCell, lang: lang, theme: theme)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var modelBreakdownSection: some View {
        if !hourlyUsage.isEmpty {
            usagePanel {
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeading(
                        title: lang.t("usage.heatmap.modelBreakdown"),
                        subtitle: lang.t("usage.heatmap.modelBreakdown.subtitle")
                    )
                    RecentModelBreakdown(rows: hourlyUsage, theme: theme)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lang.t("usage.empty.title"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.text)
            Text(lang.t("usage.empty.subtitle"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            if model.usageAnalyticsIsRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
    }

    private func usagePanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(theme.card.opacity(0.86))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(theme.outline.opacity(0.12))
            )
    }

    private func sectionHeading(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.text)
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.textSecondary)
        }
    }
}

private struct HeatmapSummaryStrip: View {
    var totalTokens: Int
    var totalCostUSD: Double
    var activeHourCount: Int
    var peakCell: UsageHeatmapHourCell?
    var lang: LanguageManager
    var theme: IslandThemePalette

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], alignment: .leading, spacing: 10) {
            metricCard(
                title: lang.t("usage.heatmap.total"),
                value: totalTokens.abbreviatedTokenString,
                detail: lang.t("usage.surface.recentDays")
            )
            metricCard(
                title: lang.t("usage.heatmap.peak"),
                value: peakCell?.totalTokens.abbreviatedTokenString ?? "0",
                detail: peakCell.map { UsageHeatmapFormatters.hourLabel.string(from: $0.hourStartAt) } ?? lang.t("usage.surface.noRecent")
            )
            metricCard(
                title: lang.t("usage.heatmap.activeHours"),
                value: "\(activeHourCount)",
                detail: "7 x 24"
            )
            metricCard(
                title: lang.t("usage.heatmap.cost"),
                value: totalCostUSD.currencyString,
                detail: lang.t("usage.surface.recentDays")
            )
        }
    }

    private func metricCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.textSecondary.opacity(0.82))
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(theme.text)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.surfaceContainer.opacity(0.48))
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(theme.primary.opacity(0.18))
                .frame(width: 34, height: 34)
                .blur(radius: 12)
                .offset(x: 8, y: -8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SevenDayHourlyHeatmap: View {
    var days: [UsageHeatmapDay]
    @Binding var selectedHourID: TimeInterval?
    var theme: IslandThemePalette
    var legend: String
    var lessLabel: String
    var moreLabel: String

    private var maxTokens: Int {
        max(days.flatMap(\.cells).map(\.totalTokens).max() ?? 1, 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let labelWidth: CGFloat = 64
            let cellSpacing: CGFloat = 4
            let availableCellWidth = proxy.size.width - labelWidth - CGFloat(23) * cellSpacing
            let cellSize = min(22, max(10, availableCellWidth / 24))

            VStack(alignment: .leading, spacing: 12) {
                hourHeader(labelWidth: labelWidth, cellSize: cellSize, spacing: cellSpacing)

                VStack(alignment: .leading, spacing: cellSpacing) {
                    ForEach(days) { day in
                        HStack(spacing: cellSpacing) {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(day.shortLabel)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(theme.textSecondary.opacity(day.isToday ? 0.96 : 0.68))
                                Text(day.dateLabel)
                                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(theme.textTertiary.opacity(day.isToday ? 0.9 : 0.58))
                            }
                            .frame(width: labelWidth, alignment: .trailing)

                            ForEach(day.cells) { cell in
                                RoundedRectangle(cornerRadius: cellSize * 0.28, style: .continuous)
                                    .fill(fill(for: cell))
                                    .frame(width: cellSize, height: cellSize)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: cellSize * 0.28, style: .continuous)
                                            .strokeBorder(stroke(for: cell), lineWidth: selectedHourID == cell.id ? 1.6 : 0.7)
                                    )
                                    .shadow(color: glow(for: cell), radius: cell.hasUsage ? 5 : 0, x: 0, y: 0)
                                    .contentShape(Rectangle())
                                    .help(cell.helpText)
                                    .onTapGesture { selectedHourID = cell.id }
                            }
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(theme.surfaceContainer.opacity(0.34))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(theme.outline.opacity(0.08))
                )

                HStack(spacing: 7) {
                    Text(legend)
                    Spacer(minLength: 0)
                    Text(lessLabel)
                    ForEach([0.08, 0.24, 0.44, 0.68, 1.0], id: \.self) { intensity in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(UsageHeatmapColor.color(theme: theme, intensity: intensity))
                            .frame(width: 13, height: 13)
                    }
                    Text(moreLabel)
                }
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            }
        }
        .frame(height: 230)
    }

    private func hourHeader(labelWidth: CGFloat, cellSize: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            Color.clear.frame(width: labelWidth, height: 1)
            ForEach(0..<24, id: \.self) { hour in
                Text(hour % 3 == 0 ? String(format: "%02d", hour) : "")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textSecondary.opacity(0.58))
                    .frame(width: cellSize)
            }
        }
    }

    private func fill(for cell: UsageHeatmapHourCell) -> Color {
        guard !cell.isFuture else {
            return theme.surfaceContainer.opacity(0.18)
        }
        guard cell.hasUsage else {
            return theme.surfaceContainer.opacity(0.42)
        }

        let normalized = Double(cell.totalTokens) / Double(maxTokens)
        return UsageHeatmapColor.color(theme: theme, intensity: sqrt(min(max(normalized, 0), 1)))
    }

    private func stroke(for cell: UsageHeatmapHourCell) -> Color {
        if selectedHourID == cell.id {
            return theme.text.opacity(0.76)
        }
        if cell.isCurrentHour {
            return theme.primaryContainer.opacity(0.7)
        }
        return theme.text.opacity(cell.hasUsage ? 0.12 : 0.05)
    }

    private func glow(for cell: UsageHeatmapHourCell) -> Color {
        guard cell.hasUsage else { return Color.clear }
        let normalized = Double(cell.totalTokens) / Double(maxTokens)
        return UsageHeatmapColor.color(theme: theme, intensity: normalized).opacity(0.16 + 0.18 * normalized)
    }
}

private struct UsageHourDetail: View {
    var cell: UsageHeatmapHourCell
    var lang: LanguageManager
    var theme: IslandThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(lang.t("usage.heatmap.selectedHour"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.textSecondary.opacity(0.82))
                    Text(UsageHeatmapFormatters.detailHourLabel.string(from: cell.hourStartAt))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.text)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(cell.totalTokens.abbreviatedTokenString)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(theme.text)
                        .monospacedDigit()
                    Text(cell.costUSD.currencyString)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textSecondary)
                }
            }

            if cell.rows.isEmpty {
                Text(lang.t("usage.heatmap.noHour"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            } else {
                VStack(spacing: 7) {
                    ForEach(cell.rows.prefix(5)) { row in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(UsageModelColor.color(for: row.modelIdentifier, theme: theme))
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.modelDisplayName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(theme.text)
                                    .lineLimit(1)
                                Text(lang.t("usage.heatmap.tokenBreakdown", row.inputTokens.abbreviatedTokenString, row.outputTokens.abbreviatedTokenString))
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(theme.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 10)
                            Text(row.totalTokens.abbreviatedTokenString)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(theme.text)
                                .monospacedDigit()
                            Text(lang.t("usage.heatmap.entries", row.entryCount))
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(13)
        .background(theme.surfaceContainer.opacity(0.48), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct RecentModelBreakdown: View {
    var rows: [UsageAnalyticsHourlyModelBucket]
    var theme: IslandThemePalette

    private var models: [UsageHeatmapModelSummary] {
        Dictionary(grouping: rows) { row in
            "\(row.provider.rawValue)|\(row.modelIdentifier)"
        }
        .map { _, rows in
            UsageHeatmapModelSummary(
                id: "\(rows.first?.provider.rawValue ?? "unknown")|\(rows.first?.modelIdentifier ?? "unknown")",
                modelIdentifier: rows.first?.modelIdentifier ?? "unknown",
                modelDisplayName: rows.first?.modelDisplayName ?? "Unknown",
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
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(models) { model in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(UsageModelColor.chartGradient(for: model.modelIdentifier, theme: theme))
                        .frame(width: 10, height: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.modelDisplayName)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                        Text(model.provider?.displayName ?? "")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(model.totalTokens.abbreviatedTokenString)
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.text)
                            .monospacedDigit()
                        Text(model.costUSD.currencyString)
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(theme.surfaceContainer.opacity(0.48), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

private struct UsageHeatmapDay: Identifiable {
    var dayStartAt: Date
    var cells: [UsageHeatmapHourCell]

    var id: TimeInterval { dayStartAt.timeIntervalSince1970 }
    var isToday: Bool { Calendar.current.isDateInToday(dayStartAt) }

    var shortLabel: String {
        UsageHeatmapFormatters.weekdayLabel.string(from: dayStartAt)
    }

    var dateLabel: String {
        UsageHeatmapFormatters.dayLabel.string(from: dayStartAt)
    }

    static func completeRecentDays(from rows: [UsageAnalyticsHourlyModelBucket], dayCount: Int) -> [UsageHeatmapDay] {
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

            let cells = (0..<24).compactMap { hourOffset -> UsageHeatmapHourCell? in
                guard let hour = calendar.date(byAdding: .hour, value: hourOffset, to: day) else {
                    return nil
                }
                let hourRows = (grouped[hour] ?? []).sorted { lhs, rhs in
                    if lhs.totalTokens == rhs.totalTokens { return lhs.modelDisplayName < rhs.modelDisplayName }
                    return lhs.totalTokens > rhs.totalTokens
                }
                return UsageHeatmapHourCell(hourStartAt: hour, rows: hourRows, isCurrentHour: hour == currentHour)
            }

            return UsageHeatmapDay(dayStartAt: day, cells: cells)
        }
    }
}

private struct UsageHeatmapHourCell: Identifiable {
    var hourStartAt: Date
    var rows: [UsageAnalyticsHourlyModelBucket]
    var isCurrentHour: Bool

    var id: TimeInterval { hourStartAt.timeIntervalSince1970 }
    var totalTokens: Int { rows.reduce(0) { $0 + $1.totalTokens } }
    var inputTokens: Int { rows.reduce(0) { $0 + $1.inputTokens } }
    var outputTokens: Int { rows.reduce(0) { $0 + $1.outputTokens } }
    var costUSD: Double { rows.reduce(0) { $0 + $1.costUSD } }
    var hasUsage: Bool { totalTokens > 0 || costUSD > 0 }
    var isFuture: Bool { hourStartAt > .now }

    var helpText: String {
        let modelText = rows.prefix(4)
            .map { "\($0.modelDisplayName): \($0.totalTokens.abbreviatedTokenString), \($0.costUSD.currencyString)" }
            .joined(separator: "\n")
        let suffix = modelText.isEmpty ? "" : "\n\(modelText)"
        return "\(UsageHeatmapFormatters.detailHourLabel.string(from: hourStartAt))\n\(totalTokens.abbreviatedTokenString) · \(costUSD.currencyString)\(suffix)"
    }
}

private struct UsageHeatmapModelSummary: Identifiable {
    var id: String
    var modelIdentifier: String
    var modelDisplayName: String
    var provider: UsageLogProvider?
    var totalTokens: Int
    var costUSD: Double
}

private enum UsageHeatmapFormatters {
    static let weekdayLabel: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

    static let dayLabel: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter
    }()

    static let hourLabel: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEE HH")
        return formatter
    }()

    static let detailHourLabel: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private enum UsageHeatmapColor {
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

        let saturationValue = Double(max(0.18, saturation)) * (0.24 + 0.76 * clamped)
        let brightnessValue = Double(max(0.42, brightness)) * (0.42 + 0.58 * clamped)
        return Color(
            hue: Double(hue),
            saturation: min(1, saturationValue),
            brightness: min(1, brightnessValue),
            opacity: 0.38 + 0.58 * clamped
        )
    }
}

private enum UsageModelColor {
    static func color(for modelIdentifier: String, theme: IslandThemePalette) -> Color {
        let palette: [Color] = [
            theme.primary,
            blended(theme.primary, with: theme.primaryContainer, amount: 0.34),
            blended(theme.primary, with: theme.secondary, amount: 0.24),
            blended(theme.primary, with: theme.tertiary, amount: 0.22),
            blended(theme.primaryContainer, with: theme.text, amount: 0.18),
            blended(theme.primary, with: theme.success, amount: 0.18),
            blended(theme.secondary, with: theme.primary, amount: 0.32),
            blended(theme.tertiary, with: theme.primary, amount: 0.30),
        ]
        let hash = abs(modelIdentifier.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) })
        return palette[hash % palette.count]
    }

    static func chartGradient(for modelIdentifier: String, theme: IslandThemePalette) -> LinearGradient {
        let base = color(for: modelIdentifier, theme: theme)
        return LinearGradient(
            colors: [
                blended(base, with: theme.surfaceBright, amount: 0.18),
                base,
                blended(base, with: theme.text, amount: 0.08),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private static func blended(_ color: Color, with otherColor: Color, amount: CGFloat) -> Color {
        guard let lhs = NSColor(color).usingColorSpace(.deviceRGB),
              let rhs = NSColor(otherColor).usingColorSpace(.deviceRGB) else {
            return color
        }

        let clampedAmount = min(max(amount, 0), 1)
        let inverse = 1 - clampedAmount
        return Color(
            red: Double(lhs.redComponent * inverse + rhs.redComponent * clampedAmount),
            green: Double(lhs.greenComponent * inverse + rhs.greenComponent * clampedAmount),
            blue: Double(lhs.blueComponent * inverse + rhs.blueComponent * clampedAmount),
            opacity: Double(lhs.alphaComponent * inverse + rhs.alphaComponent * clampedAmount)
        )
    }
}

private extension Int {
    var abbreviatedTokenString: String {
        let value = Double(self)
        if self >= 1_000_000_000 { return String(format: "%.1fB", value / 1_000_000_000) }
        if self >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if self >= 1_000 { return String(format: "%.1fK", value / 1_000) }
        return formatted()
    }
}

private extension Double {
    var currencyString: String {
        if self >= 100 { return String(format: "$%.0f", self) }
        if self >= 10 { return String(format: "$%.1f", self) }
        return String(format: "$%.2f", self)
    }
}
