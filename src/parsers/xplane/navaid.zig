const std = @import("std");
const models = @import("../../core/models.zig");
const util = @import("../../core/util.zig");

pub const Parser = struct {
    // https://developer.x-plane.com/wp-content/uploads/2016/10/XP-NAV1200-Spec.pdf
    pub fn parseLine(self: *Parser, allocator: std.mem.Allocator, line: []const u8, file_name: []const u8) !?models.Navaid {
        _ = self;
        _ = allocator;
        _ = file_name;

        if ((line.len == 0 or line[0] == 'I' or line[0] == 'A') and line.len == 1) return null;

        if (std.mem.eql(u8, std.mem.trim(u8, line, " \r\t"), "99")) return null;

        var it = std.mem.tokenizeAny(u8, line, " \t\r");

        const raw_code = it.next() orelse return null;
        const num_code = std.fmt.parseInt(u32, raw_code, 10) catch return null;

        const navaid_type = switch (num_code) {
            2, 13 => models.NavaidType.NDB,
            3, 12 => models.NavaidType.VOR,
            else => return null,
        };
        const lat_str = it.next() orelse return null;
        const lat = std.fmt.parseFloat(f64, lat_str) catch return null;
        const lon_str = it.next() orelse return null;
        const lon = std.fmt.parseFloat(f64, lon_str) catch return null;

        _ = it.next(); // Elevation

        const frequency_str = it.next() orelse return null;

        _ = it.next(); // VOR/NDB class (formerly reception range in nautical miles)
        _ = it.next(); // Flags or Slaved variation for VOR

        const ident = it.next() orelse return null;
        _ = it.next(); // terminal_region_ident

        const region = it.next() orelse return null;
        const name = it.rest();

        return models.Navaid{
            .ident = util.cleanString(ident),
            .type = navaid_type,
            .lat = lat,
            .lon = lon,
            .frequency = std.fmt.parseInt(i32, util.cleanString(frequency_str), 10) catch 0,
            .region = util.cleanString(region),
            .name = util.cleanString(name),
        };
    }
};

test "parseLine should parse a valid VOR line" {
    var parser = Parser{};
    const line = " 3 -23.339516667  -51.112525000     1813    11240   150    -20.000  LON ENRT SB LONDRINA VOR/DME";
    const navaid = try parser.parseLine(std.testing.allocator, line, "earth_nav.dat") orelse unreachable;

    try std.testing.expectEqual(models.NavaidType.VOR, navaid.type);
    try std.testing.expectEqual(-23.339516667, navaid.lat);
    try std.testing.expectEqual(-51.112525000, navaid.lon);
    try std.testing.expectEqual(11240, navaid.frequency);
    try std.testing.expectEqualStrings("SB", navaid.region);
    try std.testing.expectEqualStrings("LONDRINA VOR/DME", navaid.name);
    try std.testing.expectEqualStrings("LON", navaid.ident);
}

test "parseLine should parse a valid NDB line" {
    var parser = Parser{};
    const line = " 2 -41.120277778  -71.245000000        0      330    15      0.000   OB ENRT SA SAN CARLOS DE BARILOCHE NDB";
    const navaid = try parser.parseLine(std.testing.allocator, line, "earth_nav.dat") orelse unreachable;

    try std.testing.expectEqual(models.NavaidType.NDB, navaid.type);
    try std.testing.expectEqual(-41.120277778, navaid.lat);
    try std.testing.expectEqual(-71.245000000, navaid.lon);
    try std.testing.expectEqual(330, navaid.frequency);
    try std.testing.expectEqualStrings("SA", navaid.region);
    try std.testing.expectEqualStrings("SAN CARLOS DE BARILOCHE NDB", navaid.name);
    try std.testing.expectEqualStrings("OB", navaid.ident);
}

test "parseLine should parse a valid VOR line 2" {
    var parser = Parser{};
    const line = " 3  37.573333333  105.125000000     4147    11750   130     -3.000  ZWX ENRT ZL ZHONGWEI VOR/DME";
    const navaid = try parser.parseLine(std.testing.allocator, line, "earth_nav.dat") orelse unreachable;

    try std.testing.expectEqual(models.NavaidType.VOR, navaid.type);
    try std.testing.expectEqual(37.573333333, navaid.lat);
    try std.testing.expectEqual(105.125000000, navaid.lon);
    try std.testing.expectEqual(11750, navaid.frequency);
    try std.testing.expectEqualStrings("ZL", navaid.region);
    try std.testing.expectEqualStrings("ZHONGWEI VOR/DME", navaid.name);
    try std.testing.expectEqualStrings("ZWX", navaid.ident);
}

test "parseLine should parse a valid VOR line 3" {
    var parser = Parser{};
    const line = "13  49.239888889   28.620916667      994    11390   130      0.000  VIN ENRT UK VINNYTSIA DME";
    const navaid = try parser.parseLine(std.testing.allocator, line, "earth_nav.dat") orelse unreachable;

    try std.testing.expectEqual(models.NavaidType.NDB, navaid.type);
    try std.testing.expectEqual(49.239888889, navaid.lat);
    try std.testing.expectEqual(28.620916667, navaid.lon);
    try std.testing.expectEqual(11390, navaid.frequency);
    try std.testing.expectEqualStrings("UK", navaid.region);
    try std.testing.expectEqualStrings("VINNYTSIA DME", navaid.name);
    try std.testing.expectEqualStrings("VIN", navaid.ident);
}
