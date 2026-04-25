import Foundation
import SQLite3

struct TemporaryChatStoredConfiguration: Equatable, Sendable {
    var provider: LLMProviderKind
    var model: String
    var baseURL: String
}

struct TemporaryChatConfigurationStore: Sendable {
    static let defaultDatabaseURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/aisland/app.sqlite")

    var databaseURL: URL

    init(databaseURL: URL = Self.defaultDatabaseURL) {
        self.databaseURL = databaseURL
    }

    func loadConfiguration() throws -> TemporaryChatStoredConfiguration? {
        try withDatabase { db in
            try ensureSchema(db)
            return try withPreparedStatement(
                db,
                sql: "SELECT provider, model, base_url FROM temporary_chat_configuration WHERE id = 1 LIMIT 1;"
            ) { stmt in
                guard sqlite3_step(stmt) == SQLITE_ROW else {
                    return nil
                }

                let providerRaw = Self.string(fromSQLColumnAt: 0, in: stmt) ?? ""
                let provider = LLMProviderKind(rawValue: providerRaw) ?? .openAI
                return TemporaryChatStoredConfiguration(
                    provider: provider,
                    model: Self.string(fromSQLColumnAt: 1, in: stmt) ?? provider.defaultModel,
                    baseURL: Self.string(fromSQLColumnAt: 2, in: stmt) ?? provider.defaultBaseURL
                )
            }
        }
    }

    func saveConfiguration(_ configuration: TemporaryChatStoredConfiguration) throws {
        try withDatabase { db in
            try ensureSchema(db)
            try withPreparedStatement(
                db,
                sql: """
                INSERT INTO temporary_chat_configuration (id, provider, model, base_url, updated_at)
                VALUES (1, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    provider = excluded.provider,
                    model = excluded.model,
                    base_url = excluded.base_url,
                    updated_at = excluded.updated_at;
                """
            ) { stmt in
                try bindText(configuration.provider.rawValue, to: stmt, index: 1)
                try bindText(configuration.model, to: stmt, index: 2)
                try bindText(configuration.baseURL, to: stmt, index: 3)
                sqlite3_bind_double(stmt, 4, Date.now.timeIntervalSince1970)

                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw sqliteError(db, operation: "save temporary chat configuration")
                }
            }
        }
    }

    private func withDatabase<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        try FileManager.default.createDirectory(
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
        CREATE TABLE IF NOT EXISTS temporary_chat_configuration (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            provider TEXT NOT NULL,
            model TEXT NOT NULL,
            base_url TEXT NOT NULL,
            updated_at REAL NOT NULL
        );
        """)
    }

    private func execute(_ db: OpaquePointer, sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            defer { sqlite3_free(errorMessage) }
            let message = errorMessage.flatMap { String(cString: $0) } ?? "unknown sqlite error"
            throw NSError(domain: "TemporaryChatConfigurationStore", code: Int(sqlite3_errcode(db)), userInfo: [
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

    private func sqliteError(_ db: OpaquePointer?, operation: String) -> NSError {
        let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown sqlite error"
        return NSError(domain: "TemporaryChatConfigurationStore", code: Int(db.map { sqlite3_errcode($0) } ?? SQLITE_ERROR), userInfo: [
            NSLocalizedDescriptionKey: "SQLite error while trying to \(operation): \(message)"
        ])
    }

    private static func string(fromSQLColumnAt index: Int32, in stmt: OpaquePointer) -> String? {
        guard let cString = sqlite3_column_text(stmt, index) else {
            return nil
        }
        return String(cString: cString)
    }
}
