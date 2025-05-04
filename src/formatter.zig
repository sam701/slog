const std = @import("std");
const File = std.fs.File;

const Output = @import("./LogHandler.zig").Output;
const LogEvent = @import("./util.zig").LogEvent;

pub const ColorUsage = enum {
    always,
    auto,
    never,
};

pub const Formatter = union(enum) {
    text: ColorUsage,
    json,

    pub fn format(self: *Formatter, output: Output, event: *const LogEvent) !void {
        _ = self;
        try output.writer().print("event: {s}!\n", .{event.message});
    }
};
