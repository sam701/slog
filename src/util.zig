const std = @import("std");

pub const Level = enum(u3) {
    trace,
    debug,
    info,
    warn,
    @"error",

    pub const ErrInvalid = error.InvalidLogLevel;

    pub fn parse(str: []const u8) error{InvalidLogLevel}!Level {
        if (std.mem.eql(u8, str, "trace")) return Level.trace;
        if (std.mem.eql(u8, str, "debug")) return Level.debug;
        if (std.mem.eql(u8, str, "info")) return Level.info;
        if (std.mem.eql(u8, str, "warn")) return Level.warn;
        if (std.mem.eql(u8, str, "error")) return Level.@"error";
        return ErrInvalid;
    }
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

pub const LogEvent = struct {
    timestamp_millis: u64,
    logger_name: []const u8,
    level: Level,
    message: []const u8,
    fix_fields: ?*const std.json.ObjectMap,
    fields: *const std.json.ObjectMap,
};
