const std = @import("std");
const LogEvent = @import("./util.zig").LogEvent;
const File = std.fs.File;

// pub const OutputStream = struct {
//     inner: std.fs.File,

//     pub fn stdout() OutputStream {
//         return OutputStream{ .inner = std.io.getStdOut() };
//     }

//     pub fn stderr() OutputStream {
//         return OutputStream{ .inner = std.io.getStdErr() };
//     }

//     pub fn file(path: []const u8) std.fs.File.OpenError!OutputStream {
//         return OutputStream{ .inner = try std.fs.cwd().openFile(path, .{ .mode = .write_only }) };
//     }
// };

pub const ColorUsage = enum {
    always,
    auto,
    never,
};

pub const Formatter = union(enum) {
    text: ColorUsage,
    json,

    pub fn format(self: *Formatter, output: std.io.AnyWriter, event: *LogEvent) !void {
        _ = self;
        try output.print("event: {s}!\n", .{event.message});
    }
};
