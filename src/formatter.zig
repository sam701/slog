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
        try event.timestamp.time().gofmt(w, "2006-01-02T15:04:05.000");
        try w.writeAll(" ");
        try w.print("{s} {s} {s} ", .{ @tagName(event.level), event.logger_name, event.message });

        var it = event.fields.iterator();
        var cnt: usize = 0;
        while (it.next()) |entry| : (cnt += 1) {
            if (cnt > 0) {
                try w.writeAll(" ");
            }
            try w.print("{s}=", .{entry.key_ptr.*});
            try std.json.stringify(entry.value_ptr.*, .{}, w);
        }
    }
};
