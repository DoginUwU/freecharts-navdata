const std = @import("std");
const xp_reader = @import("./parsers/xplane/reader.zig");
const xp_fix = @import("./parsers/xplane/fix.zig");

const Fix = @import("./core/models.zig").Fix;

const sqlite = @import("./db/sqlite.zig");

fn saveFixToDatabase(db: *sqlite.Database, fix: Fix) !void {
    try db.insertFix(fix);
}

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

    var db = try sqlite.Database.init(db_path);
    defer db.deinit();

    switch (flight_sim) {
        .XPlane => {
            try db.beginTransaction();
            const dat_file_path = try std.fs.path.join(gpa, &.{ fs_path, "Custom Data/earth_fix.dat" });
            defer gpa.free(dat_file_path);

            try xp_reader.processDatFile(Fix, *sqlite.Database, dat_file_path, &db, xp_fix.parseLine, saveFixToDatabase);
            try db.commitTransaction();
        },
        .MicrosoftFlightSimulator => {
            unreachable;
        },
        .Unknown => {
            return error.UnknownFlightSimulator;
        },
    }
}
