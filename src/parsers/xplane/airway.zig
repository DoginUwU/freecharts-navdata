const std = @import("std");
const models = @import("../../core/models.zig");
const util = @import("../../core/util.zig");

pub const Parser = struct {
    // https://developer.x-plane.com/wp-content/uploads/2019/01/XP-AWY1101-Spec.pdf
    pub fn parseLine(self: *Parser, allocator: std.mem.Allocator, line: []const u8, file_name: []const u8) !?models.Airway {
        _ = self;
        _ = allocator;
        _ = file_name;

        if ((line.len == 0 or line[0] == 'I' or line[0] == 'A') and line.len == 1) return null;
        if (std.mem.eql(u8, std.mem.trim(u8, line, " \r\t"), "99")) return null;

        var it = std.mem.tokenizeAny(u8, line, " \t\r");

        const raw_from_ident = it.next() orelse return null;
        const raw_from_region = it.next() orelse return null;
        const raw_from_type = it.next() orelse return null;
        const raw_to_ident = it.next() orelse return null;
        const raw_to_region = it.next() orelse return null;
        const raw_to_type = it.next() orelse return null;
        const raw_direction = it.next() orelse return null;
        const raw_level = it.next() orelse return null;
        const raw_base = it.next() orelse return null;
        const raw_top = it.next() orelse return null;
        const raw_segment = it.next() orelse return null;

        const num_from_type = std.fmt.parseInt(i32, raw_from_type, 10) catch return null;
        const num_to_type = std.fmt.parseInt(i32, raw_to_type, 10) catch return null;

        const from_type = switch (num_from_type) {
            11 => models.AirwayFixNavaidType.FIX,
            2 => models.AirwayFixNavaidType.NDB,
            3 => models.AirwayFixNavaidType.VOR,
            else => return null,
        };
        const to_type = switch (num_to_type) {
            11 => models.AirwayFixNavaidType.FIX,
            2 => models.AirwayFixNavaidType.NDB,
            3 => models.AirwayFixNavaidType.VOR,
            else => return null,
        };

        const direction = switch (raw_direction[0]) {
            'N' => models.DirectionRestriction.NONE,
            'F' => models.DirectionRestriction.FORWARD,
            'B' => models.DirectionRestriction.BACKWARD,
            else => return null,
        };

        const num_level = std.fmt.parseInt(i32, raw_level, 10) catch return null;
        const num_base = std.fmt.parseInt(i32, raw_base, 10) catch return null;
        const num_top = std.fmt.parseInt(i32, raw_top, 10) catch return null;

        const level = switch (num_level) {
            1 => models.AirwayLevel.LOW,
            2 => models.AirwayLevel.HIGH,
            else => return null,
        };

        return models.Airway{
            .from_ident = util.cleanString(raw_from_ident),
            .from_type = from_type,
            .from_lat = 0.0,
            .from_lon = 0.0,
            .from_region = util.cleanString(raw_from_region),
            .to_ident = util.cleanString(raw_to_ident),
            .to_type = to_type,
            .to_lat = 0.0,
            .to_lon = 0.0,
            .to_region = util.cleanString(raw_to_region),
            .direction_restriction = direction,
            .level = level,
            .base_altitude = num_base,
            .top_altitude = num_top,
            .airway_name = util.cleanString(raw_segment),
            .distance_nm = 0.0,
        };
    }
};

test "parseLine with real data" {
    var parser = Parser{};
    const line = "  LON SB  3 AKTIT SB 11 N 2 250 600 UZ65";
    const airway = try parser.parseLine(std.testing.allocator, line, "earth_awy.dat");

    try std.testing.expectEqualStrings(airway.?.airway_name, "UZ65");
    try std.testing.expect(airway.?.from_type == models.AirwayFixNavaidType.VOR);
    try std.testing.expect(airway.?.to_type == models.AirwayFixNavaidType.FIX);
    try std.testing.expect(airway.?.direction_restriction == models.DirectionRestriction.NONE);
    try std.testing.expect(airway.?.level == models.AirwayLevel.HIGH);
    try std.testing.expectEqualStrings(airway.?.from_ident, "LON");
    try std.testing.expectEqualStrings(airway.?.to_ident, "AKTIT");
}

test "parseLine with real data 2" {
    var parser = Parser{};
    const line = "SOZIN UL 11 USOMA UL 11 N 1  12  27 KR213";
    const airway = try parser.parseLine(std.testing.allocator, line, "earth_awy.dat");

    try std.testing.expectEqualStrings(airway.?.airway_name, "KR213");
    try std.testing.expect(airway.?.from_type == models.AirwayFixNavaidType.FIX);
    try std.testing.expect(airway.?.to_type == models.AirwayFixNavaidType.FIX);
    try std.testing.expect(airway.?.direction_restriction == models.DirectionRestriction.NONE);
    try std.testing.expect(airway.?.level == models.AirwayLevel.LOW);
}

test "parseLine with real data 3" {
    var parser = Parser{};
    const line = "AKTIT SB 11 DEXOV SB 11 N 2 250 600 UZ65";
    const airway = try parser.parseLine(std.testing.allocator, line, "earth_awy.dat");

    try std.testing.expectEqualStrings(airway.?.airway_name, "UZ65");
    try std.testing.expect(airway.?.from_type == models.AirwayFixNavaidType.FIX);
    try std.testing.expect(airway.?.to_type == models.AirwayFixNavaidType.FIX);
    try std.testing.expect(airway.?.direction_restriction == models.DirectionRestriction.NONE);
    try std.testing.expect(airway.?.level == models.AirwayLevel.HIGH);
}
