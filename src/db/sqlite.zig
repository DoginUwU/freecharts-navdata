const std = @import("std");
pub const c = @cImport({
    @cInclude("sqlite3.h");
});
const models = @import("../core/models.zig");

const SQLITE_TRANSIENT = @as(c.sqlite3_destructor_type, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));

pub const Database = struct {
    db: *c.sqlite3,
    insert_fix_stmt: *c.sqlite3_stmt,
    insert_airport_stmt: *c.sqlite3_stmt,
    insert_runway_stmt: *c.sqlite3_stmt,
    insert_gate_stmt: *c.sqlite3_stmt,

    xp_upsert_airport_metadata_stmt: *c.sqlite3_stmt,

    pub fn init(db_path: [:0]const u8) !Database {
        var db: ?*c.sqlite3 = null;

        if (c.sqlite3_open(db_path, &db) != c.SQLITE_OK) {
            return error.SQLiteOpenFailed;
        }

        _ = c.sqlite3_exec(db, "PRAGMA synchronous = OFF; PRAGMA journal_mode = MEMORY;", null, null, null);

        var insert_fix_stmt: ?*c.sqlite3_stmt = null;
        var insert_airport_stmt: ?*c.sqlite3_stmt = null;
        var insert_runway_stmt: ?*c.sqlite3_stmt = null;
        var insert_gate_stmt: ?*c.sqlite3_stmt = null;
        var xp_upsert_airport_metadata_stmt: ?*c.sqlite3_stmt = null;

        try Database.assertOk(db.?, c.sqlite3_prepare_v2(db, "INSERT INTO waypoints (ident, lat, lon, airport, region) VALUES (?, ?, ?, ?, ?);", -1, &insert_fix_stmt, null));
        try Database.assertOk(db.?, c.sqlite3_prepare_v2(db, "INSERT INTO airports (icao, name, elevation, lat, lon) VALUES (?, ?, ?, ?, ?);", -1, &insert_airport_stmt, null));
        try Database.assertOk(db.?, c.sqlite3_prepare_v2(db, "INSERT INTO runways (airportIcao, widthMetres, lat, lon, number) VALUES (?, ?, ?, ?, ?);", -1, &insert_runway_stmt, null));
        try Database.assertOk(db.?, c.sqlite3_prepare_v2(db, "INSERT INTO gates (airportIcao, name, lat, lon) VALUES (?, ?, ?, ?);", -1, &insert_gate_stmt, null));
        try Database.assertOk(db.?, c.sqlite3_prepare_v2(db, "INSERT INTO airports (icao, lat, lon) VALUES (?, ?, ?) ON CONFLICT(icao) DO UPDATE SET lat=excluded.lat, lon=excluded.lon;", -1, &xp_upsert_airport_metadata_stmt, null));

        var database = Database{
            .db = db.?,
            .insert_fix_stmt = insert_fix_stmt.?,
            .insert_airport_stmt = insert_airport_stmt.?,
            .insert_runway_stmt = insert_runway_stmt.?,
            .insert_gate_stmt = insert_gate_stmt.?,
            .xp_upsert_airport_metadata_stmt = xp_upsert_airport_metadata_stmt.?,
        };

        try database.deleteDataFromTable("waypoints");
        try database.deleteDataFromTable("airports");
        try database.deleteDataFromTable("runways");
        try database.deleteDataFromTable("gates");

        return database;
    }

    pub fn deinit(self: *Database) void {
        _ = c.sqlite3_finalize(self.insert_fix_stmt);
        _ = c.sqlite3_finalize(self.insert_airport_stmt);
        _ = c.sqlite3_finalize(self.insert_runway_stmt);
        _ = c.sqlite3_finalize(self.insert_gate_stmt);
        _ = c.sqlite3_finalize(self.xp_upsert_airport_metadata_stmt);

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

        const stepResult = c.sqlite3_step(stmt);
        try Database.assertDone(self.db, stepResult);
    }

    pub fn insertAirportRecord(self: *Database, record: models.AirportRecord) !void {
        switch (record) {
            .airport => |apt| {
                const stmt = self.insert_airport_stmt;

                _ = c.sqlite3_reset(stmt);
                _ = c.sqlite3_clear_bindings(stmt);

                _ = c.sqlite3_bind_text(stmt, 1, apt.icao.ptr, @intCast(apt.icao.len), SQLITE_TRANSIENT);
                _ = c.sqlite3_bind_text(stmt, 2, apt.name.ptr, @intCast(apt.name.len), SQLITE_TRANSIENT);
                _ = c.sqlite3_bind_int(stmt, 3, apt.elevation);
                _ = c.sqlite3_bind_double(stmt, 4, 0.0);
                _ = c.sqlite3_bind_double(stmt, 5, 0.0);

                const stepResult = c.sqlite3_step(stmt);
                try Database.assertDone(self.db, stepResult);
            },
            .runways => |rwys| {
                const stmt = self.insert_runway_stmt;

                for (rwys) |rwy| {
                    _ = c.sqlite3_reset(stmt);
                    _ = c.sqlite3_clear_bindings(stmt);

                    _ = c.sqlite3_bind_text(stmt, 1, rwy.airport_icao.ptr, @intCast(rwy.airport_icao.len), SQLITE_TRANSIENT);
                    _ = c.sqlite3_bind_double(stmt, 2, rwy.width);
                    _ = c.sqlite3_bind_double(stmt, 3, rwy.lat);
                    _ = c.sqlite3_bind_double(stmt, 4, rwy.lon);
                    _ = c.sqlite3_bind_text(stmt, 5, rwy.number.ptr, @intCast(rwy.number.len), SQLITE_TRANSIENT);

                    const stepResult = c.sqlite3_step(stmt);
                    try Database.assertDone(self.db, stepResult);
                }
            },
            .gates => |gates| {
                const stmt = self.insert_gate_stmt;

                for (gates) |gate| {
                    _ = c.sqlite3_reset(stmt);
                    _ = c.sqlite3_clear_bindings(stmt);

                    _ = c.sqlite3_bind_text(stmt, 1, gate.airport_icao.ptr, @intCast(gate.airport_icao.len), SQLITE_TRANSIENT);
                    _ = c.sqlite3_bind_text(stmt, 2, gate.name.ptr, @intCast(gate.name.len), SQLITE_TRANSIENT);
                    _ = c.sqlite3_bind_double(stmt, 3, gate.lat);
                    _ = c.sqlite3_bind_double(stmt, 4, gate.lon);

                    const stepResult = c.sqlite3_step(stmt);
                    try Database.assertDone(self.db, stepResult);
                }
            },
            .xp_airport_metadata => |meta| {
                const stmt = self.xp_upsert_airport_metadata_stmt;

                _ = c.sqlite3_reset(stmt);
                _ = c.sqlite3_clear_bindings(stmt);

                _ = c.sqlite3_bind_text(stmt, 1, meta.icao.ptr, @intCast(meta.icao.len), SQLITE_TRANSIENT);
                _ = c.sqlite3_bind_double(stmt, 2, meta.lat);
                _ = c.sqlite3_bind_double(stmt, 3, meta.lon);

                const stepResult = c.sqlite3_step(stmt);
                try Database.assertDone(self.db, stepResult);
            },
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

    fn assertOk(db: *c.sqlite3, result: c_int) !void {
        if (result != c.SQLITE_OK) {
            const errMsg = c.sqlite3_errmsg(db);
            std.debug.print("SQLite error: {s}\n", .{errMsg});
            return error.SQLiteOperationFailed;
        }
    }

    fn assertDone(db: *c.sqlite3, result: c_int) !void {
        if (result != c.SQLITE_DONE) {
            const errMsg = c.sqlite3_errmsg(db);
            std.debug.print("SQLite error: {s}\n", .{errMsg});
            return error.SQLiteOperationFailed;
        }
    }
};
