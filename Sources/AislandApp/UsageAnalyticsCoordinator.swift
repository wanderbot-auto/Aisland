import Foundation
import Observation
import AislandCore

@MainActor
@Observable
final class UsageAnalyticsCoordinator {
    @ObservationIgnored
    private let store: UsageAnalyticsStore

    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?

    var snapshots: [UsageAggregationPeriod: UsageAnalyticsSnapshot] = [:]
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
                let (report, snapshots) = try await Task.detached(priority: .utility) { [store] in
                    let report = try store.refresh()
                    let snapshots = try store.snapshots()
                    return (report, snapshots)
                }.value

                self.snapshots = snapshots
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
