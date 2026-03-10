const std = @import("std");
const Fix = @import("../../core/models.zig").Fix;
const util = @import("../../core/util.zig");

pub const Parser = struct {
    // https://developer.x-plane.com/wp-content/uploads/2019/01/XP-FIX1101-Spec.pdf
    pub fn parseLine(self: *Parser, allocator: std.mem.Allocator, line: []const u8, file_name: []const u8) !?Fix {
        _ = self;
        _ = allocator;
        _ = file_name;

        if ((line.len == 0 or line[0] == 'I' or line[0] == 'A') and line.len == 1) return null;

        if (std.mem.eql(u8, std.mem.trim(u8, line, " \r\t"), "99")) return null;

        var it = std.mem.tokenizeAny(u8, line, " \t\r");

        const lat_str = it.next() orelse return null;
        const lat = std.fmt.parseFloat(f64, lat_str) catch return null;

        const lon_str = it.next() orelse return null;
        const lon = std.fmt.parseFloat(f64, lon_str) catch return null;

        const ident = it.next() orelse return null;
        const airport = it.next() orelse return null;
        const region = it.next() orelse return null;

        return Fix{
            .lat = lat,
            .lon = lon,
            .ident = util.cleanString(ident),
            .airport = util.cleanString(airport),
            .region = util.cleanString(region),
        };
    }
};
