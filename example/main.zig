const std = @import("std");
const slog = @import("slog");

pub fn main() !void {
    var log = try slog.initRootLogger(std.heap.page_allocator, .{});
    defer log.deinit();

    var log2 = try log.initChildLogger("mod1");
    var log3 = try log2.initChildLogger("mod2");
    var log4 = try log3.initChildLogger("mod3");

    log.info("Hello slog!", .{ .field1 = "value1", .field2 = "value1", .rate = 30 });
    log2.trace("Hello slog!", .{ .field1 = "value1", .field2 = "value2", .rate = 30 });
    log2.debug("Hello slog!", .{ .field1 = "value1", .field2 = "value3", .rate = 30 });
    log2.info("Hello slog!", .{ .field1 = "value1", .field2 = "value4", .rate = 30e2 });
    log3.warn("Hello slog!", .{ .field1 = "value1", .field2 = "value5", .rate = 30.34534 });
    log3.err("Hello slog!", .{ .field1 = "value1", .field2 = "value6", .rate = 30, .active = true, .metadata = null });
    log4.err("Hello slog!", .{ .field1 = "value1", .field2 = "value6", .rate = 30, .active = true, .metadata = null });
}
