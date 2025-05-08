pub const Logger = @import("./Logger.zig");
pub const LogLevelSpec = @import("./LogLevelSpec.zig");
pub const formatter = @import("./formatter.zig");
pub const Formatter = formatter.Formatter;
pub const ColorUsage = formatter.ColorUsage;

comptime {
    _ = @import("./LogLevelSpec.zig");
}

test "main" {
    const testing = @import("std").testing;
    var spec = try LogLevelSpec.initFromDefaultEnvvar(testing.allocator);
    defer spec.deinit();

    const std = @import("std");
    const LogHandler = @import("./LogHandler.zig");

    var colorSchema = try formatter.ColorSchema.init(testing.allocator);
    defer colorSchema.deinit();
    var logHandler = LogHandler{
        .output = std.io.getStdErr(),
        .formatter = Formatter{ .text = .{ .auto = &colorSchema } },
    };

    var log = try Logger.init("main", &spec, &logHandler);
    defer log.deinit();

    var log2 = try log.newChildLogger("kid1");
    defer log2.deinit();

    try log.info("info test", .{ .field1 = "value1", .name = "John", .age = 30 });
    try log2.trace("Hello, world!", .{ .field1 = "value1", .name = "John", .age = 30 });
    try log2.debug("Hello, world!", .{ .field1 = "value1", .name = "John", .age = 30 });
    try log2.info("Hello, world!", .{ .field1 = "value1", .name = "John", .age = 30e2 });
    try log2.warn("Hello, world!", .{ .field1 = "value1", .name = "John", .age = 30.34534 });
    try log2.err("Hello, world!", .{ .field1 = "value1", .name = "John Smith", .age = 30, .active = true, .nothing = null });
}
