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
            VStack(alignment: .leading, spacing: 20) {
                header

                Picker(lang.t("usage.period"), selection: $selectedPeriod) {
                    ForEach(UsageAggregationPeriod.allCases) { period in
                        Text(period.displayName(lang)).tag(period)
                    }
                }
                .pickerStyle(.segmented)

                todayProviderSection

                if let snapshot {
                    summaryGrid(for: snapshot)
                    bucketSection(for: snapshot)
                } else {
                    emptyState
                }
            }
            .padding(24)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
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
                .frame(width: 240)
            }

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 180), spacing: 12)
            ], alignment: .leading, spacing: 12) {
                ForEach(UsageLogProvider.allCases, id: \.self) { provider in
                    todayProviderCard(provider)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(lang.t("usage.title"))
                    .font(.system(size: 24, weight: .bold))

                Text(lang.t("usage.subtitle"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Label(lang.t("usage.sources"), systemImage: "folder")
                    if model.usageAnalyticsIsRefreshing {
                        Label(lang.t("usage.refreshing"), systemImage: "arrow.triangle.2.circlepath")
                    } else if let refreshedAt = model.usageAnalyticsLastRefreshedAt {
                        Label(
                            refreshedAt.formatted(date: .abbreviated, time: .shortened),
                            systemImage: "clock"
                        )
                    }
                    if let report = model.usageAnalyticsLastRefreshReport {
                        Label(
                            "\(report.ingestedFileCount) files · \(report.ingestedEntryCount) entries",
                            systemImage: "tray.and.arrow.down"
                        )
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button(lang.t("usage.refresh")) {
                model.refreshUsageAnalytics()
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.usageAnalyticsIsRefreshing)
        }
    }

    private func summaryGrid(for snapshot: UsageAnalyticsSnapshot) -> some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 160), spacing: 12)
        ], alignment: .leading, spacing: 12) {
            metricCard(
                title: lang.t("usage.inputTokens"),
                value: snapshot.totals.inputTokens.formatted(),
                accent: .cyan
            )
            metricCard(
                title: lang.t("usage.outputTokens"),
                value: snapshot.totals.outputTokens.formatted(),
                accent: .mint
            )
            metricCard(
                title: lang.t("usage.totalTokens"),
                value: snapshot.totals.totalTokens.formatted(),
                accent: .orange
            )
            metricCard(
                title: lang.t("usage.entries"),
                value: snapshot.totals.entryCount.formatted(),
                accent: .blue
            )
            metricCard(
                title: lang.t("usage.files"),
                value: snapshot.totals.sourceFileCount.formatted(),
                accent: .purple
            )
            metricCard(
                title: lang.t("usage.groups"),
                value: snapshot.buckets.count.formatted(),
                accent: .pink
            )
        }
    }

    private func bucketSection(for snapshot: UsageAnalyticsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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
                VStack(spacing: 10) {
                    ForEach(snapshot.buckets) { bucket in
                        bucketRow(bucket)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
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
                .fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }

    private func bucketRow(_ bucket: UsageAnalyticsBucket) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(bucket.label)
                    .font(.system(size: 14, weight: .semibold))

                if let detail = bucket.detail {
                    Text(detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(bucket.totalTokens.formatted())
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("\(bucket.inputTokens.formatted()) in · \(bucket.outputTokens.formatted()) out")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.03))
        )
    }

    private func metricCard(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(accent.opacity(0.18))
        )
    }

    private func todayProviderCard(_ provider: UsageLogProvider) -> some View {
        let totals = model.todayUsageProviderTotals.first { $0.provider == provider }
        let isShownOnIsland = model.shouldDisplayTodayTokenUsage(for: provider)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(provider.displayName)
                    .font(.system(size: 12, weight: .semibold))
                if isShownOnIsland {
                    Text(lang.t("usage.today.onIsland"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black.opacity(0.78))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(providerAccent(provider).opacity(0.9), in: Capsule())
                }
            }

            Text((totals?.totalTokens ?? 0).formatted())
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(providerAccent(provider))

            Text(lang.t(
                "usage.today.tokenBreakdown",
                (totals?.inputTokens ?? 0).formatted(),
                (totals?.outputTokens ?? 0).formatted()
            ))
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(isShownOnIsland ? 0.06 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(providerAccent(provider).opacity(isShownOnIsland ? 0.24 : 0.1))
        )
    }

    private func providerAccent(_ provider: UsageLogProvider) -> Color {
        switch provider {
        case .claude:
            .orange
        case .codex:
            .cyan
        }
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
