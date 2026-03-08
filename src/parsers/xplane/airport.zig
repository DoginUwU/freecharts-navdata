const std = @import("std");
const models = @import("../../core/models.zig");

pub const Parser = struct {
    current_icao_buf: [8]u8 = undefined,
    current_icao_len: usize = 0,

    fn currentIcao(self: *Parser) []const u8 {
        return self.current_icao_buf[0..self.current_icao_len];
    }

    // https://developer.x-plane.com/article/airport-data-apt-dat-12-00-file-format-specification/
    pub fn parseLine(self: *Parser, allocator: std.mem.Allocator, line: []const u8) !?models.AirportRecord {
        if (line.len == 0 or line[0] == 'I' or line[0] == 'A') return null;

        if (std.mem.eql(u8, std.mem.trim(u8, line, " \r\t"), "99")) return null;

        var it = std.mem.tokenizeAny(u8, line, " \t\r");

        const row_code_str = it.next() orelse return null;
        const row_code = std.fmt.parseInt(u32, row_code_str, 10) catch return null;

        switch (row_code) {
            1, 16, 17 => {
                const elev_str = it.next() orelse return null;
                _ = it.next(); // deprecated
                _ = it.next(); // deprecated
                const icao = it.next() orelse return null;
                const name = it.rest();

                @memcpy(self.current_icao_buf[0..icao.len], icao);
                self.current_icao_len = icao.len;

                return models.AirportRecord{
                    .airport = .{
                        .icao = icao,
                        .elevation = std.fmt.parseInt(i32, elev_str, 10) catch 0,
                        .has_tower = true,
                        .name = name,
                    },
                };
            },
            100 => {
                const width_meters_str = it.next() orelse return null;
                const width_meters = std.fmt.parseFloat(f32, width_meters_str) catch return null;

                _ = it.next(); // Surface Type Code
                _ = it.next(); // Surface Type Code
                _ = it.next(); // Runway smoothness
                _ = it.next(); // Runway centre-line lights
                _ = it.next(); // Runway edge lighting
                _ = it.next(); // Auto-generate distance-remaining signs

                var runaways: std.ArrayList(models.Runway) = .empty;

                while (it.next()) |number| {
                    const lat_str = it.next() orelse continue;
                    const lat = std.fmt.parseFloat(f64, lat_str) catch continue;
                    const lon_str = it.next() orelse continue;
                    const lon = std.fmt.parseFloat(f64, lon_str) catch continue;

                    _ = it.next(); // Length of displaced threshold
                    _ = it.next(); // Length of overrun
                    _ = it.next(); // Runway Marking Code
                    _ = it.next(); // Approach Lighting Code
                    _ = it.next(); // Flag for runway touchdown zone
                    _ = it.next(); // Code for Runway End Identifier Lights (REIL)

                    try runaways.append(allocator, models.Runway{
                        .airport_icao = self.currentIcao(),
                        .width = width_meters,
                        .lat = lat,
                        .lon = lon,
                        .number = number,
                    });
                }

                return models.AirportRecord{
                    .runways = try runaways.toOwnedSlice(allocator),
                };
            },
            else => {
                return null;
            },
        }
    }
};
