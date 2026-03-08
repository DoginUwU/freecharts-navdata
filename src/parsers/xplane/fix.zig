const std = @import("std");
const Fix = @import("../../core/models.zig").Fix;

pub const Parser = struct {
    // https://developer.x-plane.com/wp-content/uploads/2019/01/XP-FIX1101-Spec.pdf
    pub fn parseLine(self: *Parser, allocator: std.mem.Allocator, line: []const u8) !?Fix {
        _ = self;
        _ = allocator;

        if (line.len == 0 or line[0] == 'I' or line[0] == 'A') return null;

        if (std.mem.eql(u8, std.mem.trim(u8, line, " \r\t"), "99")) return null;

        var it = std.mem.tokenizeAny(u8, line, " \t\r");

        const lat_str = it.next() orelse return error.MissingLat;
        const lat = std.fmt.parseFloat(f64, lat_str) catch return null;

        const lon_str = it.next() orelse return error.MissingLon;
        const lon = std.fmt.parseFloat(f64, lon_str) catch return null;

        const ident = it.next() orelse return error.MissingIdent;
        const airport = it.next() orelse return error.MissingAirport;
        const region = it.next() orelse return error.MissingRegion;

        return Fix{
            .lat = lat,
            .lon = lon,
            .ident = ident,
            .airport = airport,
            .region = region,
        };
    }
};
