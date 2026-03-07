const std = @import("std");

pub fn processDatFile(
    comptime T: type,
    comptime Context: type,
    file_path: []const u8,
    ctx: Context,
    parserFn: *const fn ([]const u8) anyerror!?T,
    handlerFn: *const fn (Context, T) anyerror!void,
) !void {
    const file = try std.fs.cwd().openFile(file_path, .{ .mode = .read_only });
    defer file.close();

    var read_buffer: [1024]u8 = undefined;
    var reader = file.reader(&read_buffer);

    while (try reader.interface.takeDelimiter('\n')) |raw_line| {
        const line = std.mem.trimRight(u8, raw_line, "\r");

        if (try parserFn(line)) |parsed_item| {
            try handlerFn(ctx, parsed_item);
        }
    }
}
