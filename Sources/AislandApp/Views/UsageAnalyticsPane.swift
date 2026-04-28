import AppKit
import SwiftUI
import AislandCore

struct UsageAnalyticsPane: View {
    var model: AppModel

    @Environment(\.islandTheme) private var theme
    @State private var selectedRangeDays = 7.0

    private var lang: LanguageManager { model.lang }
    private var hourlyUsage: [UsageAnalyticsHourlyModelBucket] { model.usageAnalyticsHourlyModelUsage }
    private var selectedDayCount: Int {
        min(30, max(1, Int(selectedRangeDays.rounded())))
    }
    private var rangedHourlyUsage: [UsageAnalyticsHourlyModelBucket] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -(selectedDayCount - 1), to: today) ?? today
        return hourlyUsage.filter { $0.hourStartAt >= start }
    }
    private var calendarDays: [UsageCalendarDay] {
        UsageCalendarDay.completeRecentDays(from: rangedHourlyUsage, dayCount: selectedDayCount)
    }
    private var calendarHours: [UsageCalendarHourCell] { calendarDays.flatMap(\.hourCells) }
    private var totalTokens: Int { calendarHours.reduce(0) { $0 + $1.totalTokens } }
    private var totalCostUSD: Double { calendarHours.reduce(0) { $0 + $1.costUSD } }
    private var activeDayCount: Int { calendarDays.filter(\.hasUsage).count }
    private var peakDay: UsageCalendarDay? {
        calendarDays
            .filter { $0.hasUsage && !$0.isFuture }
            .max { lhs, rhs in
                if lhs.totalTokens == rhs.totalTokens { return lhs.costUSD < rhs.costUSD }
                return lhs.totalTokens < rhs.totalTokens
            }
    }

    var body: some View {
        Form {
            Section {
                if hourlyUsage.isEmpty {
                    emptyState
                } else {
                    UsageSummaryStrip(
                        totalTokens: totalTokens,
                        totalCostUSD: totalCostUSD,
                        activeDayCount: activeDayCount,
                        peakDay: peakDay,
                        rangeLabel: rangeLabel,
                        lang: lang,
                        theme: theme
                    )

                    rangeControl

                    usageCharts
                        .padding(.top, 6)
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
        }
    }

    private var usageCharts: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 14) {
                UsageCalendarPanel(days: calendarDays, lang: lang, theme: theme)
                    .frame(minWidth: 430, maxWidth: .infinity, alignment: .topLeading)
                ModelContributionPareto(rows: rangedHourlyUsage, title: lang.t("usage.pareto.title"), theme: theme)
                    .frame(width: 286, alignment: .topLeading)
            }
            VStack(alignment: .leading, spacing: 14) {
                UsageCalendarPanel(days: calendarDays, lang: lang, theme: theme)
                ModelContributionPareto(rows: rangedHourlyUsage, title: lang.t("usage.pareto.title"), theme: theme)
            }
        }
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

