const std = @import("std");
const slog = @import("slog");

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    var log = try slog.initRootLogger(alloc, .{});
    defer log.deinit();

    var log2 = try log.initChildLogger("kid1");

    try log.info("info test", .{ .field1 = "value1", .name = "John", .age = 30 });
    try log2.trace("Hello, world!", .{ .field1 = "value1", .name = "John", .age = 30 });
    try log2.debug("Hello, world!", .{ .field1 = "value1", .name = "John", .age = 30 });
    try log2.info("Hello, world!", .{ .field1 = "value1", .name = "John", .age = 30e2 });
    try log2.warn("Hello, world!", .{ .field1 = "value1", .name = "John", .age = 30.34534 });
    try log2.err("Hello, world!", .{ .field1 = "value1", .name = "John Smith", .age = 30, .active = true, .nothing = null });
}
