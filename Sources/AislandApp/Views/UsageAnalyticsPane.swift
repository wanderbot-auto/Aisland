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
    private var heatmapDateBucketDaySpan: Int {
        let targetColumnCount = 14
        return max(1, Int(ceil(Double(selectedDayCount) / Double(targetColumnCount))))
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
            bucketDaySpan: heatmapDateBucketDaySpan
        )
    }
    private var heatmapDays: [UsageHeatmapDay] {
        completeHeatmapDays
    }
    private var heatmapCells: [UsageHeatmapHourCell] { heatmapDays.flatMap(\.cells) }
    private var heatmapColumnCount: Int { heatmapDays.count }

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

    var body: some View {
        Form {
            Section {
                if hourlyUsage.isEmpty {
                    emptyState
                } else {
                    HeatmapSummaryStrip(
                        totalTokens: totalTokens,
                        totalCostUSD: totalCostUSD,
                        activeHourCount: activeHourCount,
                        dateColumnCount: heatmapColumnCount,
                        peakCell: peakCell,
                        rangeLabel: rangeLabel,
                        lang: lang,
                        theme: theme
                    )

                    rangeControl

                    HourlyUsageHeatmap(
                        days: heatmapDays,
                        theme: theme,
                        lang: lang,
                        legend: lang.t("usage.heatmap.legend"),
                        lessLabel: lang.t("usage.heatmap.less"),
                        moreLabel: lang.t("usage.heatmap.more")
                    )
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

private struct HeatmapSummaryStrip: View {
    var totalTokens: Int
    var totalCostUSD: Double
    var activeHourCount: Int
    var dateColumnCount: Int
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
                detail: peakCell?.shortLabel ?? lang.t("usage.surface.noRecent")
            )
            metricCard(
                title: lang.t("usage.heatmap.activeHours"),
                value: "\(activeHourCount)",
                detail: "\(dateColumnCount) x 24"
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
    var theme: IslandThemePalette
    var lang: LanguageManager
    var legend: String
    var lessLabel: String
    var moreLabel: String

    @State private var hoveredCell: UsageHeatmapHourCell?

    private var maxTokens: Int {
        max(days.flatMap(\.cells).map(\.totalTokens).max() ?? 1, 1)
    }

    private var hourValues: [Int] {
        days.first?.cells.map(\.hourOfDay) ?? Array(0..<24)
    }

    var body: some View {
        GeometryReader { proxy in
            let labelWidth: CGFloat = 42
            let headerHeight: CGFloat = 38
            let legendHeight: CGFloat = 24
            let gridPadding: CGFloat = 12
            let cellSpacing: CGFloat = 3
            let columnCount = max(days.count, 1)
            let rowCount = max(hourValues.count, 1)
            let gridWidth = max(1, proxy.size.width - labelWidth - gridPadding * 2)
            let gridHeight = max(1, proxy.size.height - headerHeight - legendHeight - gridPadding * 2 - 14)
            let cellWidth = max(6, (gridWidth - CGFloat(max(0, columnCount - 1)) * cellSpacing) / CGFloat(columnCount))
            let cellHeight = max(6, (gridHeight - CGFloat(max(0, rowCount - 1)) * cellSpacing) / CGFloat(rowCount))

            VStack(alignment: .leading, spacing: 12) {
                dateHeader(labelWidth: labelWidth, cellWidth: cellWidth, spacing: cellSpacing)

                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: cellSpacing) {
                        ForEach(Array(hourValues.enumerated()), id: \.element) { _, hour in
                            HStack(spacing: cellSpacing) {
                                Text(String(format: "%02d", hour))
                                    .font(IslandTheme.labelFont(size: 8.5))
                                    .foregroundStyle(theme.textSecondary.opacity(shouldEmphasizeHourLabel(hour) ? 0.72 : 0.38))
                                    .frame(width: labelWidth, alignment: .trailing)

                                ForEach(days) { day in
                                    if let cell = day.cell(atHour: hour) {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(fill(for: cell))
                                            .frame(width: cellWidth, height: cellHeight)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                    .strokeBorder(stroke(for: cell), lineWidth: hoveredCell?.id == cell.id ? 1.4 : 0.7)
                                            )
                                            .shadow(color: glow(for: cell), radius: cell.hasUsage ? 5 : 0, x: 0, y: 0)
                                            .contentShape(Rectangle())
                                            .help(cell.helpText)
                                            .onHover { isHovering in
                                                hoveredCell = isHovering ? cell : (hoveredCell?.id == cell.id ? nil : hoveredCell)
                                            }
                                    }
                                }
                            }
                        }
                    }
                    .padding(gridPadding)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(theme.surfaceContainer.opacity(0.34))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(theme.outline.opacity(0.08))
                    )

                    if let hoveredCell,
                       let tooltipPosition = tooltipPosition(
                        for: hoveredCell,
                        in: proxy.size,
                        labelWidth: labelWidth,
                        gridPadding: gridPadding,
                        cellWidth: cellWidth,
                        cellHeight: cellHeight,
                        spacing: cellSpacing
                       ) {
                        UsageHeatmapHoverDetail(
                            cell: hoveredCell,
                            lang: lang,
                            theme: theme
                        )
                        .frame(width: 218, alignment: .topLeading)
                        .position(tooltipPosition)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .allowsHitTesting(false)
                    }
                }

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
        .frame(height: 430)
    }

    private func dateHeader(labelWidth: CGFloat, cellWidth: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            Color.clear.frame(width: labelWidth, height: 1)
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                VStack(spacing: 1) {
                    Text(shouldShowDateLabel(at: index) ? day.shortLabel : "")
                        .font(IslandTheme.labelFont(size: 9.5))
                        .foregroundStyle(theme.textSecondary.opacity(day.includesToday ? 0.9 : 0.58))
                    Text(shouldShowDateLabel(at: index) ? day.dateLabel : "")
                        .font(IslandTheme.labelFont(size: 8))
                        .foregroundStyle(theme.textTertiary.opacity(day.includesToday ? 0.82 : 0.48))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(width: cellWidth)
            }
        }
        .frame(height: 38, alignment: .bottom)
    }

    private func shouldShowDateLabel(at index: Int) -> Bool {
        let count = days.count
        guard count > 0 else { return false }
        let cadence = max(1, Int(ceil(Double(count) / 7.0)))
        return index == 0 || index == count - 1 || index % cadence == 0
    }

    private func shouldEmphasizeHourLabel(_ hour: Int) -> Bool {
        hour == hourValues.first || hour == hourValues.last || hour % 3 == 0
    }

    private func tooltipPosition(
        for cell: UsageHeatmapHourCell,
        in size: CGSize,
        labelWidth: CGFloat,
        gridPadding: CGFloat,
        cellWidth: CGFloat,
        cellHeight: CGFloat,
        spacing: CGFloat
    ) -> CGPoint? {
        guard let columnIndex = days.firstIndex(where: { $0.id == cell.dateBucketStartAt.timeIntervalSince1970 }),
              let rowIndex = hourValues.firstIndex(of: cell.hourOfDay) else {
            return nil
        }

        let tooltipWidth: CGFloat = 218
        let tooltipHeight: CGFloat = 132
        let cellCenterX = labelWidth + gridPadding + CGFloat(columnIndex) * (cellWidth + spacing) + cellWidth / 2
        let cellCenterY = 38 + gridPadding + CGFloat(rowIndex) * (cellHeight + spacing) + cellHeight / 2
        let prefersRightSide = cellCenterX + tooltipWidth + 18 < size.width
        let rawX = prefersRightSide
            ? cellCenterX + tooltipWidth / 2 + 14
            : cellCenterX - tooltipWidth / 2 - 14
        let minX = tooltipWidth / 2 + 6
        let maxX = max(minX, size.width - tooltipWidth / 2 - 6)
        let minY = 38 + tooltipHeight / 2
        let maxY = max(minY, size.height - 28 - tooltipHeight / 2)

        return CGPoint(
            x: min(max(rawX, minX), maxX),
            y: min(max(cellCenterY, minY), maxY)
        )
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
        if hoveredCell?.id == cell.id {
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

private struct UsageHeatmapHoverDetail: View {
    var cell: UsageHeatmapHourCell
    var lang: LanguageManager
    var theme: IslandThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(cell.detailLabel)
                    .font(IslandTheme.bodyFont(size: 12.5, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .lineLimit(2)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(cell.totalTokens.abbreviatedTokenString)
                        .font(IslandTheme.bodyFont(size: 14, weight: .black))
                        .foregroundStyle(theme.text)
                        .monospacedDigit()
                    Text(cell.costUSD.currencyString)
                        .font(IslandTheme.labelFont(size: 10))
                        .foregroundStyle(theme.textSecondary)
                }
            }

            if cell.rows.isEmpty {
                Text(lang.t("usage.heatmap.noHour"))
                    .font(IslandTheme.bodyFont(size: 11, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(cell.rows.prefix(3)) { row in
                        HStack(spacing: 7) {
                            Circle()
                                .fill(UsageModelColor.color(for: row.modelIdentifier, theme: theme))
                                .frame(width: 7, height: 7)
                            Text(row.modelDisplayName)
                                .font(IslandTheme.bodyFont(size: 11, weight: .semibold))
                                .foregroundStyle(theme.text)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text(row.totalTokens.abbreviatedTokenString)
                                .font(IslandTheme.bodyFont(size: 11, weight: .bold))
                                .foregroundStyle(theme.textSecondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.surfaceBright.opacity(0.96))
                .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.outline.opacity(0.14))
        )
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
    var dayEndAt: Date
    var cells: [UsageHeatmapHourCell]

    var id: TimeInterval { dayStartAt.timeIntervalSince1970 }
    var includesToday: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return dayStartAt <= today && today < dayEndAt
    }

    var shortLabel: String {
        if isSingleDay {
            return UsageHeatmapFormatters.weekdayLabel.string(from: dayStartAt)
        }
        return "\(calendarDaySpan)d"
    }

    var dateLabel: String {
        UsageHeatmapFormatters.dateRangeLabel(start: dayStartAt, end: dayEndAt)
    }

    private var isSingleDay: Bool { calendarDaySpan <= 1 }

    private var calendarDaySpan: Int {
        max(1, Calendar.current.dateComponents([.day], from: dayStartAt, to: dayEndAt).day ?? 1)
    }

    func cell(atHour hour: Int) -> UsageHeatmapHourCell? {
        cells.first { $0.hourOfDay == hour }
    }

    static func completeRecentDays(
        from rows: [UsageAnalyticsHourlyModelBucket],
        dayCount: Int,
        bucketDaySpan: Int
    ) -> [UsageHeatmapDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let currentHour = calendar.dateInterval(of: .hour, for: .now)?.start ?? .now
        let clampedDayCount = max(1, dayCount)
        let clampedBucketDaySpan = max(1, bucketDaySpan)
        let grouped = Dictionary(grouping: rows) { row in
            calendar.dateInterval(of: .hour, for: row.hourStartAt)?.start ?? row.hourStartAt
        }
        let allDays = (0..<clampedDayCount).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset - clampedDayCount + 1, to: today)
        }

        return stride(from: 0, to: allDays.count, by: clampedBucketDaySpan).compactMap { bucketStartIndex in
            let bucketEndIndex = min(allDays.count, bucketStartIndex + clampedBucketDaySpan)
            let bucketDays = Array(allDays[bucketStartIndex..<bucketEndIndex])
            guard let bucketStartDay = bucketDays.first,
                  let lastDay = bucketDays.last,
                  let bucketEndDay = calendar.date(byAdding: .day, value: 1, to: lastDay) else {
                return nil
            }

            let cells = (0..<24).compactMap { hourOffset -> UsageHeatmapHourCell? in
                guard let representativeHourStart = calendar.date(byAdding: .hour, value: hourOffset, to: bucketStartDay),
                      let representativeHourEnd = calendar.date(byAdding: .hour, value: 1, to: representativeHourStart) else {
                    return nil
                }
                let bucketRows = bucketDays
                    .compactMap { calendar.date(byAdding: .hour, value: hourOffset, to: $0) }
                    .flatMap { grouped[$0] ?? [] }
                    .sorted { lhs, rhs in
                        if lhs.totalTokens == rhs.totalTokens { return lhs.modelDisplayName < rhs.modelDisplayName }
                        return lhs.totalTokens > rhs.totalTokens
                    }
                return UsageHeatmapHourCell(
                    dateBucketStartAt: bucketStartDay,
                    dateBucketEndAt: bucketEndDay,
                    representativeHourStartAt: representativeHourStart,
                    representativeHourEndAt: representativeHourEnd,
                    rows: bucketRows,
                    isCurrentHour: bucketDays.contains { day in
                        guard let hourStart = calendar.date(byAdding: .hour, value: hourOffset, to: day),
                              let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) else {
                            return false
                        }
                        return hourStart <= currentHour && currentHour < hourEnd
                    }
                )
            }

            return UsageHeatmapDay(dayStartAt: bucketStartDay, dayEndAt: bucketEndDay, cells: cells)
        }
    }
}

private struct UsageHeatmapHourCell: Identifiable {
    var dateBucketStartAt: Date
    var dateBucketEndAt: Date
    var representativeHourStartAt: Date
    var representativeHourEndAt: Date
    var rows: [UsageAnalyticsHourlyModelBucket]
    var isCurrentHour: Bool

    var id: TimeInterval { representativeHourStartAt.timeIntervalSince1970 }
    var totalTokens: Int { rows.reduce(0) { $0 + $1.totalTokens } }
    var inputTokens: Int { rows.reduce(0) { $0 + $1.inputTokens } }
    var outputTokens: Int { rows.reduce(0) { $0 + $1.outputTokens } }
    var costUSD: Double { rows.reduce(0) { $0 + $1.costUSD } }
    var hasUsage: Bool { totalTokens > 0 || costUSD > 0 }
    var isFuture: Bool { representativeHourStartAt > .now }
    var hourOfDay: Int { Calendar.current.component(.hour, from: representativeHourStartAt) }
    var shortLabel: String {
        UsageHeatmapFormatters.shortBucketLabel(dateStart: dateBucketStartAt, dateEnd: dateBucketEndAt, hourStart: representativeHourStartAt, hourEnd: representativeHourEndAt)
    }
    var detailLabel: String {
        UsageHeatmapFormatters.bucketLabel(dateStart: dateBucketStartAt, dateEnd: dateBucketEndAt, hourStart: representativeHourStartAt, hourEnd: representativeHourEndAt)
    }

    var helpText: String {
        let modelText = rows.prefix(4)
            .map { "\($0.modelDisplayName): \($0.totalTokens.abbreviatedTokenString), \($0.costUSD.currencyString)" }
            .joined(separator: "\n")
        let suffix = modelText.isEmpty ? "" : "\n\(modelText)"
        return "\(detailLabel)\n\(totalTokens.abbreviatedTokenString) · \(costUSD.currencyString)\(suffix)"
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

    static func dateRangeLabel(start: Date, end: Date) -> String {
        let adjustedEnd = end.addingTimeInterval(-1)
        if Calendar.current.isDate(start, inSameDayAs: adjustedEnd) {
            return dayLabel.string(from: start)
        }
        return "\(dayLabel.string(from: start))-\(dayLabel.string(from: adjustedEnd))"
    }

    static func shortBucketLabel(dateStart: Date, dateEnd: Date, hourStart: Date, hourEnd: Date) -> String {
        "\(dateRangeLabel(start: dateStart, end: dateEnd)) \(timeRangeLabel(start: hourStart, end: hourEnd))"
    }

    static func bucketLabel(dateStart: Date, dateEnd: Date, hourStart: Date, hourEnd: Date) -> String {
        "\(dateRangeLabel(start: dateStart, end: dateEnd)) · \(timeRangeLabel(start: hourStart, end: hourEnd))"
    }

    private static func timeRangeLabel(start: Date, end: Date) -> String {
        "\(hourOnlyLabel.string(from: start)):00-\(hourOnlyLabel.string(from: end)):00"
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
