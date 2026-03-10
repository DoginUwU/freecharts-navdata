const std = @import("std");
const xp_reader = @import("./parsers/xplane/reader.zig");
const sqlite = @import("./db/sqlite.zig");

const xp_airport = @import("./parsers/xplane/airport.zig");
const xp_fix = @import("./parsers/xplane/fix.zig");
const xp_navaid = @import("./parsers/xplane/navaid.zig");
const xp_awy = @import("./parsers/xplane/airway.zig");
const xp_procedure = @import("./parsers/xplane/procedure.zig");

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

fn importXPlaneData(
    allocator: std.mem.Allocator,
    root: []const u8,
    db: *sqlite.Database,
) !void {
    var fix_parser = xp_fix.Parser{};
    var apt_parser = xp_airport.Parser{};
    var awy_parser = xp_awy.Parser{};
    var proc_parser = xp_procedure.Parser{};
    var navaid_parser = xp_navaid.Parser{};

    std.debug.print("Importing Airports...\n", .{});
    try importFile(
        allocator,
        root,
        "Global Scenery/Global Airports/Earth nav data/apt.dat",
        &apt_parser,
        db,
        sqlite.Database.insertAirportRecord,
    );

    std.debug.print("Importing Fixes...\n", .{});
    try importFile(
        allocator,
        root,
        "Custom Data/earth_fix.dat",
        &fix_parser,
        db,
        sqlite.Database.insertFix,
    );

    std.debug.print("Importing Navaids...\n", .{});
    try importFile(
        allocator,
        root,
        "Custom Data/earth_nav.dat",
        &navaid_parser,
        db,
        sqlite.Database.insertNavaid,
    );

    std.debug.print("Importing Airways...\n", .{});
    try importFile(
        allocator,
        root,
        "Custom Data/earth_awy.dat",
        &awy_parser,
        db,
        sqlite.Database.insertAirway,
    );

    std.debug.print("Importing Procedures...\n", .{});
    try importCIFPDirectory(
        allocator,
        root,
        &proc_parser,
        db,
    );

    std.debug.print("Computing airport ranks...\n", .{});
    try db.computeAirportsRanks();
}

fn importFile(
    allocator: std.mem.Allocator,
    root: []const u8,
    path: []const u8,
    parser: anytype,
    db: *sqlite.Database,
    handler: anytype,
) !void {
    try db.beginTransaction();

    const full_path = try getSimFilePath(allocator, root, path);
    defer allocator.free(full_path);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    try xp_reader.processFile(
        arena.allocator(),
        full_path,
        db,
        parser,
        handler,
    );

    try db.commitTransaction();
}

fn importCIFPDirectory(
    allocator: std.mem.Allocator,
    root: []const u8,
    parser: *xp_procedure.Parser,
    db: *sqlite.Database,
) !void {
    const cifp_path = try getSimFilePath(
        allocator,
        root,
        "Custom Data/CIFP",
    );
    defer allocator.free(cifp_path);

    var dir = try std.fs.cwd().openDir(
        cifp_path,
        .{ .iterate = true },
    );
    defer dir.close();

    var it = dir.iterate();

    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;

        const path = try std.mem.concat(
            allocator,
            u8,
            &.{ "Custom Data/CIFP/", entry.name },
        );
        defer allocator.free(path);

        try importFile(
            allocator,
            root,
            path,
            parser,
            db,
            sqlite.Database.insertProcedure,
        );
    }
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

    std.debug.print("Import completed successfully!\n", .{});
}
