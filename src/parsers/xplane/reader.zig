const std = @import("std");

pub fn processFile(
    allocator: std.mem.Allocator,
    path: []const u8,
    db: anytype,
    parser: anytype,
    comptime handlerFn: anytype,
) !void {
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    var read_buffer: [1024]u8 = undefined;
    var reader = file.reader(&read_buffer);

    while (try reader.interface.takeDelimiter('\n')) |raw_line| {
        const line = std.mem.trimRight(u8, raw_line, "\r");

        if (try parser.parseLine(allocator, line)) |parsed_item| {
            try handlerFn(db, parsed_item);
        }
    }
}
