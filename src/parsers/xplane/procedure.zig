const std = @import("std");
const models = @import("../../core/models.zig");

pub const Parser = struct {
    // https://developer.x-plane.com/wp-content/uploads/2019/01/XP-CIFP1101-Spec.pdf
    // https://wiki.flightgear.org/User:Www2/XP11_Data_Specification
    pub fn parseLine(self: *Parser, allocator: std.mem.Allocator, line: []const u8, file_name: []const u8) !?models.ProcedureLeg {
        var it = std.mem.splitAny(u8, line, ",");

        const raw_prefix = it.next() orelse return null;

        var prefix_it = std.mem.splitScalar(u8, raw_prefix, ':');
        const raw_proc_type = prefix_it.next() orelse return null;
        const seq_str = prefix_it.next() orelse return null;

        const sequence = std.fmt.parseInt(u32, seq_str, 10) catch return null;
        var proc_type: ?models.ProcedureType = null;

        if (std.mem.eql(u8, raw_proc_type, "SID")) {
            proc_type = .SID;
        } else if (std.mem.eql(u8, raw_proc_type, "STAR")) {
            proc_type = .STAR;
        } else if (std.mem.eql(u8, raw_proc_type, "APPCH")) {
            proc_type = .Approach;
        } else {
            return null;
        }

        _ = it.next(); // Transition/Route type
        const proc_name = it.next() orelse return null;
        const transition_ident = it.next() orelse return null;
        const fix_ident = it.next() orelse return null;

        var current_col: u8 = 5;
        var leg_type: []const u8 = "";
        while (it.next()) |col| : (current_col += 1) {
            if (current_col == 11) {
                leg_type = col;
                break;
            }
        }

        _ = allocator;
        _ = self;

        const icao = std.fs.path.stem(file_name);

        if (icao.len == 0 or icao.len > 4) {
            return null;
        }

        return models.ProcedureLeg{
            .icao = icao,
            .proc_name = proc_name,
            .transition_ident = transition_ident,
            .fix_ident = fix_ident,
            .leg_type = leg_type,
            .type = proc_type.?,
            .sequence = sequence,
        };
    }
};

test "parseLine with real data" {
    var parser = Parser{};

    const line = "SID:010,5,AKRA1A,RW13,AKRAP,SB,P,C,EB  , ,010,CF, ,LON,SB,D, ,      ,1300,0025,1300,0030, ,     ,     ,05000, ,   ,    ,   ,SBLO,SB,P,A, , , , ;";
    const result = try parser.parseLine(std.testing.allocator, line, "SBLO.dat");

    try std.testing.expectEqualDeep(result.?, models.ProcedureLeg{
        .icao = "SBLO",
        .proc_name = "AKRA1A",
        .transition_ident = "RW13",
        .fix_ident = "AKRAP",
        .leg_type = "CF",
        .type = .SID,
        .sequence = 10,
    });
}

test "parseLine - SID Departure Leg (CF)" {
    var parser = Parser{};
    const line = "SID:010,5,AKRA1A,RW13,AKRAP,SB,P,C,EB  , ,010,CF, ,LON,SB,D, ,      ,1300,0025,1300,0030, ,     ,     ,05000, ,   ,    ,   ,SBLO,SB,P,A, , , , ;";
    const result = try parser.parseLine(std.testing.allocator, line, "SBLO.dat");

    try std.testing.expectEqualDeep(result.?, models.ProcedureLeg{
        .icao = "SBLO",
        .proc_name = "AKRA1A",
        .transition_ident = "RW13",
        .fix_ident = "AKRAP",
        .leg_type = "CF",
        .type = .SID,
        .sequence = 10,
    });
}

test "parseLine - SID Transition Leg (TF)" {
    var parser = Parser{};
    const line = "SID:020,6,AKRA1A,AKTIT,AKTIT,SB,E,A,EEC , ,010,TF, , , , , ,      ,    ,    ,    ,    , ,     ,     ,     , ,   ,    ,   , , , , , , , , ;";
    const result = try parser.parseLine(std.testing.allocator, line, "SBLO.dat");

    try std.testing.expectEqualDeep(result.?, models.ProcedureLeg{
        .icao = "SBLO",
        .proc_name = "AKRA1A",
        .transition_ident = "AKTIT",
        .fix_ident = "AKTIT",
        .leg_type = "TF",
        .type = .SID,
        .sequence = 20,
    });
}

test "parseLine - APPCH Initial Fix (IF)" {
    var parser = Parser{};
    const line = "APPCH:010,A,I31-Z,LO313,LO313,SB,P,C,E  A, ,010,IF, , , , , ,      ,    ,    ,    ,    ,+,05000,     ,     , ,   ,    ,   , , , , , ,0,N,S;";
    const result = try parser.parseLine(std.testing.allocator, line, "SBLO.dat");

    try std.testing.expect(std.mem.eql(u8, result.?.leg_type, "IF"));
    try std.testing.expect(std.mem.eql(u8, result.?.fix_ident, "LO313"));
    try std.testing.expect(result.?.type == .Approach);
    try std.testing.expect(result.?.sequence == 10);
}
