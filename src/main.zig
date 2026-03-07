const std = @import("std");
const xp_reader = @import("./parsers/xplane/reader.zig");
const xp_fix = @import("./parsers/xplane/fix.zig");

const Fix = @import("./core/models.zig").Fix;

const sqlite = @import("./db/sqlite.zig");

fn saveFixToDatabase(fix: Fix) !void {
    std.debug.print("[FIX] {s} ({d}, {d})\n", .{ fix.ident, fix.lat, fix.lon });
}

pub fn main() !void {
    var db = try sqlite.Database.init("navdata.db");
    defer db.deinit();

    try xp_reader.processDatFile(Fix, "mock/earth_fix.dat", xp_fix.parseLine, saveFixToDatabase);
}
