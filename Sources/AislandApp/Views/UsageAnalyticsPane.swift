import AppKit
import SwiftUI
import AislandCore

struct UsageAnalyticsPane: View {
    var model: AppModel

    @Environment(\.islandTheme) private var theme
    @State private var selectedHourID: TimeInterval?
    @State private var selectedRangeDays = 7.0

    private var lang: LanguageManager { model.lang }
    private var hourlyUsage: [UsageAnalyticsHourlyModelBucket] { model.usageAnalyticsHourlyModelUsage }
    private var selectedDayCount: Int {
        min(30, max(1, Int(selectedRangeDays.rounded())))
    }
    private var heatmapBucketHourSpan: Int {
        let targetCellCount = 7 * 24
        return (1...24).min { lhs, rhs in
            let lhsCellCount = selectedDayCount * Int(ceil(24.0 / Double(lhs)))
            let rhsCellCount = selectedDayCount * Int(ceil(24.0 / Double(rhs)))
            return abs(lhsCellCount - targetCellCount) < abs(rhsCellCount - targetCellCount)
        } ?? 1
    }
    private var rangedHourlyUsage: [UsageAnalyticsHourlyModelBucket] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -(selectedDayCount - 1), to: today) ?? today
        return hourlyUsage.filter { $0.hourStartAt >= start }
    }
    private var completeHeatmapDays: [UsageHeatmapDay] {
        UsageHeatmapDay.completeRecentDays(
            from: rangedHourlyUsage,
            dayCount: selectedDayCount,
            bucketHourSpan: heatmapBucketHourSpan
        )
    }
    private var heatmapDays: [UsageHeatmapDay] {
        UsageHeatmapDay.trimmedToMeaningfulHours(days: completeHeatmapDays)
    }
    private var heatmapCells: [UsageHeatmapHourCell] { heatmapDays.flatMap(\.cells) }
    private var heatmapHourCount: Int { heatmapDays.first?.cells.count ?? 24 }

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
        Form {
            Section(lang.t("usage.heatmap.title")) {
                rangeControl

                if hourlyUsage.isEmpty {
                    emptyState
                } else {
                    HeatmapSummaryStrip(
                        totalTokens: totalTokens,
                        totalCostUSD: totalCostUSD,
                        activeHourCount: activeHourCount,
                        hourColumnCount: heatmapHourCount,
                        dayCount: selectedDayCount,
                        peakCell: peakCell,
                        rangeLabel: rangeLabel,
                        lang: lang,
                        theme: theme
                    )

                    HStack(alignment: .top, spacing: 16) {
                        HourlyUsageHeatmap(
                            days: heatmapDays,
                            selectedHourID: $selectedHourID,
                            theme: theme,
                            legend: lang.t("usage.heatmap.legend"),
                            lessLabel: lang.t("usage.heatmap.less"),
                            moreLabel: lang.t("usage.heatmap.more")
                        )
                        .frame(maxWidth: .infinity)

                        Divider()

                        UsageHourDetail(
                            cell: selectedCell,
                            lang: lang,
                            theme: theme
                        )
                        .frame(width: 230, alignment: .topLeading)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                }
            }

            if !rangedHourlyUsage.isEmpty {
                Section(lang.t("usage.heatmap.modelBreakdown")) {
                    RecentModelBreakdown(rows: rangedHourlyUsage, theme: theme)
                        .padding(.vertical, 2)
                }
            }
        }
        .formStyle(.grouped)
        .islandSettingsPaneBackground()
        .navigationTitle(lang.t("settings.tab.usage"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.refreshUsageAnalytics()
                } label: {
                    if model.usageAnalyticsIsRefreshing {
                        Label(lang.t("usage.refreshing"), systemImage: "arrow.triangle.2.circlepath")
                    } else {
                        Label(lang.t("usage.refresh"), systemImage: "arrow.clockwise")
                    }
                }
                .disabled(model.usageAnalyticsIsRefreshing)
            }
        }
        .onAppear {
            if hourlyUsage.isEmpty {
                model.refreshUsageAnalytics()
            }
            normalizeSelectedHour()
        }
        .onChange(of: hourlyUsage) { _, _ in
            normalizeSelectedHour()
        }
        .onChange(of: selectedDayCount) { _, _ in
            normalizeSelectedHour()
        }
    }

    private func normalizeSelectedHour() {
        if let selectedHourID, heatmapCells.contains(where: { $0.id == selectedHourID }) {
            return
        }
        selectedHourID = peakCell?.id
    }

    private var rangeLabel: String {
        if selectedDayCount == 1 {
            return lang.t("usage.range.oneDay")
        }
        return lang.t("usage.range.days", selectedDayCount)
    }

    private var rangeControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Slider(value: $selectedRangeDays, in: 1...30, step: 1)
                Text(rangeLabel)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .trailing)
            }
            HStack(spacing: 12) {
                if let refreshedAt = model.usageAnalyticsLastRefreshedAt {
                    Text(refreshedAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let error = model.usageAnalyticsLastRefreshError {
                    Text(error)
                        .foregroundStyle(theme.error)
                        .lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lang.t("usage.empty.title"))
                .font(IslandTheme.bodyFont(size: 14, weight: .semibold))
                .foregroundStyle(theme.text)
            if model.usageAnalyticsIsRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
    }
}

private struct HeatmapSummaryStrip: View {
    var totalTokens: Int
    var totalCostUSD: Double
    var activeHourCount: Int
    var hourColumnCount: Int
    var dayCount: Int
    var peakCell: UsageHeatmapHourCell?
    var rangeLabel: String
    var lang: LanguageManager
    var theme: IslandThemePalette

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], alignment: .leading, spacing: 10) {
            metricCard(
                title: lang.t("usage.heatmap.total"),
                value: totalTokens.abbreviatedTokenString,
                detail: rangeLabel
            )
            metricCard(
                title: lang.t("usage.heatmap.peak"),
                value: peakCell?.totalTokens.abbreviatedTokenString ?? "0",
                detail: peakCell.map { UsageHeatmapFormatters.shortBucketLabel(start: $0.hourStartAt, end: $0.hourEndAt) } ?? lang.t("usage.surface.noRecent")
            )
            metricCard(
                title: lang.t("usage.heatmap.activeHours"),
                value: "\(activeHourCount)",
                detail: "\(dayCount) x \(hourColumnCount)"
            )
            metricCard(
                title: lang.t("usage.heatmap.cost"),
                value: totalCostUSD.currencyString,
                detail: rangeLabel
            )
        }
    }

    private func metricCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(IslandTheme.labelFont(size: 10))
                .foregroundStyle(theme.textSecondary.opacity(0.82))
            Text(value)
                .font(IslandTheme.bodyFont(size: 18, weight: .black))
                .foregroundStyle(theme.text)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(IslandTheme.labelFont(size: 11))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.surfaceContainer.opacity(0.48))
        )
    }
}

