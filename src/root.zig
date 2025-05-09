pub const Logger = @import("./Logger.zig");
pub const LogLevelSpec = @import("./LogLevelSpec.zig");
pub const Formatter = @import("./formatter.zig").Formatter;
pub const ColorUsage = @import("./formatter.zig").ColorUsage;

comptime {
    @import("std").testing.refAllDeclsRecursive(@This());
}

test "main" {
    const testing = @import("std").testing;
    var spec = try LogLevelSpec.initFromDefaultEnvvar(testing.allocator);
    defer spec.deinit();

    const std = @import("std");
    const LogHandler = @import("./LogHandler.zig");

    var logHandler = LogHandler{
        .output = std.io.getStdErr(),
        .formatter = Formatter{ .text = ColorUsage.auto },
    };

    var log = try Logger.init("main", &spec, &logHandler);
    defer log.deinit();

    var log2 = try log.newChildLogger("kid1");
    defer log2.deinit();

    try log2.info("Hello, world!", .{ .field1 = "value1", .name = "John", .age = 30 });

    // try testing.expect(false);
}
