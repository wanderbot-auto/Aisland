import Foundation
import Testing
@testable import AislandCore

struct UsageAnalyticsTests {
    @Test
    func usageAnalyticsStoreIngestsClaudeAndCodexJsonlLogs() throws {
        let rootURL = temporaryRootURL(named: "usage-analytics")
        let claudeRoot = rootURL.appendingPathComponent(".claude", isDirectory: true)
        let codexRoot = rootURL.appendingPathComponent(".codex", isDirectory: true)
        let claudeLogURL = claudeRoot
            .appendingPathComponent("projects/demo", isDirectory: true)
            .appendingPathComponent("session.jsonl")
        let codexLogURL = codexRoot
            .appendingPathComponent("sessions/demo", isDirectory: true)
            .appendingPathComponent("rollout.jsonl")
        let databaseURL = rootURL.appendingPathComponent("usage.sqlite")
        let store = UsageAnalyticsStore(
            databaseURL: databaseURL,
            roots: [
                UsageAnalyticsRoot(provider: .claude, rootURL: claudeRoot),
                UsageAnalyticsRoot(provider: .codex, rootURL: codexRoot),
            ]
        )

        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        try writeLines(
            [
                usageLine(
                    timestamp: "2026-04-03T10:15:00Z",
                    payload: [
                        "session_id": "claude-session-1",
                        "type": "message",
                        "request": [
                            "usage": [
                                "input_tokens": 120,
                            ],
                        ],
                        "response": [
                            "usage": [
                                "output_tokens": 45,
                            ],
                        ],
                    ]
                ),
                usageLine(
                    timestamp: "2026-04-03T11:45:00Z",
                    payload: [
                        "session_id": "claude-session-1",
                        "type": "message",
                        "usage": [
                            "input_tokens": "80",
                            "output_tokens": "20",
                        ],
                    ]
                ),
            ],
            to: claudeLogURL
        )

        try writeLines(
            [
                usageLine(
                    timestamp: "2026-04-04T09:00:00Z",
                    payload: [
                        "sessionId": "codex-session-1",
                        "event": [
                            "usage": [
                                "input_tokens": 200,
                                "output_tokens": 70,
                            ],
                        ],
                    ]
                ),
            ],
            to: codexLogURL
        )

        try setModificationDate(Date(timeIntervalSince1970: 2_000), for: claudeLogURL)
        try setModificationDate(Date(timeIntervalSince1970: 3_000), for: codexLogURL)

        let report = try store.refresh()
        let daySnapshot = try store.snapshot(for: .day)
        let monthSnapshot = try store.snapshot(for: .month)
        let sessionSnapshot = try store.snapshot(for: .session)

        #expect(report.scannedFileCount == 2)
        #expect(report.ingestedFileCount == 2)
        #expect(report.ingestedEntryCount == 3)
        #expect(daySnapshot.totals.inputTokens == 400)
        #expect(daySnapshot.totals.outputTokens == 135)
        #expect(daySnapshot.totals.totalTokens == 535)
        #expect(daySnapshot.totals.entryCount == 3)
        #expect(daySnapshot.totals.sourceFileCount == 2)
        #expect(daySnapshot.buckets.count == 2)
        #expect(daySnapshot.buckets.map(\.key) == ["2026-04-04", "2026-04-03"])
        #expect(monthSnapshot.buckets.count == 1)
        #expect(monthSnapshot.buckets.first?.key == "2026-04")
        #expect(sessionSnapshot.buckets.count == 2)
        #expect(sessionSnapshot.buckets.contains(where: { $0.key == "claude-session-1" && $0.totalTokens == 265 }))
        #expect(sessionSnapshot.buckets.contains(where: { $0.key == "codex-session-1" && $0.totalTokens == 270 }))
        #expect(sessionSnapshot.totals.totalTokens == 535)
    }

    @Test
    func usageAnalyticsStoreSkipsUnchangedFilesOnRefresh() throws {
        let rootURL = temporaryRootURL(named: "usage-analytics-skip")
        let claudeRoot = rootURL.appendingPathComponent(".claude", isDirectory: true)
        let claudeLogURL = claudeRoot
            .appendingPathComponent("projects/demo", isDirectory: true)
            .appendingPathComponent("session.jsonl")
        let databaseURL = rootURL.appendingPathComponent("usage.sqlite")
        let store = UsageAnalyticsStore(
            databaseURL: databaseURL,
            roots: [UsageAnalyticsRoot(provider: .claude, rootURL: claudeRoot)]
        )

        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        try writeLines(
            [
                usageLine(
                    timestamp: "2026-04-03T10:15:00Z",
                    payload: [
                        "session_id": "claude-session-1",
                        "usage": [
                            "input_tokens": 12,
                            "output_tokens": 8,
                        ],
                    ]
                ),
            ],
            to: claudeLogURL
        )

        try setModificationDate(Date(timeIntervalSince1970: 2_000), for: claudeLogURL)

        try store.refresh()
        let firstSnapshot = try store.snapshot(for: .session)
        try store.refresh()
        let secondSnapshot = try store.snapshot(for: .session)

        #expect(firstSnapshot.totals.totalTokens == 20)
        #expect(secondSnapshot.totals.totalTokens == 20)
        #expect(secondSnapshot.buckets.count == 1)
    }
}

private func temporaryRootURL(named name: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("aisland-\(name)-\(UUID().uuidString)", isDirectory: true)
}

private func writeLines(_ lines: [String], to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try lines.joined(separator: "\n").appending("\n").write(to: url, atomically: true, encoding: .utf8)
}

private func setModificationDate(_ date: Date, for url: URL) throws {
    try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
}

private func usageLine(timestamp: String, payload: [String: Any]) -> String {
    let object: [String: Any] = [
        "timestamp": timestamp,
        "payload": payload,
    ]
    let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    return String(decoding: data, as: UTF8.self)
}
