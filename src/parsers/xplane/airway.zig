const std = @import("std");
const models = @import("../../core/models.zig");

pub const Parser = struct {
    // https://developer.x-plane.com/wp-content/uploads/2019/01/XP-AWY1101-Spec.pdf
    pub fn parseLine(self: *Parser, allocator: std.mem.Allocator, line: []const u8) !?models.Airway {
        _ = self;
        _ = allocator;

        if (line.len == 0 or line[0] == 'I' or line[0] == 'A') return null;
        if (std.mem.eql(u8, std.mem.trim(u8, line, " \r\t"), "99")) return null;

        var it = std.mem.tokenizeAny(u8, line, " \t\r");

        const raw_from_ident = it.next() orelse return null;
        _ = it.next() orelse return null; // Region ICAO
        const raw_from_type = it.next() orelse return null;
        const raw_to_ident = it.next() orelse return null;
        _ = it.next() orelse return null; // Region ICAO
        const raw_to_type = it.next() orelse return null;
        const raw_direction = it.next() orelse return null;
        const raw_level = it.next() orelse return null;
        const raw_base = it.next() orelse return null;
        const raw_top = it.next() orelse return null;
        const raw_segment = it.next() orelse return null;

        const num_from_type = std.fmt.parseInt(i32, raw_from_type, 10) catch return null;
        const num_to_type = std.fmt.parseInt(i32, raw_to_type, 10) catch return null;

        const from_type = switch (num_from_type) {
            11 => models.NavaidType.Fix,
            2 => models.NavaidType.NDB,
            3 => models.NavaidType.VOR,
            else => return null,
        };
        const to_type = switch (num_to_type) {
            11 => models.NavaidType.Fix,
            2 => models.NavaidType.NDB,
            3 => models.NavaidType.VOR,
            else => return null,
        };

        const direction = switch (raw_direction[0]) {
            'N' => models.DirectionRestriction.None,
            'F' => models.DirectionRestriction.Forward,
            'B' => models.DirectionRestriction.Backward,
            else => return null,
        };

        const num_level = std.fmt.parseInt(i32, raw_level, 10) catch return null;
        const num_base = std.fmt.parseInt(i32, raw_base, 10) catch return null;
        const num_top = std.fmt.parseInt(i32, raw_top, 10) catch return null;

        const level = switch (num_level) {
            0 => models.AirwayLevel.Low,
            1 => models.AirwayLevel.High,
            else => return null,
        };

        return models.Airway{
            .from_ident = raw_from_ident,
            .from_type = from_type,
            .from_lat = 0.0,
            .from_lon = 0.0,
            .to_ident = raw_to_ident,
            .to_type = to_type,
            .to_lat = 0.0,
            .to_lon = 0.0,
            .direction_restriction = direction,
            .level = level,
            .base_altitude = num_base,
            .top_altitude = num_top,
            .airway_name = raw_segment,
            .distance_nm = 0.0,
        };
    }
};
