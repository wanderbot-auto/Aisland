import AppKit
import SwiftUI
import AislandCore

struct UsageAnalyticsPane: View {
    var model: AppModel

    @Environment(\.islandTheme) private var theme
    @State private var selectedContributionDate: String?

    private var lang: LanguageManager { model.lang }
    private var dailyUsage: [UsageAnalyticsDailyModelBucket] { model.usageAnalyticsDailyModelUsage }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                usageToolbar
                contributionGraphSection
                tokensPerDaySection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .islandSettingsPaneBackground()
        .navigationTitle(lang.t("settings.tab.usage"))
        .onAppear {
            if dailyUsage.isEmpty {
                model.refreshUsageAnalytics()
            }
        }
        .onChange(of: dailyUsage) { _, newValue in
            if selectedContributionDate == nil {
                selectedContributionDate = newValue.last?.dateKey
            }
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

    private var tokensPerDaySection: some View {
        usagePanel {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeading(
                    title: lang.t("usage.chart.tokensPerDay"),
                    subtitle: lang.t("usage.chart.tokensPerDay.subtitle")
                )

                if dailyUsage.isEmpty {
                    emptyState
                } else {
                    DailyStackedTokenChart(rows: dailyUsage, theme: theme)
                        .frame(minHeight: 280)
                    ModelLegend(rows: dailyUsage, theme: theme)
                }
            }
        }
    }

