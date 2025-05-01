const std = @import("std");

pub const Level = enum(u8) {
    trace,
    debug,
    info,
    warn,
    @"error",
};

pub const OutputStream = struct {
    inner: std.fs.File,

    pub fn stdout() OutputStream {
        return OutputStream{ .inner = std.io.getStdOut() };
    }

    pub fn stderr() OutputStream {
        return OutputStream{ .inner = std.io.getStdErr() };
    }

    pub fn file(path: []const u8) std.fs.File.OpenError!OutputStream {
        return OutputStream{ .inner = try std.fs.cwd().openFile(path, .{ .mode = .write_only }) };
    }
};

pub const ColorUsage = enum {
    always,
    auto,
    never,
};

pub const Formatter = union(enum) {
    json,
    text: ColorUsage,

    // pub fn format(self: Formatter, out: *const OutputStream, event: *const LogEvent) !void {
    //     _ = self;
    //     _ = out;
    //     _ = event;
    //     unreachable;
    // }
};

/// Contains log level for a logger name.
pub const LogLevelSpecNode = struct {
    name: []const u8,
    log_level: Level,
    kids: std.StringHashMap(LogLevelSpecNode),
};

pub const LogEvent = struct {
    timestamp_millis: u64,
    logger_name: []const u8,
    level: Level,
    message: []const u8,
    fix_fields: ?*const std.json.ObjectMap,
    fields: *const std.json.ObjectMap,
};
