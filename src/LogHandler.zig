const std = @import("std");
const builtin = @import("builtin");

const Formatter = @import("./formatter.zig").Formatter;
const Output = @import("./root.zig").Output;
const util = @import("./util.zig");
const Level = util.Level;
const LogEvent = util.LogEvent;

pub const Writer = std.io.BufferedWriter(4096, Output.Writer).Writer;
const Self = @This();

output: Output,
formatter: Formatter,
mutex: std.Thread.Mutex = .{},

pub fn deinit(self: *Self) void {
    self.formatter.deinit();
    if (builtin.is_test) {
        self.output.deinit();
    }
}

pub fn handle(self: *Self, event: *const LogEvent) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    var bw = std.io.bufferedWriter(self.output.writer());
    try self.formatter.format(bw.writer(), event);
    try bw.flush();
}
