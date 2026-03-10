const std = @import("std");
pub const c = @cImport({
    @cInclude("sqlite3.h");
});
const models = @import("../core/models.zig");
const math = @import("../core/math.zig");

const SQLITE_TRANSIENT = @as(c.sqlite3_destructor_type, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));

pub const Database = struct {
    db: *c.sqlite3,
    insert_fix_stmt: *c.sqlite3_stmt,
    insert_airport_stmt: *c.sqlite3_stmt,
    insert_runway_stmt: *c.sqlite3_stmt,
    insert_gate_stmt: *c.sqlite3_stmt,
    insert_airway_stmt: *c.sqlite3_stmt,
    insert_procedure_stmt: *c.sqlite3_stmt,
    insert_navaid_stmt: *c.sqlite3_stmt,

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
        var insert_airway_stmt: ?*c.sqlite3_stmt = null;
        var insert_procedure_stmt: ?*c.sqlite3_stmt = null;
        var insert_navaid_stmt: ?*c.sqlite3_stmt = null;

        var xp_upsert_airport_metadata_stmt: ?*c.sqlite3_stmt = null;

        try Database.assertOk(db.?, c.sqlite3_prepare_v2(db, "INSERT INTO fixes (ident, lat, lon, airport, region) VALUES (?, ?, ?, ?, ?);", -1, &insert_fix_stmt, null));
        try Database.assertOk(db.?, c.sqlite3_prepare_v2(db, "INSERT INTO airports (icao, name, elevation, lat, lon) VALUES (?, ?, ?, ?, ?);", -1, &insert_airport_stmt, null));
        try Database.assertOk(db.?, c.sqlite3_prepare_v2(db, "INSERT INTO runways (airportIcao, widthMetres, lat, lon, number) VALUES (?, ?, ?, ?, ?);", -1, &insert_runway_stmt, null));
        try Database.assertOk(db.?, c.sqlite3_prepare_v2(db, "INSERT INTO gates (airportIcao, name, lat, lon) VALUES (?, ?, ?, ?);", -1, &insert_gate_stmt, null));
        try Database.assertOk(db.?, c.sqlite3_prepare_v2(db, "INSERT INTO airways (fromIdent, fromLat, fromLon, fromType, fromRegion, toIdent, toLat, toLon, toType, toRegion, airwayName, directionRestriction, level, baseAltitude, topAltitude, distanceNm) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);", -1, &insert_airway_stmt, null));
        try Database.assertOk(db.?, c.sqlite3_prepare_v2(db, "INSERT INTO procedure_legs (icao, procName, transitionIdent, fixIdent, legType, type, sequence) VALUES (?, ?, ?, ?, ?, ?, ?);", -1, &insert_procedure_stmt, null));
        try Database.assertOk(db.?, c.sqlite3_prepare_v2(db, "INSERT INTO navaids (ident, type, lat, lon, frequency, region, name) VALUES (?, ?, ?, ?, ?, ?, ?);", -1, &insert_navaid_stmt, null));

        try Database.assertOk(db.?, c.sqlite3_prepare_v2(db, "INSERT INTO airports (icao, lat, lon) VALUES (?, ?, ?) ON CONFLICT(icao) DO UPDATE SET lat=excluded.lat, lon=excluded.lon;", -1, &xp_upsert_airport_metadata_stmt, null));

        var database = Database{
            .db = db.?,
            .insert_fix_stmt = insert_fix_stmt.?,
            .insert_airport_stmt = insert_airport_stmt.?,
            .insert_runway_stmt = insert_runway_stmt.?,
            .insert_gate_stmt = insert_gate_stmt.?,
            .insert_airway_stmt = insert_airway_stmt.?,
            .insert_procedure_stmt = insert_procedure_stmt.?,
            .insert_navaid_stmt = insert_navaid_stmt.?,

            .xp_upsert_airport_metadata_stmt = xp_upsert_airport_metadata_stmt.?,
        };

        try database.deleteDataFromTable("fixes");
        try database.deleteDataFromTable("navaids");
        try database.deleteDataFromTable("airports");
        try database.deleteDataFromTable("runways");
        try database.deleteDataFromTable("gates");
        try database.deleteDataFromTable("airways");
        try database.deleteDataFromTable("procedure_legs");

        return database;
    }

    pub fn deinit(self: *Database) void {
        _ = c.sqlite3_finalize(self.insert_fix_stmt);
        _ = c.sqlite3_finalize(self.insert_airport_stmt);
        _ = c.sqlite3_finalize(self.insert_runway_stmt);
        _ = c.sqlite3_finalize(self.insert_gate_stmt);
        _ = c.sqlite3_finalize(self.insert_airway_stmt);
        _ = c.sqlite3_finalize(self.xp_upsert_airport_metadata_stmt);
        _ = c.sqlite3_finalize(self.insert_procedure_stmt);
        _ = c.sqlite3_finalize(self.insert_navaid_stmt);

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

        if (fix.lat == 0.0 and fix.lon == 0.0) {
            std.debug.print("Fix insert skipped: zero coordinates for '{s}'\n", .{fix.ident});
            return;
        }

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

    fn lookupCoords(self: *Database, ident: []const u8, region: []const u8, airway_type: models.AirwayFixNavaidType) !?[2]f64 {
        const query = switch (airway_type) {
            .FIX => "SELECT lat, lon FROM fixes WHERE ident = ? AND region = ? LIMIT 1;",
            .VOR, .NDB => "SELECT lat, lon FROM navaids WHERE ident = ? AND region = ? AND type = ? LIMIT 1;",
        };

        var stmt: ?*c.sqlite3_stmt = null;
        try Database.assertOk(self.db, c.sqlite3_prepare_v2(self.db, query, -1, &stmt, null));
        defer _ = c.sqlite3_finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, ident.ptr, @intCast(ident.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_text(stmt, 2, region.ptr, @intCast(region.len), SQLITE_TRANSIENT);

        if (airway_type != .FIX) {
            const type_str = if (airway_type == .VOR) "VOR" else "NDB";
            _ = c.sqlite3_bind_text(stmt, 3, type_str.ptr, @intCast(type_str.len), SQLITE_TRANSIENT);
        }

        if (c.sqlite3_step(stmt) != c.SQLITE_ROW) return null;

        return .{ c.sqlite3_column_double(stmt, 0), c.sqlite3_column_double(stmt, 1) };
    }

    pub fn insertNavaid(self: *Database, navaid: models.Navaid) !void {
        const stmt = self.insert_navaid_stmt;

        if (navaid.lat == 0.0 and navaid.lon == 0.0) {
            std.debug.print("Navaid insert skipped: zero coordinates for '{s}'\n", .{navaid.ident});
            return;
        }

        _ = c.sqlite3_reset(stmt);
        _ = c.sqlite3_clear_bindings(stmt);

        const navaid_type = @tagName(navaid.type);
        _ = c.sqlite3_bind_text(stmt, 1, navaid.ident.ptr, @intCast(navaid.ident.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_text(stmt, 2, navaid_type, @intCast(navaid_type.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_double(stmt, 3, navaid.lat);
        _ = c.sqlite3_bind_double(stmt, 4, navaid.lon);
        _ = c.sqlite3_bind_int(stmt, 5, navaid.frequency);
        _ = c.sqlite3_bind_text(stmt, 6, navaid.region.ptr, @intCast(navaid.region.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_text(stmt, 7, navaid.name.ptr, @intCast(navaid.name.len), SQLITE_TRANSIENT);

        const stepResult = c.sqlite3_step(stmt);
        try Database.assertDone(self.db, stepResult);
    }

    pub fn insertAirway(self: *Database, airway: models.Airway) !void {
        const from_coords = try self.lookupCoords(airway.from_ident, airway.from_region, airway.from_type) orelse {
            std.debug.print("FROM Airway insert skipped: fix/navaid '{s}' not found region '{s}' type {s}\n", .{ airway.from_ident, airway.from_region, @tagName(airway.from_type) });
            return;
        };
        const to_coords = try self.lookupCoords(airway.to_ident, airway.to_region, airway.to_type) orelse {
            std.debug.print("TO Airway insert skipped: fix/navaid '{s}' not found region '{s}' type {s}\n", .{ airway.to_ident, airway.to_region, @tagName(airway.to_type) });
            return;
        };

        const distance_nm = math.haversineDistance(from_coords[0], from_coords[1], to_coords[0], to_coords[1]);

        if (distance_nm <= 0.0 or !std.math.isFinite(distance_nm)) {
            std.debug.print("Airway insert skipped: zero or negative distance between '{s}' and '{s}'\n", .{ airway.from_ident, airway.to_ident });
            return;
        }

        const stmt = self.insert_airway_stmt;
        _ = c.sqlite3_reset(stmt);
        _ = c.sqlite3_clear_bindings(stmt);

        const from_type_str = @tagName(airway.from_type);
        const to_type_str = @tagName(airway.to_type);
        const direction_str = @tagName(airway.direction_restriction);

        _ = c.sqlite3_bind_text(stmt, 1, airway.from_ident.ptr, @intCast(airway.from_ident.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_double(stmt, 2, from_coords[0]);
        _ = c.sqlite3_bind_double(stmt, 3, from_coords[1]);
        _ = c.sqlite3_bind_text(stmt, 4, from_type_str, @intCast(from_type_str.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_text(stmt, 5, airway.from_region.ptr, @intCast(airway.from_region.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_text(stmt, 6, airway.to_ident.ptr, @intCast(airway.to_ident.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_double(stmt, 7, to_coords[0]);
        _ = c.sqlite3_bind_double(stmt, 8, to_coords[1]);
        _ = c.sqlite3_bind_text(stmt, 9, to_type_str, @intCast(to_type_str.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_text(stmt, 10, airway.to_region.ptr, @intCast(airway.to_region.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_text(stmt, 11, airway.airway_name.ptr, @intCast(airway.airway_name.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_text(stmt, 12, direction_str, @intCast(direction_str.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_int(stmt, 13, @intFromEnum(airway.level));
        _ = c.sqlite3_bind_int(stmt, 14, airway.base_altitude);
        _ = c.sqlite3_bind_int(stmt, 15, airway.top_altitude);
        _ = c.sqlite3_bind_double(stmt, 16, distance_nm);

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

    pub fn insertProcedure(self: *Database, proc: models.ProcedureLeg) !void {
        const stmt = self.insert_procedure_stmt;

        _ = c.sqlite3_reset(stmt);
        _ = c.sqlite3_clear_bindings(stmt);

        const proc_type = @tagName(proc.type);

        _ = c.sqlite3_bind_text(stmt, 1, proc.icao.ptr, @intCast(proc.icao.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_text(stmt, 2, proc.proc_name.ptr, @intCast(proc.proc_name.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_text(stmt, 3, proc.transition_ident.ptr, @intCast(proc.transition_ident.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_text(stmt, 4, proc.fix_ident.ptr, @intCast(proc.fix_ident.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_text(stmt, 5, proc.leg_type.ptr, @intCast(proc.leg_type.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_text(stmt, 6, proc_type, @intCast(proc_type.len), SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_int(stmt, 7, @intCast(proc.sequence));

        const stepResult = c.sqlite3_step(stmt);
        try Database.assertDone(self.db, stepResult);
    }

    pub fn computeAirportsRanks(self: *Database) !void {
        const sql =
            \\ UPDATE airports
            \\ SET rank = (
            \\  SELECT (COUNT(DISTINCT r.id) * 10 + COUNT(DISTINCT g.id) * 2)
            \\  FROM runways r
            \\  LEFT JOIN gates g ON g.airportIcao = r.airportIcao
            \\  WHERE r.airportIcao = airports.icao
            \\ );
        ;
        if (c.sqlite3_exec(self.db, sql, null, null, null) != c.SQLITE_OK) {
            const errMsg = c.sqlite3_errmsg(self.db);
            std.debug.print("SQLite error during compute ranks: {s}\n", .{errMsg});
            return error.SQLiteComputeRanksFailed;
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
