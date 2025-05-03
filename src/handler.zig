const std = @import("std");
const util = @import("./util.zig");
const Formatter = @import("./formatter.zig").Formatter;
const Level = util.Level;
const LogEvent = util.LogEvent;

pub const LogHandler = struct {
    output: std.io.AnyWriter,
    formatter: Formatter,

    fn handle(self: *const LogHandler, event: *const LogEvent) !void {
        try self.formatter.format(self.output, event);
    }
};
