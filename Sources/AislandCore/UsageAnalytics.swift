import Foundation
import SQLite3

public enum UsageLogProvider: String, Codable, Sendable, CaseIterable {
    case claude
    case codex

    public var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
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
    public var totalTokens: Int
    public var entryCount: Int
    public var sourceFileCount: Int
    public var firstSeenAt: Date?
    public var lastSeenAt: Date?

    public init(
        inputTokens: Int,
        outputTokens: Int,
        totalTokens: Int,
        entryCount: Int,
        sourceFileCount: Int,
        firstSeenAt: Date?,
        lastSeenAt: Date?
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
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
    public var totalTokens: Int
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
        totalTokens: Int,
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
        self.totalTokens = totalTokens
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
    public var totalTokens: Int
    public var entryCount: Int
    public var sourceFileCount: Int
    public var firstSeenAt: Date?
    public var lastSeenAt: Date?

    public init(
        provider: UsageLogProvider,
        inputTokens: Int,
        outputTokens: Int,
        totalTokens: Int,
        entryCount: Int,
        sourceFileCount: Int,
        firstSeenAt: Date?,
        lastSeenAt: Date?
    ) {
        self.provider = provider
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.entryCount = entryCount
        self.sourceFileCount = sourceFileCount
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
    }

    public var id: String {
        provider.rawValue
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
    public var occurredAt: Date
    public var inputTokens: Int
    public var outputTokens: Int

    public init(
        provider: UsageLogProvider,
        sourceFilePath: String,
        lineIndex: Int,
        sessionIdentifier: String?,
        recordType: String?,
        occurredAt: Date,
        inputTokens: Int,
        outputTokens: Int
    ) {
        self.provider = provider
        self.sourceFilePath = sourceFilePath
        self.lineIndex = lineIndex
        self.sessionIdentifier = sessionIdentifier
        self.recordType = recordType
        self.occurredAt = occurredAt
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    public var totalTokens: Int {
        inputTokens + outputTokens
    }
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
                    let metadata = try file.url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                    let modifiedAt = metadata.contentModificationDate ?? .distantPast
                    let fileSize = Int64(metadata.fileSize ?? 0)
                    if try isUnchanged(filePath: file.url.path, modifiedAt: modifiedAt, fileSize: fileSize, db: db) {
                        continue
                    }

                    let entries = try parseEntries(in: file.url, provider: file.provider)
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
                guard fileURL.pathExtension == "jsonl" else {
                    continue
                }

                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
                guard values?.isRegularFile == true else {
                    continue
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

        var result: [UsageAnalyticsRecord] = []
        let fallbackTimestamp = try fileTimestamp(for: fileURL) ?? .now
        var lineIndex = 0

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
                fallbackTimestamp: fallbackTimestamp
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
            (provider, source_file_path, line_index, session_identifier, record_type, occurred_at, input_tokens, output_tokens, total_tokens)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
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
                sqlite3_bind_double(stmt, 6, entry.occurredAt.timeIntervalSince1970)
                sqlite3_bind_int64(stmt, 7, sqlite3_int64(entry.inputTokens))
                sqlite3_bind_int64(stmt, 8, sqlite3_int64(entry.outputTokens))
                sqlite3_bind_int64(stmt, 9, sqlite3_int64(entry.totalTokens))

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
            COALESCE(SUM(total_tokens), 0),
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
                    totalTokens: 0,
                    entryCount: 0,
                    sourceFileCount: 0,
                    firstSeenAt: nil,
                    lastSeenAt: nil
                )
            }

            return UsageAnalyticsTotals(
                inputTokens: Int(sqlite3_column_int64(stmt, 0)),
                outputTokens: Int(sqlite3_column_int64(stmt, 1)),
                totalTokens: Int(sqlite3_column_int64(stmt, 2)),
                entryCount: Int(sqlite3_column_int64(stmt, 3)),
                sourceFileCount: Int(sqlite3_column_int64(stmt, 4)),
                firstSeenAt: Self.date(fromSQLColumnAt: 5, in: stmt),
                lastSeenAt: Self.date(fromSQLColumnAt: 6, in: stmt)
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
            COALESCE(SUM(total_tokens), 0),
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
                        totalTokens: Int(sqlite3_column_int64(stmt, 3)),
                        entryCount: Int(sqlite3_column_int64(stmt, 4)),
                        sourceFileCount: Int(sqlite3_column_int64(stmt, 5)),
                        firstSeenAt: Self.date(fromSQLColumnAt: 6, in: stmt),
                        lastSeenAt: Self.date(fromSQLColumnAt: 7, in: stmt)
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
        var totalTokens: Int
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
            COALESCE(SUM(total_tokens), 0) AS total_tokens,
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
                let totalTokens = Int(sqlite3_column_int64(stmt, 3))
                let entryCount = Int(sqlite3_column_int64(stmt, 4))
                let sourceFileCount = Int(sqlite3_column_int64(stmt, 5))
                let firstSeenAt = Self.date(fromSQLColumnAt: 6, in: stmt)
                let lastSeenAt = Self.date(fromSQLColumnAt: 7, in: stmt)

                var provider: UsageLogProvider?
                var sourceFilePath = bucketKey

                if includeProvider {
                    provider = Self.provider(fromSQLColumnAt: 8, in: stmt)
                    sourceFilePath = Self.string(fromSQLColumnAt: 9, in: stmt) ?? bucketKey
                } else {
                    sourceFilePath = Self.string(fromSQLColumnAt: 8, in: stmt) ?? bucketKey
                }

                let row = BucketRow(
                    bucketKey: bucketKey,
                    provider: provider,
                    sourceFilePath: sourceFilePath,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    totalTokens: totalTokens,
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
                            totalTokens: totalTokens,
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
            occurred_at REAL NOT NULL,
            input_tokens INTEGER NOT NULL,
            output_tokens INTEGER NOT NULL,
            total_tokens INTEGER NOT NULL,
            UNIQUE(source_file_path, line_index)
        );
        """)

        try execute(db, sql: "CREATE INDEX IF NOT EXISTS usage_samples_occurred_at_index ON usage_samples(occurred_at);")
        try execute(db, sql: "CREATE INDEX IF NOT EXISTS usage_samples_session_index ON usage_samples(provider, session_identifier);")
        try execute(db, sql: "CREATE INDEX IF NOT EXISTS usage_samples_source_index ON usage_samples(source_file_path);")
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

    private static func record(
        from object: [String: Any],
        provider: UsageLogProvider,
        sourceFilePath: String,
        lineIndex: Int,
        fallbackTimestamp: Date
    ) -> UsageAnalyticsRecord? {
        let inputTokens = number(
            forKeys: ["input_tokens", "inputTokens"],
            in: object
        )
        let outputTokens = number(
            forKeys: ["output_tokens", "outputTokens"],
            in: object
        )

        guard inputTokens != nil || outputTokens != nil else {
            return nil
        }

        let sessionIdentifier = string(
            forKeys: ["session_id", "sessionId", "sessionID", "conversation_id", "conversationId"],
            in: object
        )
        let recordType = string(forKeys: ["type", "event_type", "eventType", "role"], in: object)
        let occurredAt = date(
            forKeys: ["timestamp", "created_at", "createdAt", "time", "date"],
            in: object
        ) ?? fallbackTimestamp

        return UsageAnalyticsRecord(
            provider: provider,
            sourceFilePath: sourceFilePath,
            lineIndex: lineIndex,
            sessionIdentifier: sessionIdentifier,
            recordType: recordType,
            occurredAt: occurredAt,
            inputTokens: inputTokens ?? 0,
            outputTokens: outputTokens ?? 0
        )
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

    private static func date(forKeys keys: [String], in object: Any) -> Date? {
        guard let value = search(forKeys: keys, in: object) else {
            return nil
        }

        switch value {
        case let number as NSNumber:
            return Date(timeIntervalSince1970: number.doubleValue)
        case let string as String:
            if let seconds = Double(string) {
                return Date(timeIntervalSince1970: seconds)
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
