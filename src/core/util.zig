const std = @import("std");

pub fn cleanString(input: []const u8) []const u8 {
    const junk = " \t\r\n\x00";
    return std.mem.trim(u8, input, junk);
}