private struct UsageSummaryStrip: View {
    var totalTokens: Int
    var totalCostUSD: Double
    var activeDayCount: Int
    var peakDay: UsageCalendarDay?
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
                value: peakDay?.totalTokens.abbreviatedTokenString ?? "0",
                detail: peakDay?.dateLabel ?? lang.t("usage.surface.noRecent")
            )
            metricCard(
                title: lang.t("usage.calendar.activeDays"),
                value: "\(activeDayCount)",
                detail: rangeLabel
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

private struct UsageCalendarPanel: View {
    var days: [UsageCalendarDay]
    var lang: LanguageManager
    var theme: IslandThemePalette

    @State private var hoveredDayID: TimeInterval?

    private var hoveredDay: UsageCalendarDay? {
        guard let hoveredDayID else { return nil }
        return days.first { $0.id == hoveredDayID }
    }
    private var maxTokens: Int { max(days.map(\.totalTokens).max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(lang.t("usage.calendar.title"))
                    .font(IslandTheme.bodyFont(size: 13, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer(minLength: 12)
                Text(lang.t("usage.heatmap.legend"))
                    .font(IslandTheme.labelFont(size: 10.5))
                    .foregroundStyle(theme.textSecondary)
            }

            ZStack(alignment: .topTrailing) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 72, maximum: 98), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(days) { day in
                        UsageCalendarDayCard(
                            day: day,
                            maxTokens: maxTokens,
                            theme: theme
                        )
                        .onHover { isHovering in
                            if isHovering {
                                hoveredDayID = day.id
                            } else if hoveredDayID == day.id {
                                hoveredDayID = nil
                            }
                        }
                    }
                }

                if let hoveredDay {
                    UsageCalendarDayHoverDetail(day: hoveredDay, lang: lang, theme: theme)
                        .frame(width: 280, alignment: .topLeading)
                        .padding(10)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeOut(duration: 0.16), value: hoveredDayID)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.surfaceContainer.opacity(0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(theme.outline.opacity(0.08))
        )
    }
}

private struct UsageCalendarDayCard: View {
    var day: UsageCalendarDay
    var maxTokens: Int
    var theme: IslandThemePalette

    private var intensity: Double {
        guard maxTokens > 0 else { return 0 }
        return min(max(Double(day.totalTokens) / Double(maxTokens), 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(day.shortLabel)
                    .font(IslandTheme.labelFont(size: 9.5))
                    .foregroundStyle(theme.textSecondary.opacity(day.includesToday ? 0.96 : 0.72))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if day.includesToday {
                    Circle()
                        .fill(theme.primaryContainer.opacity(0.72))
                        .frame(width: 5, height: 5)
                }
            }
            Text(day.dateLabel)
                .font(IslandTheme.labelFont(size: 8.5))
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)
            Spacer(minLength: 10)
            Text(day.totalTokens.abbreviatedTokenString)
                .font(IslandTheme.bodyFont(size: 12, weight: .black))
                .foregroundStyle(day.hasUsage ? theme.text : theme.textSecondary.opacity(0.58))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(day.costUSD.currencyString)
                .font(IslandTheme.labelFont(size: 9))
                .foregroundStyle(theme.textSecondary.opacity(day.hasUsage ? 0.88 : 0.48))
                .lineLimit(1)
        }
        .padding(8)
        .frame(height: 76, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .bottom) {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(fill)
                        .frame(height: max(day.hasUsage ? 7 : 0, proxy.size.height * CGFloat(intensity)))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.surfaceContainer.opacity(0.38))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(stroke, lineWidth: day.includesToday ? 1.2 : 0.8)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .help(day.helpText)
    }

    private var fill: LinearGradient {
        let hot = intensity >= 0.76
        let base = hot ? theme.primaryContainer : theme.primary
        return LinearGradient(
            colors: [base.opacity(0.08), base.opacity(hot ? 0.68 : 0.56)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var stroke: Color {
        if day.includesToday { return theme.primaryContainer.opacity(0.65) }
        return theme.text.opacity(day.hasUsage ? 0.10 : 0.055)
    }
}

private struct UsageCalendarDayHoverDetail: View {
    var day: UsageCalendarDay
    var lang: LanguageManager
    var theme: IslandThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.detailLabel)
                        .font(IslandTheme.bodyFont(size: 13, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Text(lang.t("usage.calendar.hourlyBreakdown"))
                        .font(IslandTheme.labelFont(size: 10))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(day.totalTokens.abbreviatedTokenString)
                        .font(IslandTheme.bodyFont(size: 15, weight: .black))
                        .foregroundStyle(theme.text)
                        .monospacedDigit()
                    Text(day.costUSD.currencyString)
                        .font(IslandTheme.labelFont(size: 10))
                        .foregroundStyle(theme.textSecondary)
                }
            }

            if day.modelSummaries.isEmpty {
                Text(lang.t("usage.calendar.noDay"))
                    .font(IslandTheme.bodyFont(size: 11, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(day.modelSummaries.prefix(4)) { model in
                        HStack(spacing: 7) {
                            Circle()
                                .fill(UsageModelColor.color(for: model.modelIdentifier, theme: theme))
                                .frame(width: 7, height: 7)
                            Text(model.modelDisplayName)
                                .font(IslandTheme.bodyFont(size: 11, weight: .semibold))
                                .foregroundStyle(theme.text)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text(model.totalTokens.abbreviatedTokenString)
                                .font(IslandTheme.bodyFont(size: 11, weight: .bold))
                                .foregroundStyle(theme.textSecondary)
                                .monospacedDigit()
                        }
                    }
                }
            }

            UsageHourlySparkHeatmap(cells: day.hourCells, theme: theme)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.surfaceBright.opacity(0.96))
                .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.outline.opacity(0.14))
        )
    }
}

