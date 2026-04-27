import Foundation
import Testing
@testable import AislandCore

struct UsageAnalyticsTests {
    @Test
    func usageAnalyticsStoreIngestsClaudeAndCodexJsonlLogs() throws {
        let rootURL = temporaryRootURL(named: "usage-analytics")
        let claudeRoot = rootURL.appendingPathComponent(".claude", isDirectory: true)
        let codexRoot = rootURL.appendingPathComponent(".codex", isDirectory: true)
        let openCodeRoot = rootURL.appendingPathComponent(".local/share/opencode/storage", isDirectory: true)
        let claudeLogURL = claudeRoot
            .appendingPathComponent("projects/demo", isDirectory: true)
            .appendingPathComponent("session.jsonl")
        let codexLogURL = codexRoot
            .appendingPathComponent("sessions/demo", isDirectory: true)
            .appendingPathComponent("rollout.jsonl")
        let openCodeLogURL = openCodeRoot
            .appendingPathComponent("message/session-a", isDirectory: true)
            .appendingPathComponent("message-a.json")
        let databaseURL = rootURL.appendingPathComponent("usage.sqlite")
        let store = UsageAnalyticsStore(
            databaseURL: databaseURL,
            roots: [
                UsageAnalyticsRoot(provider: .claude, rootURL: claudeRoot),
                UsageAnalyticsRoot(provider: .codex, rootURL: codexRoot),
                UsageAnalyticsRoot(provider: .openCode, rootURL: openCodeRoot),
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
                        "id": "codex-session-1",
                        "model": "gpt-5.3-codex",
                        "model_provider": "openai",
                        "type": "token_count",
                        "info": [
                            "last_token_usage": [
                                "input_tokens": 200,
                                "cached_input_tokens": 30,
                                "output_tokens": 70,
                                "reasoning_output_tokens": 10,
                            ],
                        ],
                    ]
                ),
                usageLine(
                    timestamp: "2026-04-04T09:10:00Z",
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

        try writeJSON(
            [
                "id": "msg-open-code-1",
                "sessionID": "opencode-session-1",
                "role": "assistant",
                "time": ["created": 1_775_299_200_000],
                "modelID": "glm-4.7",
                "providerID": "zai-coding-plan",
                "cost": 0.42,
                "tokens": [
                    "input": 500,
                    "output": 120,
                    "reasoning": 20,
                    "cache": [
                        "read": 300,
                        "write": 40,
                    ],
                ],
            ],
            to: openCodeLogURL
        )

        try setModificationDate(Date(timeIntervalSince1970: 2_000), for: claudeLogURL)
        try setModificationDate(Date(timeIntervalSince1970: 3_000), for: codexLogURL)
        try setModificationDate(Date(timeIntervalSince1970: 4_000), for: openCodeLogURL)

        let report = try store.refresh()
        let daySnapshot = try store.snapshot(for: .day)
        let monthSnapshot = try store.snapshot(for: .month)
        let sessionSnapshot = try store.snapshot(for: .session)
        let dailyModelUsage = try store.dailyModelUsage()
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let aprilThird = ISO8601DateFormatter().date(from: "2026-04-03T12:00:00Z")!
        let aprilFourth = ISO8601DateFormatter().date(from: "2026-04-04T12:00:00Z")!
        let aprilThirdProviderTotals = try store.providerTotals(on: aprilThird, calendar: utcCalendar)
        let aprilFourthProviderTotals = try store.providerTotals(on: aprilFourth, calendar: utcCalendar)
        let aprilFourthHourlyUsage = try store.hourlyModelUsage(lastHours: 4, endingAt: aprilFourth, calendar: utcCalendar)

        #expect(report.scannedFileCount == 3)
        #expect(report.ingestedFileCount == 3)
        #expect(report.ingestedEntryCount == 5)
        #expect(daySnapshot.totals.inputTokens == 1_100)
        #expect(daySnapshot.totals.outputTokens == 325)
        #expect(daySnapshot.totals.cacheReadTokens == 330)
        #expect(daySnapshot.totals.cacheWriteTokens == 40)
        #expect(daySnapshot.totals.reasoningTokens == 30)
        #expect(daySnapshot.totals.totalTokens == 1_825)
        #expect(daySnapshot.totals.totalCostUSD > 0.42)
        #expect(daySnapshot.totals.entryCount == 5)
        #expect(daySnapshot.totals.sourceFileCount == 3)
        #expect(daySnapshot.buckets.count == 2)
        #expect(daySnapshot.buckets.map(\.key) == ["2026-04-04", "2026-04-03"])
        #expect(monthSnapshot.buckets.count == 1)
        #expect(monthSnapshot.buckets.first?.key == "2026-04")
        #expect(sessionSnapshot.buckets.count == 3)
        #expect(sessionSnapshot.buckets.contains(where: { $0.key == "claude-session-1" && $0.totalTokens == 265 }))
        #expect(sessionSnapshot.buckets.contains(where: { $0.key == "codex-session-1" && $0.totalTokens == 580 }))
        #expect(sessionSnapshot.buckets.contains(where: { $0.key == "opencode-session-1" && $0.totalTokens == 980 }))
        #expect(sessionSnapshot.totals.totalTokens == 1_825)
        #expect(aprilThirdProviderTotals.count == 1)
        #expect(aprilThirdProviderTotals.first?.provider == .claude)
        #expect(aprilThirdProviderTotals.first?.totalTokens == 265)
        #expect(aprilThirdProviderTotals.first?.entryCount == 2)
        #expect(aprilFourthProviderTotals.count == 2)
        #expect(aprilFourthProviderTotals.contains(where: { $0.provider == .codex && $0.totalTokens == 580 }))
        #expect(aprilFourthProviderTotals.contains(where: { $0.provider == .openCode && $0.totalTokens == 980 && $0.costUSD == 0.42 }))
        #expect(dailyModelUsage.contains(where: { $0.dateKey == "2026-04-04" && $0.modelIdentifier == "gpt-5.3-codex" && $0.totalTokens == 310 }))
        #expect(dailyModelUsage.contains(where: { $0.dateKey == "2026-04-04" && $0.modelIdentifier == "glm-4.7" && $0.totalTokens == 980 }))
        #expect(aprilFourthHourlyUsage.contains(where: { $0.modelIdentifier == "gpt-5.3-codex" && $0.totalTokens == 310 }))
        #expect(aprilFourthHourlyUsage.contains(where: { $0.modelIdentifier == "unknown" && $0.totalTokens == 270 }))
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

private func writeJSON(_ object: [String: Any], to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url)
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
