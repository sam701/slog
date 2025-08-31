const std = @import("std");

const zeit = @import("zeit");

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

pub const Field = struct {
    name: []const u8,
    value: Value,
};

pub const Value = union(enum) {
    null,
    bool: bool,
    integer: i64,
    float: f64,
    string: []const u8,

    pub fn write(self: Value, w: *std.Io.Writer) !void {
        switch (self) {
            .null => try w.writeAll("null"),
            .bool => |x| try w.print("{}", .{x}),
            .integer => |x| try w.print("{d}", .{x}),
            .float => |x| try w.print("{d:.10}", .{x}),
            // .string => |x| try std.fmt.format(w, "\"{s}\"", .{x}),
            .string => |x| try std.json.Stringify.encodeJsonString(x, .{}, w),
        }
    }
};

pub const LogEvent = struct {
    timestamp: zeit.Instant,
    logger_name: ?[]const u8,
    level: Level,
    message: []const u8,
    constant_fields: ?[]const Field,
    fields: []Field,
};
