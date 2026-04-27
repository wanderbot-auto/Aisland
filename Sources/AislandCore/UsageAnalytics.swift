import Foundation
import SQLite3

public enum UsageLogProvider: String, Codable, Sendable, CaseIterable {
    case claude
    case codex
    case openCode

    public var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .openCode: "OpenCode"
        }
    }
}

public struct UsageAnalyticsRoot: Equatable, Sendable {
    public var provider: UsageLogProvider
    public var rootURL: URL

    public init(provider: UsageLogProvider, rootURL: URL) {
        self.provider = provider
        self.rootURL = rootURL
    }

    public static func defaultRoots(fileManager: FileManager = .default) -> [UsageAnalyticsRoot] {
        let home = fileManager.homeDirectoryForCurrentUser
        return [
            UsageAnalyticsRoot(
                provider: .claude,
                rootURL: home.appendingPathComponent(".claude", isDirectory: true)
            ),
            UsageAnalyticsRoot(
                provider: .codex,
                rootURL: home.appendingPathComponent(".codex", isDirectory: true)
            ),
            UsageAnalyticsRoot(
                provider: .openCode,
                rootURL: home.appendingPathComponent(".local/share/opencode/storage", isDirectory: true)
            ),
        ]
    }
}

public enum UsageAggregationPeriod: String, Codable, Sendable, CaseIterable, Identifiable {
    case day
    case month
    case session

    public var id: String { rawValue }
}

public struct UsageAnalyticsTotals: Equatable, Codable, Sendable {
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheReadTokens: Int
    public var cacheWriteTokens: Int
    public var reasoningTokens: Int
    public var totalTokens: Int
    public var totalCostUSD: Double
    public var entryCount: Int
    public var sourceFileCount: Int
    public var firstSeenAt: Date?
    public var lastSeenAt: Date?

    public init(
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int = 0,
        cacheWriteTokens: Int = 0,
        reasoningTokens: Int = 0,
        totalTokens: Int,
        totalCostUSD: Double = 0,
        entryCount: Int,
        sourceFileCount: Int,
        firstSeenAt: Date?,
        lastSeenAt: Date?
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.reasoningTokens = reasoningTokens
        self.totalTokens = totalTokens
        self.totalCostUSD = totalCostUSD
        self.entryCount = entryCount
        self.sourceFileCount = sourceFileCount
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
    }
}

public struct UsageAnalyticsBucket: Equatable, Codable, Sendable, Identifiable {
    public var id: String
    public var key: String
    public var label: String
    public var detail: String?
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheReadTokens: Int
    public var cacheWriteTokens: Int
    public var reasoningTokens: Int
    public var totalTokens: Int
    public var costUSD: Double
    public var entryCount: Int
    public var sourceFileCount: Int
    public var firstSeenAt: Date?
    public var lastSeenAt: Date?

    public init(
        id: String,
        key: String,
        label: String,
        detail: String? = nil,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int = 0,
        cacheWriteTokens: Int = 0,
        reasoningTokens: Int = 0,
        totalTokens: Int,
        costUSD: Double = 0,
        entryCount: Int,
        sourceFileCount: Int,
        firstSeenAt: Date?,
        lastSeenAt: Date?
    ) {
        self.id = id
        self.key = key
        self.label = label
        self.detail = detail
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.reasoningTokens = reasoningTokens
        self.totalTokens = totalTokens
        self.costUSD = costUSD
        self.entryCount = entryCount
        self.sourceFileCount = sourceFileCount
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
    }
}

public struct UsageAnalyticsSnapshot: Equatable, Codable, Sendable {
    public var generatedAt: Date
    public var period: UsageAggregationPeriod
    public var totals: UsageAnalyticsTotals
    public var buckets: [UsageAnalyticsBucket]

    public init(
        generatedAt: Date,
        period: UsageAggregationPeriod,
        totals: UsageAnalyticsTotals,
        buckets: [UsageAnalyticsBucket]
    ) {
        self.generatedAt = generatedAt
        self.period = period
        self.totals = totals
        self.buckets = buckets
    }

    public var isEmpty: Bool {
        totals.entryCount == 0
    }
}


public struct UsageAnalyticsProviderTotals: Equatable, Codable, Sendable, Identifiable {
    public var provider: UsageLogProvider
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheReadTokens: Int
    public var cacheWriteTokens: Int
    public var reasoningTokens: Int
    public var totalTokens: Int
    public var costUSD: Double
    public var entryCount: Int
    public var sourceFileCount: Int
    public var firstSeenAt: Date?
    public var lastSeenAt: Date?

    public init(
        provider: UsageLogProvider,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int = 0,
        cacheWriteTokens: Int = 0,
        reasoningTokens: Int = 0,
        totalTokens: Int,
        costUSD: Double = 0,
        entryCount: Int,
        sourceFileCount: Int,
        firstSeenAt: Date?,
        lastSeenAt: Date?
    ) {
        self.provider = provider
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.reasoningTokens = reasoningTokens
        self.totalTokens = totalTokens
        self.costUSD = costUSD
        self.entryCount = entryCount
        self.sourceFileCount = sourceFileCount
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
    }

    public var id: String {
        provider.rawValue
    }
}

public struct UsageAnalyticsDailyModelBucket: Equatable, Codable, Sendable, Identifiable {
    public var id: String
    public var dateKey: String
    public var modelIdentifier: String
    public var modelDisplayName: String
    public var provider: UsageLogProvider
    public var providerIdentifier: String?
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheReadTokens: Int
    public var cacheWriteTokens: Int
    public var reasoningTokens: Int
    public var totalTokens: Int
    public var costUSD: Double
    public var entryCount: Int

    public init(
        dateKey: String,
        modelIdentifier: String,
        modelDisplayName: String,
        provider: UsageLogProvider,
        providerIdentifier: String?,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int,
        cacheWriteTokens: Int,
        reasoningTokens: Int,
        totalTokens: Int,
        costUSD: Double,
        entryCount: Int
    ) {
        self.id = "\(dateKey)|\(provider.rawValue)|\(modelIdentifier)"
        self.dateKey = dateKey
        self.modelIdentifier = modelIdentifier
        self.modelDisplayName = modelDisplayName
        self.provider = provider
        self.providerIdentifier = providerIdentifier
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.reasoningTokens = reasoningTokens
        self.totalTokens = totalTokens
        self.costUSD = costUSD
        self.entryCount = entryCount
    }
}

public struct UsageAnalyticsRefreshReport: Equatable, Codable, Sendable {
    public var scannedFileCount: Int
    public var ingestedFileCount: Int
    public var ingestedEntryCount: Int

    public init(scannedFileCount: Int, ingestedFileCount: Int, ingestedEntryCount: Int) {
        self.scannedFileCount = scannedFileCount
        self.ingestedFileCount = ingestedFileCount
        self.ingestedEntryCount = ingestedEntryCount
    }
}

public struct UsageAnalyticsRecord: Equatable, Sendable {
    public var provider: UsageLogProvider
    public var sourceFilePath: String
    public var lineIndex: Int
    public var sessionIdentifier: String?
    public var recordType: String?
    public var modelIdentifier: String
    public var modelDisplayName: String
    public var providerIdentifier: String?
    public var occurredAt: Date
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheReadTokens: Int
    public var cacheWriteTokens: Int
    public var reasoningTokens: Int
    public var costUSD: Double