private struct HourlyUsageHeatmap: View {
    var days: [UsageHeatmapDay]
    @Binding var selectedHourID: TimeInterval?
    var theme: IslandThemePalette
    var legend: String
    var lessLabel: String
    var moreLabel: String

    private var maxTokens: Int {
        max(days.flatMap(\.cells).map(\.totalTokens).max() ?? 1, 1)
    }

    private var hourValues: [Int] {
        days.first?.cells.map(\.hourOfDay) ?? Array(0..<24)
    }

    var body: some View {
        GeometryReader { proxy in
            let labelWidth: CGFloat = 64
            let cellSpacing: CGFloat = 4
            let columnCount = max(hourValues.count, 1)
            let horizontalPadding: CGFloat = 24
            let availableCellWidth = proxy.size.width - labelWidth - horizontalPadding - CGFloat(max(0, columnCount - 1)) * cellSpacing
            let cellWidth = max(8, availableCellWidth / CGFloat(columnCount))
            let cellHeight: CGFloat = 18

            VStack(alignment: .leading, spacing: 12) {
                hourHeader(labelWidth: labelWidth, cellWidth: cellWidth, spacing: cellSpacing)

                VStack(alignment: .leading, spacing: cellSpacing) {
                    ForEach(days) { day in
                        HStack(spacing: cellSpacing) {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(day.shortLabel)
                                    .font(IslandTheme.labelFont(size: 10))
                                    .foregroundStyle(theme.textSecondary.opacity(day.isToday ? 0.96 : 0.68))
                                Text(day.dateLabel)
                                    .font(IslandTheme.labelFont(size: 8.5))
                                    .foregroundStyle(theme.textTertiary.opacity(day.isToday ? 0.9 : 0.58))
                            }
                            .frame(width: labelWidth, alignment: .trailing)

                            ForEach(day.cells) { cell in
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(fill(for: cell))
                                    .frame(width: cellWidth, height: cellHeight)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
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
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.surfaceContainer.opacity(0.34))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
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
                .font(IslandTheme.labelFont(size: 10.5))
                .foregroundStyle(theme.textSecondary)
            }
        }
        .frame(height: max(190, CGFloat(days.count) * 26 + 74))
    }

    private func hourHeader(labelWidth: CGFloat, cellWidth: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            Color.clear.frame(width: labelWidth, height: 1)
            ForEach(hourValues, id: \.self) { hour in
                Text(shouldShowHourLabel(hour) ? String(format: "%02d", hour) : "")
                    .font(IslandTheme.labelFont(size: 8.5))
                    .foregroundStyle(theme.textSecondary.opacity(0.58))
                    .frame(width: cellWidth)
            }
        }
    }

    private func shouldShowHourLabel(_ hour: Int) -> Bool {
        hour == hourValues.first || hour == hourValues.last || hour % 3 == 0
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
    var cell: UsageHeatmapHourCell?
    var lang: LanguageManager
    var theme: IslandThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let cell {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(lang.t("usage.heatmap.selectedHour"))
                            .font(IslandTheme.labelFont(size: 10))
                            .foregroundStyle(theme.textSecondary.opacity(0.82))
                        Text(UsageHeatmapFormatters.bucketLabel(start: cell.hourStartAt, end: cell.hourEndAt))
                            .font(IslandTheme.bodyFont(size: 14, weight: .semibold))
                            .foregroundStyle(theme.text)
                    }
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(cell.totalTokens.abbreviatedTokenString)
                            .font(IslandTheme.bodyFont(size: 16, weight: .black))
                            .foregroundStyle(theme.text)
                            .monospacedDigit()
                        Text(cell.costUSD.currencyString)
                            .font(IslandTheme.labelFont(size: 11))
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                if cell.rows.isEmpty {
                    Text(lang.t("usage.heatmap.noHour"))
                        .font(IslandTheme.bodyFont(size: 12, weight: .medium))
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
                                        .font(IslandTheme.bodyFont(size: 12, weight: .semibold))
                                        .foregroundStyle(theme.text)
                                        .lineLimit(1)
                                    Text(lang.t("usage.heatmap.tokenBreakdown", row.inputTokens.abbreviatedTokenString, row.outputTokens.abbreviatedTokenString))
                                        .font(IslandTheme.bodyFont(size: 10.5, weight: .medium))
                                        .foregroundStyle(theme.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 10)
                                Text(row.totalTokens.abbreviatedTokenString)
                                    .font(IslandTheme.bodyFont(size: 12, weight: .bold))
                                    .foregroundStyle(theme.text)
                                    .monospacedDigit()
                                Text(lang.t("usage.heatmap.entries", row.entryCount))
                                    .font(IslandTheme.labelFont(size: 10.5))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                    }
                }
            } else {
                Text(lang.t("usage.heatmap.noHour"))
                    .font(IslandTheme.bodyFont(size: 12, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(13)
        .background(theme.surfaceContainer.opacity(0.48), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                            .font(IslandTheme.bodyFont(size: 11.5, weight: .semibold))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                        Text(model.provider?.displayName ?? "")
                            .font(IslandTheme.bodyFont(size: 10, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(model.totalTokens.abbreviatedTokenString)
                            .font(IslandTheme.bodyFont(size: 11.5, weight: .bold))
                            .foregroundStyle(theme.text)
                            .monospacedDigit()
                        Text(model.costUSD.currencyString)
                            .font(IslandTheme.bodyFont(size: 10.5, weight: .bold))
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

    static func completeRecentDays(
        from rows: [UsageAnalyticsHourlyModelBucket],
        dayCount: Int,
        bucketHourSpan: Int
    ) -> [UsageHeatmapDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let currentHour = calendar.dateInterval(of: .hour, for: .now)?.start ?? .now
        let clampedBucketHourSpan = min(24, max(1, bucketHourSpan))
        let grouped = Dictionary(grouping: rows) { row in
            calendar.dateInterval(of: .hour, for: row.hourStartAt)?.start ?? row.hourStartAt
        }

        return (0..<max(1, dayCount)).compactMap { dayOffset in
            guard let day = calendar.date(byAdding: .day, value: dayOffset - max(1, dayCount) + 1, to: today) else {
                return nil
            }

            let cells = stride(from: 0, to: 24, by: clampedBucketHourSpan).compactMap { hourOffset -> UsageHeatmapHourCell? in
                guard let bucketStart = calendar.date(byAdding: .hour, value: hourOffset, to: day),
                      let bucketEnd = calendar.date(
                        byAdding: .hour,
                        value: min(clampedBucketHourSpan, 24 - hourOffset),
                        to: bucketStart
                      ) else {
                    return nil
                }
                let bucketRows = stride(from: hourOffset, to: min(24, hourOffset + clampedBucketHourSpan), by: 1)
                    .compactMap { offset in
                        calendar.date(byAdding: .hour, value: offset, to: day)
                    }
                    .flatMap { grouped[$0] ?? [] }
                    .sorted { lhs, rhs in
                    if lhs.totalTokens == rhs.totalTokens { return lhs.modelDisplayName < rhs.modelDisplayName }
                    return lhs.totalTokens > rhs.totalTokens
                }
                return UsageHeatmapHourCell(
                    hourStartAt: bucketStart,
                    hourEndAt: bucketEnd,
                    rows: bucketRows,
                    isCurrentHour: bucketStart <= currentHour && currentHour < bucketEnd
                )
            }

            return UsageHeatmapDay(dayStartAt: day, cells: cells)
        }
    }

    static func trimmedToMeaningfulHours(days: [UsageHeatmapDay]) -> [UsageHeatmapDay] {
        let activeHours = days
            .flatMap(\.cells)
            .filter { $0.hasUsage && !$0.isFuture }
            .map(\.hourOfDay)

        guard let firstHour = activeHours.min(), let lastHour = activeHours.max() else {
            return days
        }

        return days.map { day in
            UsageHeatmapDay(
                dayStartAt: day.dayStartAt,
                cells: day.cells.filter { (firstHour...lastHour).contains($0.hourOfDay) }
            )
        }
    }
}

private struct UsageHeatmapHourCell: Identifiable {
    var hourStartAt: Date
    var hourEndAt: Date
    var rows: [UsageAnalyticsHourlyModelBucket]
    var isCurrentHour: Bool

    var id: TimeInterval { hourStartAt.timeIntervalSince1970 }
    var totalTokens: Int { rows.reduce(0) { $0 + $1.totalTokens } }
    var inputTokens: Int { rows.reduce(0) { $0 + $1.inputTokens } }
    var outputTokens: Int { rows.reduce(0) { $0 + $1.outputTokens } }
    var costUSD: Double { rows.reduce(0) { $0 + $1.costUSD } }
    var hasUsage: Bool { totalTokens > 0 || costUSD > 0 }
    var isFuture: Bool { hourStartAt > .now }
    var hourOfDay: Int { Calendar.current.component(.hour, from: hourStartAt) }

    var helpText: String {
        let modelText = rows.prefix(4)
            .map { "\($0.modelDisplayName): \($0.totalTokens.abbreviatedTokenString), \($0.costUSD.currencyString)" }
            .joined(separator: "\n")
        let suffix = modelText.isEmpty ? "" : "\n\(modelText)"
        return "\(UsageHeatmapFormatters.bucketLabel(start: hourStartAt, end: hourEndAt))\n\(totalTokens.abbreviatedTokenString) · \(costUSD.currencyString)\(suffix)"
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

    static func shortBucketLabel(start: Date, end: Date) -> String {
        let adjustedEnd = end.addingTimeInterval(-1)
        if Calendar.current.dateComponents([.hour], from: start, to: end).hour == 1 {
            return hourLabel.string(from: start)
        }
        return "\(hourLabel.string(from: start))-\(hourOnlyLabel.string(from: adjustedEnd))"
    }

    static func bucketLabel(start: Date, end: Date) -> String {
        let adjustedEnd = end.addingTimeInterval(-1)
        if Calendar.current.dateComponents([.hour], from: start, to: end).hour == 1 {
            return detailHourLabel.string(from: start)
        }
        return "\(detailHourLabel.string(from: start)) - \(hourOnlyLabel.string(from: adjustedEnd))"
    }

    private static let hourOnlyLabel: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("HH")
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
