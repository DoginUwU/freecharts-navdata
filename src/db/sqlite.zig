const std = @import("std");
pub const c = @cImport({
    @cInclude("sqlite3.h");
});
const models = @import("../core/models.zig");

const SQLITE_TRANSIENT = @as(c.sqlite3_destructor_type, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));

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

        var database = Database{
            .db = db.?,
            .insert_fix_stmt = insert_fix_stmt.?,
        };

        try database.deleteDataFromTable("waypoints");

        return database;
    }

    pub fn deinit(self: *Database) void {
        _ = c.sqlite3_finalize(self.insert_fix_stmt);
        _ = c.sqlite3_close(self.db);
    }

    pub fn beginTransaction(self: *Database) !void {
        if (c.sqlite3_exec(self.db, "BEGIN TRANSACTION;", null, null, null) != c.SQLITE_OK) {
            const errMsg = c.sqlite3_errmsg(self.db);
            std.debug.print("SQLite error during transaction begin: {s}\n", .{errMsg});
            return error.SQLiteBeginTxFailed;
        }
    }

    pub fn commitTransaction(self: *Database) !void {
        if (c.sqlite3_exec(self.db, "COMMIT;", null, null, null) != c.SQLITE_OK) {
            const errMsg = c.sqlite3_errmsg(self.db);
            std.debug.print("SQLite error during commit: {s}\n", .{errMsg});
            return error.SQLiteCommitFailed;
        }
    }

    pub fn insertFix(self: *Database, fix: models.Fix) !void {
        const stmt = self.insert_fix_stmt;

        _ = c.sqlite3_reset(stmt);
        _ = c.sqlite3_clear_bindings(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, fix.ident.ptr, @intCast(fix.ident.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_double(stmt, 2, fix.lat);
        _ = c.sqlite3_bind_double(stmt, 3, fix.lon);
        _ = c.sqlite3_bind_text(stmt, 4, fix.airport.ptr, @intCast(fix.airport.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_text(stmt, 5, fix.region.ptr, @intCast(fix.region.len), SQLITE_TRANSIENT);

        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
            const errMsg = c.sqlite3_errmsg(self.db);
            std.debug.print("SQLite error: {s}\n", .{errMsg});
            std.debug.print("Failed to insert fix: {}\n", .{fix});
            return error.SQLiteStepFailed;
        }
    }

    fn deleteDataFromTable(self: *Database, tableName: [:0]const u8) !void {
        var buffer: [256]u8 = undefined;

        const query = try std.fmt.bufPrintZ(
            &buffer,
            "DELETE FROM {s};",
            .{tableName},
        );

        if (c.sqlite3_exec(self.db, query, null, null, null) != c.SQLITE_OK) {
            const errMsg = c.sqlite3_errmsg(self.db);
            std.debug.print("SQLite error during delete from {s}: {s}\n", .{ tableName, errMsg });
            return error.SQLiteDeleteFailed;
        }
    }
};