    public init(
        provider: UsageLogProvider,
        sourceFilePath: String,
        lineIndex: Int,
        sessionIdentifier: String?,
        recordType: String?,
        modelIdentifier: String = "unknown",
        modelDisplayName: String = "Unknown",
        providerIdentifier: String? = nil,
        occurredAt: Date,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int = 0,
        cacheWriteTokens: Int = 0,
        reasoningTokens: Int = 0,
        costUSD: Double? = nil
    ) {
        self.provider = provider
        self.sourceFilePath = sourceFilePath
        self.lineIndex = lineIndex
        self.sessionIdentifier = sessionIdentifier
        self.recordType = recordType
        self.modelIdentifier = modelIdentifier.isEmpty ? "unknown" : modelIdentifier
        self.modelDisplayName = modelDisplayName.isEmpty ? self.modelIdentifier : modelDisplayName
        self.providerIdentifier = providerIdentifier
        self.occurredAt = occurredAt
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.reasoningTokens = reasoningTokens
        self.costUSD = costUSD ?? Self.estimatedCostUSD(
            modelIdentifier: self.modelIdentifier,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheReadTokens: cacheReadTokens,
            cacheWriteTokens: cacheWriteTokens
        )
    }

    public var totalTokens: Int {
        inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens + reasoningTokens
    }

    private static func estimatedCostUSD(
        modelIdentifier: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int,
        cacheWriteTokens: Int
    ) -> Double {
        guard let pricing = UsageModelPricing.pricing(for: modelIdentifier) else {
            return 0
        }

        let million = 1_000_000.0
        return (Double(inputTokens) / million * pricing.inputPerMillion)
            + (Double(outputTokens) / million * pricing.outputPerMillion)
            + (Double(cacheReadTokens) / million * pricing.cacheReadPerMillion)
            + (Double(cacheWriteTokens) / million * pricing.cacheWritePerMillion)
    }
}

private struct UsageModelPricing {
    var inputPerMillion: Double
    var outputPerMillion: Double
    var cacheReadPerMillion: Double
    var cacheWritePerMillion: Double

    static func pricing(for rawModelIdentifier: String) -> UsageModelPricing? {
        let model = rawModelIdentifier.lowercased()

        if model.contains("gpt-4o-mini") {
            return .init(inputPerMillion: 0.15, outputPerMillion: 0.60, cacheReadPerMillion: 0.075, cacheWritePerMillion: 0.15)
        }
        if model.contains("gpt-4o") {
            return .init(inputPerMillion: 2.50, outputPerMillion: 10.00, cacheReadPerMillion: 1.25, cacheWritePerMillion: 2.50)
        }
        if model.contains("gpt-4.1") {
            return .init(inputPerMillion: 2.00, outputPerMillion: 8.00, cacheReadPerMillion: 0.50, cacheWritePerMillion: 2.00)
        }
        if model.contains("gpt-5") {
            return .init(inputPerMillion: 1.25, outputPerMillion: 10.00, cacheReadPerMillion: 0.25, cacheWritePerMillion: 1.25)
        }
        if model.contains("claude") && model.contains("opus") {
            return .init(inputPerMillion: 15.00, outputPerMillion: 75.00, cacheReadPerMillion: 1.50, cacheWritePerMillion: 18.75)
        }
        if model.contains("claude") && model.contains("haiku") {
            return .init(inputPerMillion: 0.80, outputPerMillion: 4.00, cacheReadPerMillion: 0.08, cacheWritePerMillion: 1.00)
        }
        if model.contains("claude") || model.contains("sonnet") {
            return .init(inputPerMillion: 3.00, outputPerMillion: 15.00, cacheReadPerMillion: 0.30, cacheWritePerMillion: 3.75)
        }
        if model.contains("glm-4.5-air") {
            return .init(inputPerMillion: 0.20, outputPerMillion: 1.10, cacheReadPerMillion: 0.02, cacheWritePerMillion: 0.20)
        }
        if model.contains("glm-") {
            return .init(inputPerMillion: 0.60, outputPerMillion: 2.20, cacheReadPerMillion: 0.10, cacheWritePerMillion: 0.60)
        }
        if model.contains("kimi") {
            return .init(inputPerMillion: 0.60, outputPerMillion: 2.50, cacheReadPerMillion: 0.075, cacheWritePerMillion: 0.60)
        }
        if model.contains("minimax") {
            return .init(inputPerMillion: 0.30, outputPerMillion: 1.20, cacheReadPerMillion: 0.03, cacheWritePerMillion: 0.30)
        }
        if model.contains("doubao") {
            return .init(inputPerMillion: 0.30, outputPerMillion: 1.20, cacheReadPerMillion: 0.03, cacheWritePerMillion: 0.30)
        }

        return nil
    }
}

private struct UsageLogParseState {
    var sessionIdentifier: String?
    var modelIdentifier: String?
    var providerIdentifier: String?
}

public final class UsageAnalyticsStore: @unchecked Sendable {
    public static let defaultDatabaseURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/aisland/usage.sqlite")

    public var databaseURL: URL
    public var roots: [UsageAnalyticsRoot]
    private let fileManager: FileManager

    public init(
        databaseURL: URL = defaultDatabaseURL,
        roots: [UsageAnalyticsRoot] = UsageAnalyticsRoot.defaultRoots(),
        fileManager: FileManager = .default
    ) {
        self.databaseURL = databaseURL
        self.roots = roots
        self.fileManager = fileManager
    }

    public func refresh() throws -> UsageAnalyticsRefreshReport {
        let files = discoverLogFiles()
        var report = UsageAnalyticsRefreshReport(scannedFileCount: files.count, ingestedFileCount: 0, ingestedEntryCount: 0)

        try withDatabase { db in
            try execute(db, sql: "PRAGMA journal_mode=WAL;")
            try execute(db, sql: "PRAGMA synchronous=NORMAL;")
            try ensureSchema(db)
            try execute(db, sql: "BEGIN IMMEDIATE TRANSACTION;")

            do {
                for file in files {
                    guard let metadata = try? file.url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else {
                        continue
                    }
                    let modifiedAt = metadata.contentModificationDate ?? .distantPast
                    let fileSize = Int64(metadata.fileSize ?? 0)
                    if try isUnchanged(filePath: file.url.path, modifiedAt: modifiedAt, fileSize: fileSize, db: db) {
                        continue
                    }

                    let entries: [UsageAnalyticsRecord]
                    do {
                        entries = try parseEntries(in: file.url, provider: file.provider)
                    } catch {
                        continue
                    }
                    try deleteEntries(for: file.url.path, db: db)
                    try insert(entries: entries, db: db)
                    try upsertFileMetadata(
                        filePath: file.url.path,
                        provider: file.provider,
                        modifiedAt: modifiedAt,
                        fileSize: fileSize,
                        db: db
                    )
                    report.ingestedFileCount += 1
                    report.ingestedEntryCount += entries.count
                }

                try execute(db, sql: "COMMIT;")
            } catch {
                _ = try? execute(db, sql: "ROLLBACK;")
                throw error
            }
        }

        return report
    }

    public func snapshot(for period: UsageAggregationPeriod) throws -> UsageAnalyticsSnapshot {
        try withDatabase { db in
            try execute(db, sql: "PRAGMA journal_mode=WAL;")
            try execute(db, sql: "PRAGMA synchronous=NORMAL;")
            try ensureSchema(db)
            return try loadSnapshot(for: period, db: db)
        }
    }

