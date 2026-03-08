const std = @import("std");
const xp_reader = @import("./parsers/xplane/reader.zig");
const sqlite = @import("./db/sqlite.zig");

const xp_fix = @import("./parsers/xplane/fix.zig");
const xp_airport = @import("./parsers/xplane/airport.zig");

const FlightSim = enum {
    XPlane,
    MicrosoftFlightSimulator,
    Unknown,
};

fn detectFlightSim(fs_path: [:0]const u8) !FlightSim {
    var dir = try std.fs.cwd().openDir(fs_path, .{ .iterate = true });
    defer dir.close();

    var dirIt = dir.iterate();

    while (try dirIt.next()) |entry| {
        if (std.mem.eql(u8, entry.name, "Custom Data")) {
            return .XPlane;
        }
    }

    return .Unknown;
}

fn getSimFilePath(allocator: std.mem.Allocator, base: []const u8, sub_path: []const u8) ![]u8 {
    return try std.fs.path.join(allocator, &.{ base, sub_path });
}

fn importXPlaneData(allocator: std.mem.Allocator, root: []const u8, db: *sqlite.Database) !void {
    // var fix_parser = xp_fix.Parser{};
    var apt_parser = xp_airport.Parser{};

    const tasks = .{
        // .{
        //     .path = "Custom Data/earth_fix.dat",
        //     .parser = &fix_parser,
        //     .handler = sqlite.Database.insertFix,
        // },
        .{
            .path = "Global Scenery/Global Airports/Earth nav data/apt.dat",
            .parser = &apt_parser,
            .handler = sqlite.Database.insertAirportRecord,
        },
    };

    inline for (tasks) |task| {
        const full_path = try getSimFilePath(allocator, root, task.path);
        defer allocator.free(full_path);

        std.debug.print("Importing: {s}...\n", .{task.path});

        try db.beginTransaction();

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const a = arena.allocator();

        try xp_reader.processFile(a, full_path, db, task.parser, task.handler);
        try db.commitTransaction();
    }

    try db.computeAirportsRanks();
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();
    defer {
        const leak = general_purpose_allocator.deinit();
        if (leak == .leak) {
            std.debug.print("Memory leak detected!\n", .{});
        }
    }

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    if (args.len != 3) {
        std.debug.print("Usage: {s} <path_flight_simulator> <database_path>\n", .{args[0]});
        return;
    }

    const fs_path = args[1];
    const db_path = args[2];

    const flight_sim = try detectFlightSim(fs_path);

    const db_path_z = try gpa.dupeZ(u8, db_path);
    defer gpa.free(db_path_z);

    var db = try sqlite.Database.init(db_path_z);
    defer db.deinit();

    switch (flight_sim) {
        .XPlane => try importXPlaneData(gpa, fs_path, &db),
        .MicrosoftFlightSimulator => return error.MSFSNotSupportedYet,
        .Unknown => return error.UnknownFlightSimulator,
    }
}
