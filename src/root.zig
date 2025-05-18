const std = @import("std");
const testing = std.testing;

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

pub const Options = struct {
    root_logger_name: ?[]const u8 = null,
    log_spec: SpecSource = SpecSource.from_default_envvar,
    output: ?std.fs.File = null,
    formatter: enum { text, json } = .text,
    color: enum { always, auto, never } = .auto,
    color_schema_spec: ?SpecSource = SpecSource.from_default_envvar,
};

pub fn initRootLogger(alloc: std.mem.Allocator, options: Options) !*Logger {
    var spec = switch (options.log_spec) {
        .from_default_envvar => try LogLevelSpec.initFromEnvvar("ZIG_LOG", alloc),
        .from_envvar => |envvar| try LogLevelSpec.initFromEnvvar(envvar, alloc),
        .from_string => |str| try LogLevelSpec.initFromStringSpec(str, alloc),
    };
    errdefer spec.deinit();

    const output = options.output orelse std.io.getStdErr();
    const frm = switch (options.formatter) {
        .text => f: {
            const use_color = switch (options.color) {
                .always => true,
                .never => false,
                .auto => std.posix.isatty(output.handle),
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
        .json => unreachable, // TODO: implement
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
        .color = .always,
    });
    defer log.deinit();

    var log2 = try log.initChildLogger("kid1");

    try log.info("info test", .{ .field1 = "value1", .name = "John", .age = 30 });
    try log2.trace("Hello, world!", .{ .field1 = "value1", .name = "John", .age = 30 });
    try log2.debug("Hello, world!", .{ .field1 = "value1", .name = "John", .age = 30 });
    try log2.info("Hello, world!", .{ .field1 = "value1", .name = "John", .age = 30e2 });
    try log2.warn("Hello, world!", .{ .field1 = "value1", .name = "John", .age = 30.34534 });
    try log2.err("Hello, world!", .{ .field1 = "value1", .name = "John Smith", .age = 30, .active = true, .nothing = null });

    var log3 = try log2.initChildLogger("kid1-1");
    var log4 = try log2.initChildLogger("kid1-2");
    try testing.expectEqual(2, log2.kids.items.len);
    try log3.warn("abc", .{ .f1 = "v1" });
    try log4.warn("abc", .{ .f1 = "v1" });

    log3.deinit();
    try testing.expectEqual(1, log2.kids.items.len);
}