    public func snapshots() throws -> [UsageAggregationPeriod: UsageAnalyticsSnapshot] {
        try withDatabase { db in
            try execute(db, sql: "PRAGMA journal_mode=WAL;")
            try execute(db, sql: "PRAGMA synchronous=NORMAL;")
            try ensureSchema(db)

            var result: [UsageAggregationPeriod: UsageAnalyticsSnapshot] = [:]
            for period in UsageAggregationPeriod.allCases {
                result[period] = try loadSnapshot(for: period, db: db)
            }
            return result
        }
    }

    public func providerTotals(
        on date: Date = Date.now,
        calendar: Calendar = .current
    ) throws -> [UsageAnalyticsProviderTotals] {
        try withDatabase { db in
            try execute(db, sql: "PRAGMA journal_mode=WAL;")
            try execute(db, sql: "PRAGMA synchronous=NORMAL;")
            try ensureSchema(db)
            return try loadProviderTotals(on: date, calendar: calendar, db: db)
        }
    }

    public func dailyModelUsage(limitDays: Int = 120) throws -> [UsageAnalyticsDailyModelBucket] {
        try withDatabase { db in
            try execute(db, sql: "PRAGMA journal_mode=WAL;")
            try execute(db, sql: "PRAGMA synchronous=NORMAL;")
            try ensureSchema(db)
            return try loadDailyModelUsage(limitDays: limitDays, db: db)
        }
    }

    private struct LogFileCandidate {
        var provider: UsageLogProvider
        var url: URL
    }

    private func discoverLogFiles() -> [LogFileCandidate] {
        var result: [LogFileCandidate] = []

        for root in roots where fileManager.fileExists(atPath: root.rootURL.path) {
            guard let enumerator = fileManager.enumerator(
                at: root.rootURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
                guard values?.isRegularFile == true else {
                    continue
                }

                switch root.provider {
                case .claude, .codex:
                    guard fileURL.pathExtension == "jsonl" else {
                        continue
                    }
                case .openCode:
                    guard fileURL.pathExtension == "json",
                          fileURL.pathComponents.contains("message") else {
                        continue
                    }
                }

                result.append(LogFileCandidate(provider: root.provider, url: fileURL))
            }
        }

        return result.sorted { lhs, rhs in
            lhs.url.path.localizedStandardCompare(rhs.url.path) == .orderedAscending
        }
    }

    private func parseEntries(in fileURL: URL, provider: UsageLogProvider) throws -> [UsageAnalyticsRecord] {
        let data = try Data(contentsOf: fileURL)
        guard let contents = String(data: data, encoding: .utf8) else {
            return []
        }

        if provider == .openCode {
            guard let object = Self.jsonObject(fromData: data),
                  let record = Self.openCodeRecord(
                    from: object,
                    sourceFilePath: fileURL.path,
                    fallbackTimestamp: try fileTimestamp(for: fileURL) ?? .now
                  ) else {
                return []
            }
            return [record]
        }

        var result: [UsageAnalyticsRecord] = []
        let fallbackTimestamp = try fileTimestamp(for: fileURL) ?? .now
        var lineIndex = 0
        var state = UsageLogParseState()

        contents.enumerateLines { line, _ in
            defer { lineIndex += 1 }
            guard let object = Self.jsonObject(from: line) else {
                return
            }

            guard let record = Self.record(
                from: object,
                provider: provider,
                sourceFilePath: fileURL.path,
                lineIndex: lineIndex,
                fallbackTimestamp: fallbackTimestamp,
                state: &state
            ) else {
                return
            }

            result.append(record)
        }

        return result
    }

    private func fileTimestamp(for fileURL: URL) throws -> Date? {
        let values = try fileURL.resourceValues(forKeys: [.contentModificationDateKey])
        return values.contentModificationDate
    }

    private func isUnchanged(filePath: String, modifiedAt: Date, fileSize: Int64, db: OpaquePointer) throws -> Bool {
        let sql = "SELECT last_modified, file_size FROM usage_source_files WHERE source_file_path = ? LIMIT 1;"
        return try withPreparedStatement(db, sql: sql) { stmt in
            try bindText(filePath, to: stmt, index: 1)
            guard sqlite3_step(stmt) == SQLITE_ROW else {
                return false
            }

            let storedModifiedAt = sqlite3_column_double(stmt, 0)
            let storedFileSize = sqlite3_column_int64(stmt, 1)
            return storedModifiedAt == modifiedAt.timeIntervalSince1970 && storedFileSize == fileSize
        }
    }

