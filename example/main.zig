const std = @import("std");
const slog = @import("slog");

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    var log = try slog.initRootLogger(alloc, .{
        .log_spec = .{ .from_string = "debug" },
    });
    defer log.deinit();

    var log2 = try log.initChildLogger("kid1");

    log.info("Hello slog!", .{ .field1 = "value1", .field2 = "value1", .rate = 30 });
    log2.trace("Hello slog", .{ .field1 = "value1", .field2 = "value2", .rate = 30 });
    log2.debug("Hello slog", .{ .field1 = "value1", .field2 = "value3", .rate = 30 });
    log2.info("Hello slog", .{ .field1 = "value1", .field2 = "value4", .rate = 30e2 });
    log2.warn("Hello slog", .{ .field1 = "value1", .field2 = "value5", .rate = 30.34534 });
    log2.err("Hello slog", .{ .field1 = "value1", .field2 = "value6", .rate = 30, .active = true, .metadata = null });
}