private struct UsageHourlySparkHeatmap: View {
    var cells: [UsageCalendarHourCell]
    var theme: IslandThemePalette

    private var maxTokens: Int { max(cells.map(\.totalTokens).max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(cells) { cell in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(fill(for: cell))
                        .frame(height: barHeight(for: cell))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(cell.isCurrentHour ? theme.primaryContainer.opacity(0.65) : .clear, lineWidth: 0.9)
                        )
                }
            }
            .frame(height: 42, alignment: .bottom)

            HStack {
                Text("00")
                Spacer(minLength: 0)
                Text("06")
                Spacer(minLength: 0)
                Text("12")
                Spacer(minLength: 0)
                Text("18")
                Spacer(minLength: 0)
                Text("23")
            }
            .font(IslandTheme.labelFont(size: 8.5))
            .foregroundStyle(theme.textTertiary)
        }
        .padding(.top, 9)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.outline.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func barHeight(for cell: UsageCalendarHourCell) -> CGFloat {
        guard cell.hasUsage else { return 5 }
        let normalized = Double(cell.totalTokens) / Double(maxTokens)
        return 5 + 37 * CGFloat(sqrt(min(max(normalized, 0), 1)))
    }

    private func fill(for cell: UsageCalendarHourCell) -> Color {
        guard !cell.isFuture else { return theme.surfaceContainer.opacity(0.16) }
        guard cell.hasUsage else { return theme.surfaceContainer.opacity(0.42) }
        let normalized = Double(cell.totalTokens) / Double(maxTokens)
        return UsageHeatmapColor.color(theme: theme, intensity: sqrt(min(max(normalized, 0), 1)))
    }
}

private struct ModelContributionPareto: View {
    var rows: [UsageAnalyticsHourlyModelBucket]
    var title: String
    var theme: IslandThemePalette

