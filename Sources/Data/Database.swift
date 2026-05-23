// Database.swift
// A thin, dependency-free wrapper over the system SQLite3 C library. Provides
// statement preparation, positional binding, row stepping, and the
// PRAGMA user_version accessor used by the migration runner.

import Foundation
import SQLite3

/// SQLite tells callers whether bound text/blob memory is transient (must be
/// copied) — we always pass transient since Swift Strings are short-lived here.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum DatabaseError: Error, CustomStringConvertible {
    case open(String)
    case prepare(String)
    case step(String)

    var description: String {
        switch self {
        case .open(let m): return "SQLite open failed: \(m)"
        case .prepare(let m): return "SQLite prepare failed: \(m)"
        case .step(let m): return "SQLite step failed: \(m)"
        }
    }
}

/// An open connection to a SQLite database file.
final class Database {
    private var handle: OpaquePointer?

    init(path: String) throws {
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(handle)
            throw DatabaseError.open(message)
        }
        sqlite3_exec(handle, "PRAGMA foreign_keys = ON;", nil, nil, nil)
    }

    deinit { sqlite3_close(handle) }

    /// Run one or more statements with no result rows.
    func execute(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(handle, sql, nil, nil, &errorPointer) == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(errorPointer)
            throw DatabaseError.step(message)
        }
    }

    /// Prepare a statement for binding/stepping.
    func prepare(_ sql: String) throws -> Statement {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        return Statement(handle: stmt, db: handle)
    }

    /// Schema version stored in the file (PRAGMA user_version).
    var userVersion: Int {
        get {
            guard let stmt = try? prepare("PRAGMA user_version;") else { return 0 }
            defer { stmt.finalize() }
            return stmt.step() ? (stmt.int(0) ?? 0) : 0
        }
        set { try? execute("PRAGMA user_version = \(newValue);") }
    }

    /// Run `body` inside a transaction, rolling back on throw.
    func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN;")
        do {
            try body()
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }
}

/// A prepared SQLite statement. Bind by 1-based index, step to read rows.
final class Statement {
    private let handle: OpaquePointer?
    private let db: OpaquePointer?

    init(handle: OpaquePointer?, db: OpaquePointer?) {
        self.handle = handle
        self.db = db
    }

    deinit { sqlite3_finalize(handle) }

    func finalize() { /* deinit finalizes; kept for explicit defer readability */ }

    // MARK: Binding

    @discardableResult
    func bind(_ index: Int32, _ value: String?) -> Statement {
        if let value { sqlite3_bind_text(handle, index, value, -1, SQLITE_TRANSIENT) }
        else { sqlite3_bind_null(handle, index) }
        return self
    }

    @discardableResult
    func bind(_ index: Int32, _ value: Int?) -> Statement {
        if let value { sqlite3_bind_int64(handle, index, Int64(value)) }
        else { sqlite3_bind_null(handle, index) }
        return self
    }

    @discardableResult
    func bind(_ index: Int32, _ value: Double?) -> Statement {
        if let value { sqlite3_bind_double(handle, index, value) }
        else { sqlite3_bind_null(handle, index) }
        return self
    }

    // MARK: Stepping & reading

    /// Advance to the next row. Returns true while a row is available.
    @discardableResult
    func step() -> Bool {
        sqlite3_step(handle) == SQLITE_ROW
    }

    /// Run a statement expected to return no rows (INSERT/UPDATE/DELETE).
    func run() throws {
        guard sqlite3_step(handle) == SQLITE_DONE else {
            throw DatabaseError.step(db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown")
        }
    }

    func text(_ column: Int32) -> String? {
        guard sqlite3_column_type(handle, column) != SQLITE_NULL,
              let cString = sqlite3_column_text(handle, column) else { return nil }
        return String(cString: cString)
    }

    func int(_ column: Int32) -> Int? {
        guard sqlite3_column_type(handle, column) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int64(handle, column))
    }

    func double(_ column: Int32) -> Double? {
        guard sqlite3_column_type(handle, column) != SQLITE_NULL else { return nil }
        return sqlite3_column_double(handle, column)
    }
}
