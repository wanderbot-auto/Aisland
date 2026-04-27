import AppKit
import SwiftUI
import AislandCore

struct UsageAnalyticsPane: View {
    var model: AppModel

    @State private var selectedPeriod: UsageAggregationPeriod = .day

    private var lang: LanguageManager { model.lang }
    private var snapshot: UsageAnalyticsSnapshot? { model.usageAnalyticsSnapshot(for: selectedPeriod) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                Picker(lang.t("usage.period"), selection: $selectedPeriod) {
                    ForEach(UsageAggregationPeriod.allCases) { period in
                        Text(period.displayName(lang)).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)

                todayProviderSection

                if let snapshot {
                    summaryGrid(for: snapshot)
                    bucketSection(for: snapshot)
                } else {
                    emptyState
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(lang.t("settings.tab.usage"))
        .onAppear {
            if snapshot == nil {
                model.refreshUsageAnalytics()
            }
        }
    }

    private var todayProviderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lang.t("usage.today.title"))
                        .font(.system(size: 15, weight: .semibold))
                    Text(lang.t("usage.today.subtitle"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Picker(lang.t("usage.today.islandDisplay"), selection: Binding(
                    get: { model.islandTokenUsageDisplayMode },
                    set: { model.islandTokenUsageDisplayMode = $0 }
                )) {
                    ForEach(IslandTokenUsageDisplayMode.allCases) { mode in
                        Text(mode.displayName(lang)).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 220), spacing: 8)
            ], alignment: .leading, spacing: 8) {
                ForEach(UsageLogProvider.allCases, id: \.self) { provider in
                    todayProviderCard(provider)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.10))
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(lang.t("usage.title"))
                    .font(.system(size: 20, weight: .semibold))

                Text(lang.t("usage.subtitle"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if model.usageAnalyticsIsRefreshing {
                    Label(lang.t("usage.refreshing"), systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else if let refreshedAt = model.usageAnalyticsLastRefreshedAt {
                    Label(
                        refreshedAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "clock"
                    )
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                }
                #if DEBUG
                if let report = model.usageAnalyticsLastRefreshReport {
                    HStack(spacing: 6) {
                        Label(
                            "\(report.ingestedFileCount) files · \(report.ingestedEntryCount) entries",
                            systemImage: "tray.and.arrow.down"
                        )
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                }
                #endif
            }

            Spacer(minLength: 12)

            Button(lang.t("usage.refresh")) {
                model.refreshUsageAnalytics()
            }
            .buttonStyle(.bordered)
            .disabled(model.usageAnalyticsIsRefreshing)
        }
    }

    private func summaryGrid(for snapshot: UsageAnalyticsSnapshot) -> some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 132), spacing: 8)
        ], alignment: .leading, spacing: 8) {
            metricCard(
                title: lang.t("usage.totalTokens"),
                value: snapshot.totals.totalTokens.formatted()
            )
            metricCard(
                title: lang.t("usage.inputTokens"),
                value: snapshot.totals.inputTokens.formatted()
            )
            metricCard(
                title: lang.t("usage.outputTokens"),
                value: snapshot.totals.outputTokens.formatted()
            )
            metricCard(
                title: lang.t("usage.entries"),
                value: snapshot.totals.entryCount.formatted()
            )
        }
    }

    private func bucketSection(for snapshot: UsageAnalyticsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(selectedPeriod.listTitle(lang))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if let error = model.usageAnalyticsLastRefreshError {
                    Text(error)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.red.opacity(0.8))
                }
            }

            if snapshot.buckets.isEmpty {
                emptyState
            } else {
                VStack(spacing: 6) {
                    ForEach(snapshot.buckets) { bucket in
                        bucketRow(bucket)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.10))
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lang.t("usage.empty.title"))
                .font(.system(size: 14, weight: .semibold))
            Text(lang.t("usage.empty.subtitle"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if model.usageAnalyticsIsRefreshing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button(lang.t("usage.refresh")) {
                    model.refreshUsageAnalytics()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.10))
        )
    }

    private func bucketRow(_ bucket: UsageAnalyticsBucket) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(bucket.label)
                    .font(.system(size: 13, weight: .semibold))

                if let detail = bucket.detail {
                    Text(detail)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(bucket.totalTokens.formatted())
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text("\(bucket.inputTokens.formatted()) in · \(bucket.outputTokens.formatted()) out")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.46))
        )
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.10))
        )
    }

    private func todayProviderCard(_ provider: UsageLogProvider) -> some View {
        let totals = model.todayUsageProviderTotals.first { $0.provider == provider }
        let isShownOnIsland = model.shouldDisplayTodayTokenUsage(for: provider)

        return HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 8) {
                Text(provider.displayName)
                    .font(.system(size: 12, weight: .semibold))
                if isShownOnIsland {
                    Text(lang.t("usage.today.onIsland"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.10), in: Capsule())
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text((totals?.totalTokens ?? 0).formatted())
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(lang.t(
                    "usage.today.tokenBreakdown",
                    (totals?.inputTokens ?? 0).formatted(),
                    (totals?.outputTokens ?? 0).formatted()
                ))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(isShownOnIsland ? 0.58 : 0.40))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isShownOnIsland ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.08))
        )
    }
}

private extension UsageAggregationPeriod {
    func displayName(_ lang: LanguageManager) -> String {
        switch self {
        case .day:
            lang.t("usage.period.day")
        case .month:
            lang.t("usage.period.month")
        case .session:
            lang.t("usage.period.session")
        }
    }

    func listTitle(_ lang: LanguageManager) -> String {
        switch self {
        case .day:
            lang.t("usage.list.day")
        case .month:
            lang.t("usage.list.month")
        case .session:
            lang.t("usage.list.session")
        }
    }
}

private extension IslandTokenUsageDisplayMode {
    func displayName(_ lang: LanguageManager) -> String {
        switch self {
        case .claude:
            lang.t("settings.display.tokenUsageDisplay.claude")
        case .codex:
            lang.t("settings.display.tokenUsageDisplay.codex")
        case .both:
            lang.t("settings.display.tokenUsageDisplay.both")
        }
    }
}