    private var models: [UsageModelSummary] {
        UsageModelSummary.models(from: rows)
    }
    private var maxTokens: Int { max(models.map(\.totalTokens).max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(IslandTheme.bodyFont(size: 13, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer(minLength: 8)
                Text("Pareto")
                    .font(IslandTheme.labelFont(size: 10.5))
                    .foregroundStyle(theme.textSecondary)
            }

            if models.isEmpty {
                Text("-")
                    .font(IslandTheme.bodyFont(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                VStack(spacing: 10) {
                    ForEach(models.prefix(7)) { model in
                        ModelContributionRow(model: model, maxTokens: maxTokens, theme: theme)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.surfaceContainer.opacity(0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(theme.outline.opacity(0.08))
        )
    }
}

private struct ModelContributionRow: View {
    var model: UsageModelSummary
    var maxTokens: Int
    var theme: IslandThemePalette

    private var ratio: Double {
        guard maxTokens > 0 else { return 0 }
        return min(max(Double(model.totalTokens) / Double(maxTokens), 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.modelDisplayName)
                        .font(IslandTheme.bodyFont(size: 11.5, weight: .semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Text(model.provider?.displayName ?? "")
                        .font(IslandTheme.labelFont(size: 9.5))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(model.totalTokens.abbreviatedTokenString)
                        .font(IslandTheme.bodyFont(size: 11.5, weight: .bold))
                        .foregroundStyle(theme.text)
                        .monospacedDigit()
                    Text(model.costUSD.currencyString)
                        .font(IslandTheme.labelFont(size: 9.5))
                        .foregroundStyle(theme.textSecondary)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.surfaceContainer.opacity(0.52))
                    Capsule()
                        .fill(UsageModelColor.chartGradient(for: model.modelIdentifier, theme: theme))
                        .frame(width: max(8, proxy.size.width * CGFloat(ratio)))
                }
            }
            .frame(height: 18)
        }
        .padding(.vertical, 2)
    }
}

private struct UsageCalendarDay: Identifiable {
    var dayStartAt: Date
    var hourCells: [UsageCalendarHourCell]

    var id: TimeInterval { dayStartAt.timeIntervalSince1970 }
    var includesToday: Bool { Calendar.current.isDateInToday(dayStartAt) }
    var isFuture: Bool { dayStartAt > .now }
    var totalTokens: Int { hourCells.reduce(0) { $0 + $1.totalTokens } }
    var costUSD: Double { hourCells.reduce(0) { $0 + $1.costUSD } }
    var hasUsage: Bool { totalTokens > 0 || costUSD > 0 }
    var rows: [UsageAnalyticsHourlyModelBucket] { hourCells.flatMap(\.rows) }
    var modelSummaries: [UsageModelSummary] { UsageModelSummary.models(from: rows) }

    var shortLabel: String {
        UsageCalendarFormatters.weekdayLabel.string(from: dayStartAt)
    }

    var dateLabel: String {
        UsageCalendarFormatters.dayLabel.string(from: dayStartAt)
    }

    var detailLabel: String {
        UsageCalendarFormatters.detailDayLabel.string(from: dayStartAt)
    }

    var helpText: String {
        let modelText = modelSummaries.prefix(4)
            .map { "\($0.modelDisplayName): \($0.totalTokens.abbreviatedTokenString), \($0.costUSD.currencyString)" }
            .joined(separator: "\n")
        let suffix = modelText.isEmpty ? "" : "\n\(modelText)"
        return "\(detailLabel)\n\(totalTokens.abbreviatedTokenString) · \(costUSD.currencyString)\(suffix)"
    }

    static func completeRecentDays(
        from rows: [UsageAnalyticsHourlyModelBucket],
        dayCount: Int
    ) -> [UsageCalendarDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let currentHour = calendar.dateInterval(of: .hour, for: .now)?.start ?? .now
        let clampedDayCount = max(1, dayCount)
        let grouped = Dictionary(grouping: rows) { row in
            calendar.dateInterval(of: .hour, for: row.hourStartAt)?.start ?? row.hourStartAt
        }

        return (0..<clampedDayCount).compactMap { dayOffset in
            guard let day = calendar.date(byAdding: .day, value: dayOffset - clampedDayCount + 1, to: today) else {
                return nil
            }

            let hourCells = (0..<24).compactMap { hourOffset -> UsageCalendarHourCell? in
                guard let hourStart = calendar.date(byAdding: .hour, value: hourOffset, to: day),
                      let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) else {
                    return nil
                }
                let hourRows = (grouped[hourStart] ?? [])
                    .sorted { lhs, rhs in
                        if lhs.totalTokens == rhs.totalTokens { return lhs.modelDisplayName < rhs.modelDisplayName }
                        return lhs.totalTokens > rhs.totalTokens
                    }
                return UsageCalendarHourCell(
                    hourStartAt: hourStart,
                    hourEndAt: hourEnd,
                    rows: hourRows,
                    isCurrentHour: hourStart <= currentHour && currentHour < hourEnd
                )
            }

            return UsageCalendarDay(dayStartAt: day, hourCells: hourCells)
        }
    }
}

private struct UsageCalendarHourCell: Identifiable {
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
}

private struct UsageModelSummary: Identifiable {
    var id: String
    var modelIdentifier: String
    var modelDisplayName: String
    var provider: UsageLogProvider?
    var totalTokens: Int
    var costUSD: Double

    static func models(from rows: [UsageAnalyticsHourlyModelBucket]) -> [UsageModelSummary] {
        Dictionary(grouping: rows) { row in
            "\(row.provider.rawValue)|\(row.modelIdentifier)"
        }
        .map { _, rows in
            UsageModelSummary(
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
}

private enum UsageCalendarFormatters {
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

    static let detailDayLabel: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
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
            startPoint: .leading,
            endPoint: .trailing
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
