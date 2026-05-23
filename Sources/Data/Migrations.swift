// Migrations.swift
// Versioned schema migrations driven by PRAGMA user_version. Each bump adds a
// numbered step; the runner applies every step above the file's current version
// inside a transaction. Add a new `v<N>` and bump `latestVersion` for changes —
// never edit a shipped step (per the project's no-destructive-data rule).

import Foundation

enum Migrations {
    /// The schema version this build expects.
    static let latestVersion = 1

    /// Apply any pending migrations to bring `db` up to `latestVersion`.
    static func migrate(_ db: Database) throws {
        var version = db.userVersion
        guard version < latestVersion else { return }

        try db.transaction {
            if version < 1 {
                try v1(db)
                version = 1
            }
            // Future: if version < 2 { try v2(db); version = 2 }
        }
        db.userVersion = latestVersion
    }

    /// v1 — initial folders + tasks schema.
    private static func v1(_ db: Database) throws {
        try db.execute("""
        CREATE TABLE folders (
            id          TEXT PRIMARY KEY,
            name        TEXT NOT NULL,
            parent_id   TEXT,
            color_l     REAL NOT NULL,
            color_c     REAL NOT NULL,
            color_h     REAL NOT NULL,
            is_system   INTEGER NOT NULL DEFAULT 0,
            sort_order  INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE tasks (
            id              TEXT PRIMARY KEY,
            title           TEXT NOT NULL,
            folder_id       TEXT NOT NULL,
            due             REAL,
            effort_minutes  INTEGER,
            impact          INTEGER NOT NULL,
            priority        INTEGER NOT NULL,
            state           TEXT NOT NULL,
            notes           TEXT,
            snoozed_until   REAL,
            created_at      REAL NOT NULL,
            sort_order      INTEGER NOT NULL DEFAULT 0
        );

        CREATE INDEX idx_tasks_folder ON tasks(folder_id);
        """)
    }
}
