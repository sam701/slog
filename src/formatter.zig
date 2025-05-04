const std = @import("std");
const File = std.fs.File;

const zeit = @import("zeit");

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
        var w = output.writer();
        // try instant.time().strftime(w, "%Y-%m-%d");
        try event.timestamp.time().gofmt(w, "2006-01-02T15:04:05.000");
        try w.writeAll(" ");
        try w.writeAll(event.message);
        try w.writeAll("\n");
    }
};