    private func deleteEntries(for filePath: String, db: OpaquePointer) throws {
        try withPreparedStatement(db, sql: "DELETE FROM usage_samples WHERE source_file_path = ?;") { stmt in
            try bindText(filePath, to: stmt, index: 1)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw sqliteError(db, operation: "delete usage_samples")
            }
        }
    }

    private func insert(entries: [UsageAnalyticsRecord], db: OpaquePointer) throws {
        guard !entries.isEmpty else {
            return
        }

        try withPreparedStatement(
            db,
            sql: """
            INSERT OR REPLACE INTO usage_samples
            (
                provider, source_file_path, line_index, session_identifier, record_type,
                model_identifier, model_display_name, provider_identifier, occurred_at,
                input_tokens, output_tokens, cache_read_tokens, cache_write_tokens,
                reasoning_tokens, total_tokens, cost_usd
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        ) { stmt in
            for entry in entries {
                sqlite3_reset(stmt)
                sqlite3_clear_bindings(stmt)

                try bindText(entry.provider.rawValue, to: stmt, index: 1)
                try bindText(entry.sourceFilePath, to: stmt, index: 2)
                sqlite3_bind_int(stmt, 3, Int32(entry.lineIndex))
                try bindOptionalText(entry.sessionIdentifier, to: stmt, index: 4)
                try bindOptionalText(entry.recordType, to: stmt, index: 5)
                try bindText(entry.modelIdentifier, to: stmt, index: 6)
                try bindText(entry.modelDisplayName, to: stmt, index: 7)
                try bindOptionalText(entry.providerIdentifier, to: stmt, index: 8)
                sqlite3_bind_double(stmt, 9, entry.occurredAt.timeIntervalSince1970)
                sqlite3_bind_int64(stmt, 10, sqlite3_int64(entry.inputTokens))
                sqlite3_bind_int64(stmt, 11, sqlite3_int64(entry.outputTokens))
                sqlite3_bind_int64(stmt, 12, sqlite3_int64(entry.cacheReadTokens))
                sqlite3_bind_int64(stmt, 13, sqlite3_int64(entry.cacheWriteTokens))
                sqlite3_bind_int64(stmt, 14, sqlite3_int64(entry.reasoningTokens))
                sqlite3_bind_int64(stmt, 15, sqlite3_int64(entry.totalTokens))
                sqlite3_bind_double(stmt, 16, entry.costUSD)

                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw sqliteError(db, operation: "insert usage_samples")
                }
            }
        }
    }

    private func upsertFileMetadata(
        filePath: String,
        provider: UsageLogProvider,
        modifiedAt: Date,
        fileSize: Int64,
        db: OpaquePointer
    ) throws {
        try withPreparedStatement(
            db,
            sql: """
            INSERT INTO usage_source_files
            (source_file_path, provider, last_modified, file_size, last_scanned_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(source_file_path) DO UPDATE SET
                provider = excluded.provider,
                last_modified = excluded.last_modified,
                file_size = excluded.file_size,
                last_scanned_at = excluded.last_scanned_at;
            """
        ) { stmt in
            try bindText(filePath, to: stmt, index: 1)
            try bindText(provider.rawValue, to: stmt, index: 2)
            sqlite3_bind_double(stmt, 3, modifiedAt.timeIntervalSince1970)
            sqlite3_bind_int64(stmt, 4, fileSize)
            sqlite3_bind_double(stmt, 5, Date.now.timeIntervalSince1970)

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw sqliteError(db, operation: "upsert usage_source_files")
            }
        }
    }

    private func loadSnapshot(for period: UsageAggregationPeriod, db: OpaquePointer) throws -> UsageAnalyticsSnapshot {
        let totals = try loadTotals(db: db)
        let buckets = try loadBuckets(for: period, db: db)
        return UsageAnalyticsSnapshot(
            generatedAt: Date.now,
            period: period,
            totals: totals,
            buckets: buckets
        )
    }

    private func loadTotals(db: OpaquePointer) throws -> UsageAnalyticsTotals {
        let sql = """
        SELECT
            COALESCE(SUM(input_tokens), 0),
            COALESCE(SUM(output_tokens), 0),
            COALESCE(SUM(cache_read_tokens), 0),
            COALESCE(SUM(cache_write_tokens), 0),
            COALESCE(SUM(reasoning_tokens), 0),
            COALESCE(SUM(total_tokens), 0),
            COALESCE(SUM(cost_usd), 0),
            COUNT(*),
            COUNT(DISTINCT source_file_path),
            MIN(occurred_at),
            MAX(occurred_at)
        FROM usage_samples;
        """

        return try withPreparedStatement(db, sql: sql) { stmt in
            guard sqlite3_step(stmt) == SQLITE_ROW else {
                return UsageAnalyticsTotals(
                    inputTokens: 0,
                    outputTokens: 0,
                    cacheReadTokens: 0,
                    cacheWriteTokens: 0,
                    reasoningTokens: 0,
                    totalTokens: 0,
                    totalCostUSD: 0,
                    entryCount: 0,
                    sourceFileCount: 0,
                    firstSeenAt: nil,
                    lastSeenAt: nil
                )
            }

            return UsageAnalyticsTotals(
                inputTokens: Int(sqlite3_column_int64(stmt, 0)),
                outputTokens: Int(sqlite3_column_int64(stmt, 1)),
                cacheReadTokens: Int(sqlite3_column_int64(stmt, 2)),
                cacheWriteTokens: Int(sqlite3_column_int64(stmt, 3)),
                reasoningTokens: Int(sqlite3_column_int64(stmt, 4)),
                totalTokens: Int(sqlite3_column_int64(stmt, 5)),
                totalCostUSD: sqlite3_column_double(stmt, 6),
                entryCount: Int(sqlite3_column_int64(stmt, 7)),
                sourceFileCount: Int(sqlite3_column_int64(stmt, 8)),
                firstSeenAt: Self.date(fromSQLColumnAt: 9, in: stmt),
                lastSeenAt: Self.date(fromSQLColumnAt: 10, in: stmt)
            )
        }
    }

    private func loadProviderTotals(
        on date: Date,
        calendar: Calendar,
        db: OpaquePointer
    ) throws -> [UsageAnalyticsProviderTotals] {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let sql = """
        SELECT
            provider,
            COALESCE(SUM(input_tokens), 0),
            COALESCE(SUM(output_tokens), 0),
            COALESCE(SUM(cache_read_tokens), 0),
            COALESCE(SUM(cache_write_tokens), 0),
            COALESCE(SUM(reasoning_tokens), 0),
            COALESCE(SUM(total_tokens), 0),
            COALESCE(SUM(cost_usd), 0),
            COUNT(*),
            COUNT(DISTINCT source_file_path),
            MIN(occurred_at),
            MAX(occurred_at)
        FROM usage_samples
        WHERE occurred_at >= ? AND occurred_at < ?
        GROUP BY provider
        ORDER BY provider ASC;
        """

        return try withPreparedStatement(db, sql: sql) { stmt in
            sqlite3_bind_double(stmt, 1, startOfDay.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 2, endOfDay.timeIntervalSince1970)

            var rows: [UsageAnalyticsProviderTotals] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let provider = Self.provider(fromSQLColumnAt: 0, in: stmt) else {
                    continue
                }

                rows.append(
                    UsageAnalyticsProviderTotals(
                        provider: provider,
                        inputTokens: Int(sqlite3_column_int64(stmt, 1)),
                        outputTokens: Int(sqlite3_column_int64(stmt, 2)),
                        cacheReadTokens: Int(sqlite3_column_int64(stmt, 3)),
                        cacheWriteTokens: Int(sqlite3_column_int64(stmt, 4)),
                        reasoningTokens: Int(sqlite3_column_int64(stmt, 5)),
                        totalTokens: Int(sqlite3_column_int64(stmt, 6)),
                        costUSD: sqlite3_column_double(stmt, 7),
                        entryCount: Int(sqlite3_column_int64(stmt, 8)),
                        sourceFileCount: Int(sqlite3_column_int64(stmt, 9)),
                        firstSeenAt: Self.date(fromSQLColumnAt: 10, in: stmt),
                        lastSeenAt: Self.date(fromSQLColumnAt: 11, in: stmt)
                    )
                )
            }
            return rows
        }
    }

    private func loadBuckets(for period: UsageAggregationPeriod, db: OpaquePointer) throws -> [UsageAnalyticsBucket] {
        switch period {
        case .day:
            return try loadBuckets(
                db: db,
                bucketKeySQL: "date(occurred_at, 'unixepoch', 'localtime')",
                orderBy: "bucket_key DESC"
            ) { bucketKey, row in
                return (
                    Self.bucketLabel(forDayKey: bucketKey),
                    Self.bucketDetail(
                    entryCount: row.entryCount,
                    sourceFileCount: row.sourceFileCount,
                    firstSeenAt: row.firstSeenAt,
                    lastSeenAt: row.lastSeenAt
                    )
                )
            }
        case .month:
            return try loadBuckets(
                db: db,
                bucketKeySQL: "strftime('%Y-%m', occurred_at, 'unixepoch', 'localtime')",
                orderBy: "bucket_key DESC"
            ) { bucketKey, row in
                return (
                    Self.bucketLabel(forMonthKey: bucketKey),
                    Self.bucketDetail(
                    entryCount: row.entryCount,
                    sourceFileCount: row.sourceFileCount,
                    firstSeenAt: row.firstSeenAt,
                    lastSeenAt: row.lastSeenAt
                    )
                )
            }
        case .session:
            return try loadBuckets(
                db: db,
                bucketKeySQL: "COALESCE(NULLIF(session_identifier, ''), source_file_path)",
                orderBy: "last_seen_at DESC, bucket_key ASC",
                includeProvider: true
            ) { bucketKey, row in
                return (
                    Self.bucketLabel(forSessionKey: bucketKey, provider: row.provider, sourceFilePath: row.sourceFilePath),
                    Self.bucketDetail(
                    entryCount: row.entryCount,
                    sourceFileCount: row.sourceFileCount,
                    firstSeenAt: row.firstSeenAt,
                    lastSeenAt: row.lastSeenAt
                    )
                )
            }
        }
    }

    private struct BucketRow {
        var bucketKey: String
        var provider: UsageLogProvider?
        var sourceFilePath: String
        var inputTokens: Int
        var outputTokens: Int
        var cacheReadTokens: Int
        var cacheWriteTokens: Int
        var reasoningTokens: Int
        var totalTokens: Int
        var costUSD: Double
        var entryCount: Int
        var sourceFileCount: Int
        var firstSeenAt: Date?
        var lastSeenAt: Date?
    }

    private func loadBuckets(
        db: OpaquePointer,
        bucketKeySQL: String,
        orderBy: String,
        includeProvider: Bool = false,
        makePresentation: (String, BucketRow) -> (String, String?)?
    ) throws -> [UsageAnalyticsBucket] {
        let sql = """
        SELECT
            \(bucketKeySQL) AS bucket_key,
            COALESCE(SUM(input_tokens), 0) AS input_tokens,
            COALESCE(SUM(output_tokens), 0) AS output_tokens,
            COALESCE(SUM(cache_read_tokens), 0) AS cache_read_tokens,
            COALESCE(SUM(cache_write_tokens), 0) AS cache_write_tokens,
            COALESCE(SUM(reasoning_tokens), 0) AS reasoning_tokens,
            COALESCE(SUM(total_tokens), 0) AS total_tokens,
            COALESCE(SUM(cost_usd), 0) AS cost_usd,
            COUNT(*) AS entry_count,
            COUNT(DISTINCT source_file_path) AS source_file_count,
            MIN(occurred_at) AS first_seen_at,
            MAX(occurred_at) AS last_seen_at
            \(includeProvider ? ", provider, MIN(source_file_path) AS source_file_path" : ", MIN(source_file_path) AS source_file_path")
        FROM usage_samples
        GROUP BY \(bucketKeySQL)\(includeProvider ? ", provider" : "")
        ORDER BY \(orderBy);
        """

        return try withPreparedStatement(db, sql: sql) { stmt in
            var rows: [UsageAnalyticsBucket] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let bucketKey = Self.string(fromSQLColumnAt: 0, in: stmt) ?? ""
                let inputTokens = Int(sqlite3_column_int64(stmt, 1))
                let outputTokens = Int(sqlite3_column_int64(stmt, 2))
                let cacheReadTokens = Int(sqlite3_column_int64(stmt, 3))
                let cacheWriteTokens = Int(sqlite3_column_int64(stmt, 4))
                let reasoningTokens = Int(sqlite3_column_int64(stmt, 5))
                let totalTokens = Int(sqlite3_column_int64(stmt, 6))
                let costUSD = sqlite3_column_double(stmt, 7)
                let entryCount = Int(sqlite3_column_int64(stmt, 8))
                let sourceFileCount = Int(sqlite3_column_int64(stmt, 9))
                let firstSeenAt = Self.date(fromSQLColumnAt: 10, in: stmt)
                let lastSeenAt = Self.date(fromSQLColumnAt: 11, in: stmt)

                var provider: UsageLogProvider?
                var sourceFilePath = bucketKey

                if includeProvider {
                    provider = Self.provider(fromSQLColumnAt: 12, in: stmt)
                    sourceFilePath = Self.string(fromSQLColumnAt: 13, in: stmt) ?? bucketKey
                } else {
                    sourceFilePath = Self.string(fromSQLColumnAt: 12, in: stmt) ?? bucketKey
                }

                let row = BucketRow(
                    bucketKey: bucketKey,
                    provider: provider,
                    sourceFilePath: sourceFilePath,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cacheReadTokens: cacheReadTokens,
                    cacheWriteTokens: cacheWriteTokens,
                    reasoningTokens: reasoningTokens,
                    totalTokens: totalTokens,
                    costUSD: costUSD,
                    entryCount: entryCount,
                    sourceFileCount: sourceFileCount,
                    firstSeenAt: firstSeenAt,
                    lastSeenAt: lastSeenAt
                )

                if let presentation = makePresentation(bucketKey, row) {
                    let (label, detail) = presentation
                    rows.append(
                        UsageAnalyticsBucket(
                            id: includeProvider ? "\(provider?.rawValue ?? "unknown")|\(bucketKey)" : bucketKey,
                            key: bucketKey,
                            label: label,
                            detail: detail,
                            inputTokens: inputTokens,
                            outputTokens: outputTokens,
                            cacheReadTokens: cacheReadTokens,
                            cacheWriteTokens: cacheWriteTokens,
                            reasoningTokens: reasoningTokens,
                            totalTokens: totalTokens,
                            costUSD: costUSD,
                            entryCount: entryCount,
                            sourceFileCount: sourceFileCount,
                            firstSeenAt: firstSeenAt,
                            lastSeenAt: lastSeenAt
                        )
                    )
                }
            }
            return rows
        }
    }

    private func loadDailyModelUsage(limitDays: Int, db: OpaquePointer) throws -> [UsageAnalyticsDailyModelBucket] {
        let dayLimit = max(1, limitDays)
        let sql = """
        WITH recent_days AS (
            SELECT DISTINCT date(occurred_at, 'unixepoch', 'localtime') AS day_key
            FROM usage_samples
            ORDER BY day_key DESC
            LIMIT ?
        )
        SELECT
            date(s.occurred_at, 'unixepoch', 'localtime') AS day_key,
            s.model_identifier,
            s.model_display_name,
            s.provider,
            s.provider_identifier,
            COALESCE(SUM(s.input_tokens), 0) AS input_tokens,
            COALESCE(SUM(s.output_tokens), 0) AS output_tokens,
            COALESCE(SUM(s.cache_read_tokens), 0) AS cache_read_tokens,
            COALESCE(SUM(s.cache_write_tokens), 0) AS cache_write_tokens,
            COALESCE(SUM(s.reasoning_tokens), 0) AS reasoning_tokens,
            COALESCE(SUM(s.total_tokens), 0) AS total_tokens,
            COALESCE(SUM(s.cost_usd), 0) AS cost_usd,
            COUNT(*) AS entry_count
        FROM usage_samples s
        INNER JOIN recent_days d ON d.day_key = date(s.occurred_at, 'unixepoch', 'localtime')
        GROUP BY day_key, s.provider, s.provider_identifier, s.model_identifier, s.model_display_name
        ORDER BY day_key ASC, total_tokens DESC;
        """

        return try withPreparedStatement(db, sql: sql) { stmt in
            sqlite3_bind_int(stmt, 1, Int32(dayLimit))

            var rows: [UsageAnalyticsDailyModelBucket] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let dateKey = Self.string(fromSQLColumnAt: 0, in: stmt),
                      let modelIdentifier = Self.string(fromSQLColumnAt: 1, in: stmt),
                      let provider = Self.provider(fromSQLColumnAt: 3, in: stmt) else {
                    continue
                }

                rows.append(
                    UsageAnalyticsDailyModelBucket(
                        dateKey: dateKey,
                        modelIdentifier: modelIdentifier,
                        modelDisplayName: Self.string(fromSQLColumnAt: 2, in: stmt) ?? modelIdentifier,
                        provider: provider,
                        providerIdentifier: Self.string(fromSQLColumnAt: 4, in: stmt),
                        inputTokens: Int(sqlite3_column_int64(stmt, 5)),
                        outputTokens: Int(sqlite3_column_int64(stmt, 6)),
                        cacheReadTokens: Int(sqlite3_column_int64(stmt, 7)),
                        cacheWriteTokens: Int(sqlite3_column_int64(stmt, 8)),
                        reasoningTokens: Int(sqlite3_column_int64(stmt, 9)),
                        totalTokens: Int(sqlite3_column_int64(stmt, 10)),
                        costUSD: sqlite3_column_double(stmt, 11),
                        entryCount: Int(sqlite3_column_int64(stmt, 12))
                    )
                )
            }
            return rows
        }
    }

    private func withDatabase<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        try fileManager.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
              let db else {
            throw sqliteError(db, operation: "open database")
        }

        defer { sqlite3_close(db) }
        return try body(db)
    }

    private func ensureSchema(_ db: OpaquePointer) throws {
        try execute(db, sql: """
        CREATE TABLE IF NOT EXISTS usage_source_files (
            source_file_path TEXT PRIMARY KEY NOT NULL,
            provider TEXT NOT NULL,
            last_modified REAL NOT NULL,
            file_size INTEGER NOT NULL,
            last_scanned_at REAL NOT NULL
        );
        """)

        try execute(db, sql: """
        CREATE TABLE IF NOT EXISTS usage_samples (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            provider TEXT NOT NULL,
            source_file_path TEXT NOT NULL,
            line_index INTEGER NOT NULL,
            session_identifier TEXT,
            record_type TEXT,
            model_identifier TEXT NOT NULL DEFAULT 'unknown',
            model_display_name TEXT NOT NULL DEFAULT 'Unknown',
            provider_identifier TEXT,
            occurred_at REAL NOT NULL,
            input_tokens INTEGER NOT NULL,
            output_tokens INTEGER NOT NULL,
            cache_read_tokens INTEGER NOT NULL DEFAULT 0,
            cache_write_tokens INTEGER NOT NULL DEFAULT 0,
            reasoning_tokens INTEGER NOT NULL DEFAULT 0,
            total_tokens INTEGER NOT NULL,
            cost_usd REAL NOT NULL DEFAULT 0,
            UNIQUE(source_file_path, line_index)
        );
        """)

        var didAddUsageColumns = false
        didAddUsageColumns = try ensureColumn("usage_samples", column: "model_identifier", definition: "TEXT NOT NULL DEFAULT 'unknown'", db: db) || didAddUsageColumns
        didAddUsageColumns = try ensureColumn("usage_samples", column: "model_display_name", definition: "TEXT NOT NULL DEFAULT 'Unknown'", db: db) || didAddUsageColumns
        didAddUsageColumns = try ensureColumn("usage_samples", column: "provider_identifier", definition: "TEXT", db: db) || didAddUsageColumns
        didAddUsageColumns = try ensureColumn("usage_samples", column: "cache_read_tokens", definition: "INTEGER NOT NULL DEFAULT 0", db: db) || didAddUsageColumns
        didAddUsageColumns = try ensureColumn("usage_samples", column: "cache_write_tokens", definition: "INTEGER NOT NULL DEFAULT 0", db: db) || didAddUsageColumns
        didAddUsageColumns = try ensureColumn("usage_samples", column: "reasoning_tokens", definition: "INTEGER NOT NULL DEFAULT 0", db: db) || didAddUsageColumns
        didAddUsageColumns = try ensureColumn("usage_samples", column: "cost_usd", definition: "REAL NOT NULL DEFAULT 0", db: db) || didAddUsageColumns

        if didAddUsageColumns {
            try execute(db, sql: "DELETE FROM usage_source_files;")
            try execute(db, sql: "DELETE FROM usage_samples;")
        }

        try execute(db, sql: "CREATE INDEX IF NOT EXISTS usage_samples_occurred_at_index ON usage_samples(occurred_at);")
        try execute(db, sql: "CREATE INDEX IF NOT EXISTS usage_samples_session_index ON usage_samples(provider, session_identifier);")
        try execute(db, sql: "CREATE INDEX IF NOT EXISTS usage_samples_source_index ON usage_samples(source_file_path);")
        try execute(db, sql: "CREATE INDEX IF NOT EXISTS usage_samples_model_day_index ON usage_samples(model_identifier, occurred_at);")
    }

    private func ensureColumn(_ table: String, column: String, definition: String, db: OpaquePointer) throws -> Bool {
        let existingColumns = try tableColumns(table, db: db)
        guard !existingColumns.contains(column) else {
            return false
        }

        try execute(db, sql: "ALTER TABLE \(table) ADD COLUMN \(column) \(definition);")
        return true
    }

    private func tableColumns(_ table: String, db: OpaquePointer) throws -> Set<String> {
        try withPreparedStatement(db, sql: "PRAGMA table_info(\(table));") { stmt in
            var columns = Set<String>()
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let name = Self.string(fromSQLColumnAt: 1, in: stmt) {
                    columns.insert(name)
                }
            }
            return columns
        }
    }

    private func execute(_ db: OpaquePointer, sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            defer { sqlite3_free(errorMessage) }
            let message = errorMessage.flatMap { String(cString: $0) } ?? "unknown sqlite error"
            throw NSError(domain: "UsageAnalyticsStore", code: Int(sqlite3_errcode(db)), userInfo: [
                NSLocalizedDescriptionKey: "SQLite error during `\(sql.prefix(64))`: \(message)"
            ])
        }
    }

    private func withPreparedStatement<T>(
        _ db: OpaquePointer,
        sql: String,
        body: (OpaquePointer) throws -> T
    ) throws -> T {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw sqliteError(db, operation: "prepare statement")
        }
        defer { sqlite3_finalize(statement) }
        return try body(statement)
    }

    private func bindText(_ text: String, to stmt: OpaquePointer, index: Int32) throws {
        let result = text.withCString { cString in
            sqlite3_bind_text(
                stmt,
                index,
                cString,
                -1,
                unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            )
        }
        guard result == SQLITE_OK else {
            throw sqliteError(nil, operation: "bind text")
        }
    }

    private func bindOptionalText(_ text: String?, to stmt: OpaquePointer, index: Int32) throws {
        guard let text else {
            guard sqlite3_bind_null(stmt, index) == SQLITE_OK else {
                throw sqliteError(nil, operation: "bind null")
            }
            return
        }

        try bindText(text, to: stmt, index: index)
    }

    private func sqliteError(_ db: OpaquePointer?, operation: String) -> NSError {
        let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown sqlite error"
        return NSError(domain: "UsageAnalyticsStore", code: Int(db.map { sqlite3_errcode($0) } ?? SQLITE_ERROR), userInfo: [
            NSLocalizedDescriptionKey: "SQLite error while trying to \(operation): \(message)"
        ])
    }

    private static func string(fromSQLColumnAt index: Int32, in stmt: OpaquePointer) -> String? {
        guard let cString = sqlite3_column_text(stmt, index) else {
            return nil
        }
        return String(cString: cString)
    }

    private static func provider(fromSQLColumnAt index: Int32, in stmt: OpaquePointer) -> UsageLogProvider? {
        guard let value = string(fromSQLColumnAt: index, in: stmt) else {
            return nil
        }
        return UsageLogProvider(rawValue: value)
    }

    private static func date(fromSQLColumnAt index: Int32, in stmt: OpaquePointer) -> Date? {
        let value = sqlite3_column_double(stmt, index)
        guard value > 0 else {
            return nil
        }
        return Date(timeIntervalSince1970: value)
    }

    private static func bucketLabel(forDayKey key: String) -> String {
        dateLabelFormatter(dateFormat: "yyyy-MM-dd", template: "MMM d", from: key) ?? key
    }

    private static func bucketLabel(forMonthKey key: String) -> String {
        dateLabelFormatter(dateFormat: "yyyy-MM", template: "MMM yyyy", from: key) ?? key
    }

    private static func bucketLabel(forSessionKey key: String, provider: UsageLogProvider?, sourceFilePath: String) -> String {
        let sourceName = URL(fileURLWithPath: sourceFilePath).lastPathComponent
        if key == sourceFilePath {
            return "\(provider?.displayName ?? "Usage") · \(sourceName)"
        }
        return "\(provider?.displayName ?? "Usage") · \(key)"
    }

    private static func bucketDetail(
        entryCount: Int,
        sourceFileCount: Int,
        firstSeenAt: Date?,
        lastSeenAt: Date?
    ) -> String? {
        var parts: [String] = []
        parts.append("\(entryCount) entries")
        parts.append("\(sourceFileCount) files")
        if let firstSeenAt {
            parts.append("from \(firstSeenAt.formatted(date: .abbreviated, time: .shortened))")
        }
        if let lastSeenAt {
            parts.append("updated \(lastSeenAt.formatted(date: .abbreviated, time: .shortened))")
        }
        return parts.joined(separator: " · ")
    }

    private static func dateLabelFormatter(dateFormat: String, template: String, from value: String) -> String? {
        let inputFormatter = DateFormatter()
        inputFormatter.locale = .current
        inputFormatter.timeZone = .current
        inputFormatter.dateFormat = dateFormat

        guard let date = inputFormatter.date(from: value) else {
            return nil
        }

        let outputFormatter = DateFormatter()
        outputFormatter.locale = .current
        outputFormatter.timeZone = .current
        outputFormatter.setLocalizedDateFormatFromTemplate(template)
        return outputFormatter.string(from: date)
    }

    private static func jsonObject(from line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
    }

    private static func jsonObject(fromData data: Data) -> [String: Any]? {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
    }

    private static func record(
        from object: [String: Any],
        provider: UsageLogProvider,
        sourceFilePath: String,
        lineIndex: Int,
        fallbackTimestamp: Date,
        state: inout UsageLogParseState
    ) -> UsageAnalyticsRecord? {
        switch provider {
        case .codex:
            return codexRecord(
                from: object,
                sourceFilePath: sourceFilePath,
                lineIndex: lineIndex,
                fallbackTimestamp: fallbackTimestamp,
                state: &state
            )
        case .claude:
            return claudeRecord(
                from: object,
                sourceFilePath: sourceFilePath,
                lineIndex: lineIndex,
                fallbackTimestamp: fallbackTimestamp,
                state: &state
            )
        case .openCode:
            return nil
        }
    }

    private static func codexRecord(
        from object: [String: Any],
        sourceFilePath: String,
        lineIndex: Int,
        fallbackTimestamp: Date,
        state: inout UsageLogParseState
    ) -> UsageAnalyticsRecord? {
        let payload = object["payload"] as? [String: Any]

        state.sessionIdentifier = string(forKeys: ["id", "session_id", "sessionId"], in: payload as Any)
            ?? state.sessionIdentifier
        state.modelIdentifier = string(forKeys: ["model"], in: payload as Any)
            ?? string(forKeys: ["model"], in: object)
            ?? state.modelIdentifier
        state.providerIdentifier = string(forKeys: ["model_provider", "modelProvider", "provider"], in: payload as Any)
            ?? state.providerIdentifier

        guard let usageRoot = codexUsageObject(from: object) else {
            return genericRecord(
                from: object,
                provider: .codex,
                sourceFilePath: sourceFilePath,
                lineIndex: lineIndex,
                fallbackTimestamp: fallbackTimestamp,
                state: state
            )
        }

        let tokens = tokenCounts(from: usageRoot)
        guard tokens.hasUsage else {
            return nil
        }

        let occurredAt = date(forKeys: ["timestamp", "created_at", "createdAt", "time"], in: object) ?? fallbackTimestamp
        let modelIdentifier = normalizedModelIdentifier(state.modelIdentifier)
        return UsageAnalyticsRecord(
            provider: .codex,
            sourceFilePath: sourceFilePath,
            lineIndex: lineIndex,
            sessionIdentifier: state.sessionIdentifier,
            recordType: "token_count",
            modelIdentifier: modelIdentifier,
            modelDisplayName: displayName(forModelIdentifier: modelIdentifier),
            providerIdentifier: state.providerIdentifier,
            occurredAt: occurredAt,
            inputTokens: tokens.input,
            outputTokens: tokens.output,
            cacheReadTokens: tokens.cacheRead,
            cacheWriteTokens: tokens.cacheWrite,
            reasoningTokens: tokens.reasoning,
            costUSD: explicitCost(from: object)
        )
    }

    private static func claudeRecord(
        from object: [String: Any],
        sourceFilePath: String,
        lineIndex: Int,
        fallbackTimestamp: Date,
        state: inout UsageLogParseState
    ) -> UsageAnalyticsRecord? {
        state.sessionIdentifier = string(forKeys: ["sessionId", "session_id"], in: object) ?? state.sessionIdentifier

        guard let message = object["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any] else {
            return genericRecord(
                from: object,
                provider: .claude,
                sourceFilePath: sourceFilePath,
                lineIndex: lineIndex,
                fallbackTimestamp: fallbackTimestamp,
                state: state
            )
        }

        let tokens = tokenCounts(from: usage)
        guard tokens.hasUsage else {
            return nil
        }

        let modelIdentifier = normalizedModelIdentifier(
            string(forKeys: ["model"], in: message) ?? state.modelIdentifier
        )
        let occurredAt = date(forKeys: ["timestamp", "created_at", "createdAt", "time"], in: object) ?? fallbackTimestamp
        return UsageAnalyticsRecord(
            provider: .claude,
            sourceFilePath: sourceFilePath,
            lineIndex: lineIndex,
            sessionIdentifier: state.sessionIdentifier,
            recordType: string(forKeys: ["type", "role"], in: object) ?? "assistant",
            modelIdentifier: modelIdentifier,
            modelDisplayName: displayName(forModelIdentifier: modelIdentifier),
            providerIdentifier: "anthropic",
            occurredAt: occurredAt,
            inputTokens: tokens.input,
            outputTokens: tokens.output,
            cacheReadTokens: tokens.cacheRead,
            cacheWriteTokens: tokens.cacheWrite,
            reasoningTokens: tokens.reasoning,
            costUSD: explicitCost(from: object)
        )
    }

    private static func openCodeRecord(
        from object: [String: Any],
        sourceFilePath: String,
        fallbackTimestamp: Date
    ) -> UsageAnalyticsRecord? {
        guard string(forKeys: ["role"], in: object) == "assistant",
              let tokensRoot = object["tokens"] as? [String: Any] else {
            return nil
        }

        let tokens = tokenCounts(from: tokensRoot)
        guard tokens.hasUsage else {
            return nil
        }

        let modelIdentifier = normalizedModelIdentifier(string(forKeys: ["modelID", "modelId", "model"], in: object))
        let explicitCost = double(forKeys: ["cost", "cost_usd", "costUSD"], in: object)
        return UsageAnalyticsRecord(
            provider: .openCode,
            sourceFilePath: sourceFilePath,
            lineIndex: 0,
            sessionIdentifier: string(forKeys: ["sessionID", "sessionId", "session_id"], in: object),
            recordType: "assistant",
            modelIdentifier: modelIdentifier,
            modelDisplayName: displayName(forModelIdentifier: modelIdentifier),
            providerIdentifier: string(forKeys: ["providerID", "providerId", "provider"], in: object),
            occurredAt: date(forKeys: ["created", "timestamp", "created_at"], in: object["time"] as Any)
                ?? date(forKeys: ["timestamp", "created_at", "createdAt"], in: object)
                ?? fallbackTimestamp,
            inputTokens: tokens.input,
            outputTokens: tokens.output,
            cacheReadTokens: tokens.cacheRead,
            cacheWriteTokens: tokens.cacheWrite,
            reasoningTokens: tokens.reasoning,
            costUSD: (explicitCost ?? 0) > 0 ? explicitCost : nil
        )
    }

    private static func genericRecord(
        from object: [String: Any],
        provider: UsageLogProvider,
        sourceFilePath: String,
        lineIndex: Int,
        fallbackTimestamp: Date,
        state: UsageLogParseState
    ) -> UsageAnalyticsRecord? {
        let tokens = tokenCounts(from: object)
        guard tokens.hasUsage else {
            return nil
        }

        let modelIdentifier = normalizedModelIdentifier(
            string(forKeys: ["model", "modelID", "modelId"], in: object) ?? state.modelIdentifier
        )
        return UsageAnalyticsRecord(
            provider: provider,
            sourceFilePath: sourceFilePath,
            lineIndex: lineIndex,
            sessionIdentifier: string(forKeys: ["session_id", "sessionId", "sessionID", "conversation_id", "conversationId"], in: object)
                ?? state.sessionIdentifier,
            recordType: string(forKeys: ["type", "event_type", "eventType", "role"], in: object),
            modelIdentifier: modelIdentifier,
            modelDisplayName: displayName(forModelIdentifier: modelIdentifier),
            providerIdentifier: state.providerIdentifier,
            occurredAt: date(forKeys: ["timestamp", "created_at", "createdAt", "time", "date"], in: object) ?? fallbackTimestamp,
            inputTokens: tokens.input,
            outputTokens: tokens.output,
            cacheReadTokens: tokens.cacheRead,
            cacheWriteTokens: tokens.cacheWrite,
            reasoningTokens: tokens.reasoning,
            costUSD: explicitCost(from: object)
        )
    }

    private static func codexUsageObject(from object: [String: Any]) -> [String: Any]? {
        guard let payload = object["payload"] as? [String: Any] else {
            return object["usage"] as? [String: Any]
        }

        if string(forKeys: ["type"], in: payload) == "token_count",
           let info = payload["info"] as? [String: Any] {
            return (info["last_token_usage"] as? [String: Any])
                ?? (info["total_token_usage"] as? [String: Any])
        }

        if let usage = payload["usage"] as? [String: Any] {
            return usage
        }

        return object["usage"] as? [String: Any]
    }

    private struct TokenCounts {
        var input: Int
        var output: Int
        var cacheRead: Int
        var cacheWrite: Int
        var reasoning: Int

        var hasUsage: Bool {
            input > 0 || output > 0 || cacheRead > 0 || cacheWrite > 0 || reasoning > 0
        }
    }

    private static func tokenCounts(from object: [String: Any]) -> TokenCounts {
        let cache = object["cache"] as? [String: Any]
        return TokenCounts(
            input: number(forKeys: ["input_tokens", "inputTokens", "input", "prompt_tokens", "promptTokens"], in: object) ?? 0,
            output: number(forKeys: ["output_tokens", "outputTokens", "output", "completion_tokens", "completionTokens"], in: object) ?? 0,
            cacheRead: number(forKeys: ["cache_read_input_tokens", "cacheReadInputTokens", "cached_input_tokens", "cachedInputTokens", "cached_tokens", "cachedTokens", "cacheRead"], in: object)
                ?? number(forKeys: ["read"], in: cache as Any)
                ?? 0,
            cacheWrite: number(forKeys: ["cache_creation_input_tokens", "cacheCreationInputTokens", "cache_write_input_tokens", "cacheWriteInputTokens", "cacheWrite"], in: object)
                ?? number(forKeys: ["write"], in: cache as Any)
                ?? 0,
            reasoning: number(forKeys: ["reasoning_output_tokens", "reasoningOutputTokens", "reasoning_tokens", "reasoningTokens", "reasoning"], in: object) ?? 0
        )
    }

    private static func normalizedModelIdentifier(_ value: String?) -> String {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return "unknown"
        }
        return value.lowercased()
    }

    private static func displayName(forModelIdentifier modelIdentifier: String) -> String {
        guard modelIdentifier != "unknown" else {
            return "Unknown"
        }

        return modelIdentifier
            .split(separator: "/")
            .last
            .map(String.init)?
            .replacingOccurrences(of: "-", with: " ")
            .capitalized ?? modelIdentifier
    }

    private static func explicitCost(from object: Any) -> Double? {
        double(forKeys: ["cost", "cost_usd", "costUSD", "estimated_cost_usd", "actual_cost_usd"], in: object)
    }

    private static func string(forKeys keys: [String], in object: Any) -> String? {
        if let direct = search(forKeys: keys, in: object) as? String, !direct.isEmpty {
            return direct
        }
        if let number = search(forKeys: keys, in: object) as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private static func number(forKeys keys: [String], in object: Any) -> Int? {
        guard let value = search(forKeys: keys, in: object) else {
            return nil
        }

        switch value {
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }

    private static func double(forKeys keys: [String], in object: Any) -> Double? {
        guard let value = search(forKeys: keys, in: object) else {
            return nil
        }

        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }

    private static func date(forKeys keys: [String], in object: Any) -> Date? {
        guard let value = search(forKeys: keys, in: object) else {
            return nil
        }

        switch value {
        case let number as NSNumber:
            let seconds = number.doubleValue > 10_000_000_000
                ? number.doubleValue / 1_000
                : number.doubleValue
            return Date(timeIntervalSince1970: seconds)
        case let string as String:
            if let seconds = Double(string) {
                return Date(timeIntervalSince1970: seconds > 10_000_000_000 ? seconds / 1_000 : seconds)
            }

            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: string) {
                return date
            }

            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            return standard.date(from: string)
        default:
            return nil
        }
    }

    private static func search(forKeys keys: [String], in object: Any) -> Any? {
        if let dictionary = object as? [String: Any] {
            for key in keys {
                if let value = dictionary[key] {
                    return value
                }
            }

            for value in dictionary.values {
                if let match = search(forKeys: keys, in: value) {
                    return match
                }
            }
        } else if let array = object as? [Any] {
            for value in array {
                if let match = search(forKeys: keys, in: value) {
                    return match
                }
            }
        }

        return nil
    }
}
