import Foundation
import Observation
import AislandCore

@MainActor
@Observable
final class UsageAnalyticsCoordinator {
    private static let recentHourlyWindow = 7 * 24

    @ObservationIgnored
    private let store: UsageAnalyticsStore

    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?

    var snapshots: [UsageAggregationPeriod: UsageAnalyticsSnapshot] = [:]
    var todayProviderTotals: [UsageAnalyticsProviderTotals] = []
    var dailyModelUsage: [UsageAnalyticsDailyModelBucket] = []
    var hourlyModelUsage: [UsageAnalyticsHourlyModelBucket] = []
    var isRefreshing = false
    var lastRefreshError: String?
    var lastRefreshedAt: Date?
    var lastRefreshReport: UsageAnalyticsRefreshReport?

    init(store: UsageAnalyticsStore = UsageAnalyticsStore()) {
        self.store = store
    }

    func snapshot(for period: UsageAggregationPeriod) -> UsageAnalyticsSnapshot? {
        snapshots[period]
    }

    func refreshNow() {
        guard !isRefreshing else { return }

        isRefreshing = true
        Task { @MainActor [weak self] in
            guard let self else { return }

            defer { self.isRefreshing = false }

            do {
                let recentHourlyWindow = Self.recentHourlyWindow
                let (report, snapshots, todayProviderTotals, dailyModelUsage, hourlyModelUsage) = try await Task.detached(priority: .utility) { [store, recentHourlyWindow] in
                    let report = try store.refresh()
                    let snapshots = try store.snapshots()
                    let todayProviderTotals = try store.providerTotals()
                    let dailyModelUsage = try store.dailyModelUsage()
                    let hourlyModelUsage = try store.hourlyModelUsage(lastHours: recentHourlyWindow)
                    return (report, snapshots, todayProviderTotals, dailyModelUsage, hourlyModelUsage)
                }.value

                self.snapshots = snapshots
                self.todayProviderTotals = todayProviderTotals
                self.dailyModelUsage = dailyModelUsage
                self.hourlyModelUsage = hourlyModelUsage
                self.lastRefreshReport = report
                self.lastRefreshedAt = .now
                self.lastRefreshError = nil
            } catch {
                self.lastRefreshError = error.localizedDescription
            }
        }
    }

    func startMonitoringIfNeeded() {
        guard refreshTask == nil else { return }

        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                self.refreshNow()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }
}