    private var contributionGraphSection: some View {
        usagePanel {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeading(
                    title: lang.t("usage.chart.contributionGraph"),
                    subtitle: lang.t("usage.chart.contributionGraph.subtitle")
                )

                if dailyUsage.isEmpty {
                    emptyState
                } else {
                    ContributionGraph(
                        rows: dailyUsage,
                        selectedDate: $selectedContributionDate,
                        theme: theme
                    )

                    if let day = selectedContributionDay {
                        ContributionDetail(day: day, theme: theme)
                    }
                }
            }
        }
    }

    private var selectedContributionDay: UsageDaySummary? {
        let days = UsageDaySummary.makeDays(from: dailyUsage)
        guard let selectedContributionDate else {
            return days.last
        }
        return days.first { $0.dateKey == selectedContributionDate } ?? days.last
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

private struct DailyStackedTokenChart: View {
    var rows: [UsageAnalyticsDailyModelBucket]
    var theme: IslandThemePalette

    private var days: [UsageDaySummary] { UsageDaySummary.makeDays(from: rows).suffixArray(30) }
    private var maxTokens: Int { max(days.map(\.totalTokens).max() ?? 1, 1) }

    var body: some View {
        GeometryReader { proxy in
            let chartHeight = max(160, proxy.size.height - 72)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days) { day in
                    VStack(spacing: 7) {
                        Text(day.costUSD.currencyString)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)

                        VStack(spacing: 1) {
                            Spacer(minLength: 0)
                            ForEach(day.modelRows.reversed()) { row in
                                Rectangle()
                                    .fill(UsageModelColor.chartGradient(for: row.modelIdentifier, theme: theme))
                                    .frame(height: segmentHeight(row.totalTokens, chartHeight: chartHeight))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: chartHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(theme.surfaceContainer.opacity(0.34))
                        )
                        .help(day.helpText)

                        Text(day.shortLabel)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func segmentHeight(_ tokens: Int, chartHeight: CGFloat) -> CGFloat {
        guard tokens > 0 else { return 0 }
        return max(2, chartHeight * CGFloat(tokens) / CGFloat(maxTokens))
    }
}

private struct ContributionGraph: View {
    var rows: [UsageAnalyticsDailyModelBucket]
    @Binding var selectedDate: String?
    var theme: IslandThemePalette

    private var maxCost: Double { max(rows.map(\.costUSD).max() ?? 0, 0.01) }

    var body: some View {
        GeometryReader { proxy in
            let layout = layout(for: proxy.size.width)
            let days = UsageDaySummary.makeCompleteDays(from: rows, trailingDayCount: layout.weekCount * 7)
            let weeks = days.chunked(into: 7)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: layout.weekSpacing) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: layout.daySpacing) {
                            ForEach(week) { day in
                                RoundedRectangle(cornerRadius: layout.cellSize * 0.26, style: .continuous)
                                    .fill(fillColor(for: day))
                                    .frame(width: layout.cellSize, height: layout.cellSize)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: layout.cellSize * 0.26, style: .continuous)
                                            .strokeBorder(selectedDate == day.dateKey ? theme.text.opacity(0.72) : Color.clear, lineWidth: 1.5)
                                    )
                                    .help(day.helpText)
                                    .onTapGesture { selectedDate = day.dateKey }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Text("Less")
                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(intensityColor(Double(index) / 4))
                            .frame(width: 12, height: 12)
                    }
                    Text("More")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 170)
    }

    private struct GraphLayout {
        var weekCount: Int
        var cellSize: CGFloat
        var weekSpacing: CGFloat
        var daySpacing: CGFloat
    }

    private func layout(for width: CGFloat) -> GraphLayout {
        let weekCount = min(52, max(12, Int((width + 5) / 18)))
        let baseWeekSpacing: CGFloat = 5
        let availableForCells = max(0, width - baseWeekSpacing * CGFloat(weekCount - 1))
        let cellSize = min(18, max(9, availableForCells / CGFloat(weekCount)))
        let weekSpacing = weekCount > 1
            ? max(4, (width - cellSize * CGFloat(weekCount)) / CGFloat(weekCount - 1))
            : 0
        return GraphLayout(
            weekCount: weekCount,
            cellSize: cellSize,
            weekSpacing: weekSpacing,
            daySpacing: min(5, max(3, cellSize * 0.34))
        )
    }

    private func fillColor(for day: UsageDaySummary) -> Color {
        guard day.totalTokens > 0 || day.costUSD > 0 else {
            return theme.surfaceContainer.opacity(0.42)
        }
        return intensityColor(min(1, day.costUSD / maxCost))
    }

    private func intensityColor(_ value: Double) -> Color {
        let clamped = min(max(value, 0), 1)
        return theme.primary.opacity(0.18 + (0.72 * clamped))
    }
}

private struct ContributionDetail: View {
    var day: UsageDaySummary
    var theme: IslandThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(day.longLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Text("\(day.totalTokens.abbreviatedTokenString) · \(day.costUSD.currencyString)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.text)
            }

            VStack(spacing: 7) {
                ForEach(day.modelRows) { row in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(UsageModelColor.color(for: row.modelIdentifier, theme: theme))
                            .frame(width: 8, height: 8)
                        Text(row.modelDisplayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                        Spacer(minLength: 10)
                        Text(row.totalTokens.abbreviatedTokenString)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.text)
                        Text(row.costUSD.currencyString)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }
        .padding(13)
        .background(theme.surfaceContainer.opacity(0.48), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ModelLegend: View {
    var rows: [UsageAnalyticsDailyModelBucket]
    var theme: IslandThemePalette

    private var models: [UsageModelSummary] {
        Dictionary(grouping: rows, by: \.modelIdentifier)
            .map { modelIdentifier, rows in
                UsageModelSummary(
                    modelIdentifier: modelIdentifier,
                    modelDisplayName: rows.first?.modelDisplayName ?? modelIdentifier,
                    totalTokens: rows.reduce(0) { $0 + $1.totalTokens },
                    costUSD: rows.reduce(0) { $0 + $1.costUSD }
                )
            }
            .sorted { lhs, rhs in
                if lhs.totalTokens == rhs.totalTokens { return lhs.modelDisplayName < rhs.modelDisplayName }
                return lhs.totalTokens > rhs.totalTokens
            }
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(models) { model in
                HStack(spacing: 8) {
                    Circle()
                        .fill(UsageModelColor.color(for: model.modelIdentifier, theme: theme))
                        .frame(width: 9, height: 9)
                    Text(model.modelDisplayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(model.costUSD.currencyString)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(theme.surfaceContainer.opacity(0.48), in: Capsule())
            }
        }
    }
}

private struct UsageDaySummary: Identifiable, Equatable {
    var dateKey: String
    var modelRows: [UsageAnalyticsDailyModelBucket]

    var id: String { dateKey }
    var totalTokens: Int { modelRows.reduce(0) { $0 + $1.totalTokens } }
    var costUSD: Double { modelRows.reduce(0) { $0 + $1.costUSD } }

    var shortLabel: String {
        guard let date else { return dateKey }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter.string(from: date)
    }

    var longLabel: String {
        guard let date else { return dateKey }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    var helpText: String {
        let modelText = modelRows.prefix(4)
            .map { "\($0.modelDisplayName): \($0.totalTokens.abbreviatedTokenString), \($0.costUSD.currencyString)" }
            .joined(separator: "\n")
        return "\(longLabel)\n\(totalTokens.abbreviatedTokenString) · \(costUSD.currencyString)\n\(modelText)"
    }

    private var date: Date? {
        Self.dateFormatter.date(from: dateKey)
    }

    static func makeDays(from rows: [UsageAnalyticsDailyModelBucket]) -> [UsageDaySummary] {
        Dictionary(grouping: rows, by: \.dateKey)
            .map { dateKey, rows in
                UsageDaySummary(
                    dateKey: dateKey,
                    modelRows: rows.sorted { lhs, rhs in
                        if lhs.totalTokens == rhs.totalTokens { return lhs.modelDisplayName < rhs.modelDisplayName }
                        return lhs.totalTokens > rhs.totalTokens
                    }
                )
            }
            .sorted { $0.dateKey < $1.dateKey }
    }

    static func makeCompleteDays(from rows: [UsageAnalyticsDailyModelBucket], trailingDayCount: Int) -> [UsageDaySummary] {
        let grouped = Dictionary(grouping: rows, by: \.dateKey)
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: .now)
        let count = max(7, trailingDayCount)
        return (0..<count).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - count + 1, to: end) else {
                return nil
            }
            let key = dateFormatter.string(from: date)
            return UsageDaySummary(dateKey: key, modelRows: grouped[key] ?? [])
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct UsageModelSummary: Identifiable {
    var modelIdentifier: String
    var modelDisplayName: String
    var totalTokens: Int
    var costUSD: Double

    var id: String { modelIdentifier }
}

private enum UsageModelColor {
    static func color(for modelIdentifier: String, theme: IslandThemePalette) -> Color {
        let palette: [Color] = [
            theme.primary,
            blended(theme.primary, with: theme.warning, amount: 0.36),
            theme.secondary,
            blended(theme.secondary, with: theme.success, amount: 0.32),
            theme.tertiary,
            blended(theme.tertiary, with: theme.primary, amount: 0.34),
            theme.success,
            blended(theme.success, with: theme.primary, amount: 0.28),
            theme.warning,
            blended(theme.warning, with: theme.error, amount: 0.25),
            theme.error,
            blended(theme.primaryContainer, with: theme.text, amount: 0.18),
            blended(theme.cardSelected, with: theme.primary, amount: 0.30),
        ]
        let hash = abs(modelIdentifier.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) })
        return palette[hash % palette.count]
    }

    static func chartGradient(for modelIdentifier: String, theme: IslandThemePalette) -> LinearGradient {
        let base = color(for: modelIdentifier, theme: theme)
        return LinearGradient(
            colors: [
                blended(base, with: theme.surfaceBright, amount: 0.24),
                base,
                blended(base, with: theme.text, amount: 0.10),
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

private extension Array {
    func suffixArray(_ maxLength: Int) -> [Element] {
        Array(suffix(maxLength))
    }

    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { index in
            Array(self[index..<Swift.min(index + size, count)])
        }
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
