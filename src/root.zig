const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

const formatter = @import("./formatter.zig");
const Formatter = formatter.Formatter;
const ColorUsage = formatter.ColorUsage;
const ColorSchema = formatter.ColorSchema;
pub const Logger = @import("./Logger.zig");
const LogHandler = @import("./LogHandler.zig");
const LogLevelSpec = @import("./LogLevelSpec.zig");

/// Describes where to get the specification from.
pub const SpecSource = union(enum) {
    /// Get spec from the default envvar, e.g. ZIG_LOG, ZIG_LOG_COLORS, ZIG_LOG_FORMAT.
    from_default_envvar,

    /// Get spec from the given envvar.
    from_envvar: []const u8,

    /// Get spec from the provided spec string.
    from_string: []const u8,
};

pub const Output = if (builtin.is_test) std.ArrayList(u8) else std.fs.File;

/// Root logger options.
pub const Options = struct {
    /// Root logger name.
    root_logger_name: ?[]const u8 = null,

    /// Defines where to get the log specification from. Default is to get it from environment variable ZIG_LOG.
    ///
    /// Format: LOG_LEVEL_DEFINITION(,LOG_LEVEL_DEFINITION)*
    ///
    /// * LOG_LEVEL_DEFINITION = NODE_NAME=LOG_LEVEL
    /// * NODE_NAME = string(.string)*
    /// * LOG_LEVEL = trace|debug|info|warn|error
    ///
    /// Example: info,child_logger=debug,child_logger.next=trace
    log_spec: SpecSource = SpecSource.from_default_envvar,

    /// Some file to log into. Default: stderr.
    output: ?Output = null,

    /// Log formatter
    formatter: enum { text, json } = .text,

    /// When to use color if formatter is .text.
    color: enum { always, auto, never } = .auto,

    /// Color schema for text formatter. If not set, no colors are used.
    /// Default is to use spec source from environment variable ZIG_LOG_COLORS
    ///
    /// Format: COLOR_SPEC(,COLOR_SPEC)*
    /// * COLOR_SPEC = COLOR_ITEM=COLOR_DEFINITION
    /// * COLOR_ITEM = timestamp|message|logger|field_name|trace|debug|info|warn|error|null|bool|number|string
    /// * COLOR_DEFINITION = terminal color sequence, like 31;1 or 38;5;243
    ///
    /// Example: trace=33;1,logger=32
    color_schema_spec: ?SpecSource = SpecSource.from_default_envvar,
};

pub fn initRootLogger(alloc: std.mem.Allocator, options: Options) !*Logger {
    var spec = switch (options.log_spec) {
        .from_default_envvar => try LogLevelSpec.initFromEnvvar("ZIG_LOG", alloc),
        .from_envvar => |envvar| try LogLevelSpec.initFromEnvvar(envvar, alloc),
        .from_string => |str| try LogLevelSpec.initFromStringSpec(str, alloc),
    };
    errdefer spec.deinit();

    const output = options.output orelse if (builtin.is_test) Output.init(std.testing.allocator) else std.io.getStdErr();
    const frm = switch (options.formatter) {
        .text => f: {
            const use_color = switch (options.color) {
                .always => true,
                .never => false,
                .auto => if (builtin.is_test) false else std.posix.isatty(output.handle),
            };

            const color_schema = if (use_color) cs: {
                break :cs if (options.color_schema_spec) |schema_spec| {
                    break :cs switch (schema_spec) {
                        .from_default_envvar => try ColorSchema.initEnvVar("ZIG_LOG_COLORS", alloc),
                        .from_envvar => |envvar| try ColorSchema.initEnvVar(envvar, alloc),
                        .from_string => |str| try ColorSchema.initString(str, alloc),
                    };
                } else null;
            } else null;

            break :f Formatter{ .text = color_schema };
        },
        .json => Formatter.json,
    };
    const log_handler = try alloc.create(LogHandler);
    log_handler.* = LogHandler{
        .output = output,
        .formatter = frm,
    };
    return Logger.initRoot(options.root_logger_name, spec, log_handler, alloc);
}

test "main" {
    var log = try initRootLogger(testing.allocator, .{
        .log_spec = SpecSource{ .from_string = "warn" },
        .color = .always,
    });
    defer log.deinit();

    var log2 = try log.initChildLogger("kid1");

    log.info("info test aa11", .{ .field1 = "value1", .name = "John", .age = 30 });
    log2.trace("Hello, aa22", .{ .field1 = "value1", .name = "John", .age = 30 });
    log2.debug("Hello, aa33", .{ .field1 = "value1", .name = "John", .age = 30 });
    log2.info("Hello, aa44", .{ .field1 = "value1", .name = "John", .age = 30e2 });
    log2.warn("Hello, aa55", .{ .field1 = "value1", .name = "John", .age = 30.34534 });
    log2.err("Hello, aa66", .{ .field1 = "value1", .name = "John Smith", .age = 30, .active = true, .nothing = null });

    var log3 = try log2.initChildLogger("kid1-1");
    var log4 = try log2.initChildLogger("kid1-2");
    try testing.expectEqual(2, log2.kids.items.len);
    log3.warn("abc77", .{ .f1 = "v1" });
    log4.err("abc88", .{ .f1 = "v1" });

    log3.deinit();
    try testing.expectEqual(1, log2.kids.items.len);

    const si = StringInspector{ .str = log.dispatcher.handler.output.items };
    try si.hasNotPattern("aa11");
    try si.hasNotPattern("aa22");
    try si.hasNotPattern("aa33");
    try si.hasNotPattern("aa44");
    try si.hasPattern("aa55");
    try si.hasPattern("aa66");
    try si.hasPattern("abc77");
    try si.hasPattern("abc88");
}

const StringInspector = struct {
    str: []const u8,

    fn hasPattern(self: StringInspector, pattern: []const u8) !void {
        try testing.expect(std.mem.indexOf(u8, self.str, pattern).? > 0);
    }

    fn hasNotPattern(self: StringInspector, pattern: []const u8) !void {
        try testing.expect(std.mem.indexOf(u8, self.str, pattern) == null);
    }
};
