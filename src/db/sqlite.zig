const std = @import("std");
pub const c = @cImport({
    @cInclude("sqlite3.h");
});

pub const Database = struct {
    db: *c.sqlite3,
    insert_fix_stmt: *c.sqlite3_stmt,

    pub fn init(db_path: [:0]const u8) !Database {
        var db: ?*c.sqlite3 = null;

        if (c.sqlite3_open(db_path, &db) != c.SQLITE_OK) {
            return error.SQLiteOpenFailed;
        }

        _ = c.sqlite3_exec(db, "PRAGMA synchronous = OFF; PRAGMA journal_mode = MEMORY;", null, null, null);

        var insert_fix_stmt: ?*c.sqlite3_stmt = null;
        const insert_sql = "INSERT INTO waypoints (ident, lat, lon, airport, region) VALUES (?, ?, ?, ?, ?);";
        if (c.sqlite3_prepare_v2(db, insert_sql, -1, &insert_fix_stmt, null) != c.SQLITE_OK) {
            return error.SQLitePrepareFailed;
        }

        return Database{
            .db = db.?,
            .insert_fix_stmt = insert_fix_stmt.?,
        };
    }

    pub fn deinit(self: *Database) void {
        _ = c.sqlite3_finalize(self.insert_fix_stmt);
        _ = c.sqlite3_close(self.db);
    }

    pub fn beginTransaction(self: *Database) !void {
        if (c.sqlite3_exec(self.db, "BEGIN TRANSACTION;", null, null, null) != c.SQLITE_OK) {
            return error.SQLiteBeginTxFailed;
        }
    }

    pub fn commitTransaction(self: *Database) !void {
        if (c.sqlite3_exec(self.db, "COMMIT;", null, null, null) != c.SQLITE_OK) {
            return error.SQLiteCommitFailed;
        }
    }
};
