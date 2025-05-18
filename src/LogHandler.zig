const std = @import("std");

const Formatter = @import("./formatter.zig").Formatter;
const util = @import("./util.zig");
const Level = util.Level;
const LogEvent = util.LogEvent;

const Self = @This();

pub const Output = std.fs.File;

output: Output,
formatter: Formatter,
mutex: std.Thread.Mutex = .{},

pub fn deinit(self: *Self) void {
    self.formatter.deinit();
}

pub fn handle(self: *Self, event: *const LogEvent) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    try self.formatter.format(self.output, event);
}
