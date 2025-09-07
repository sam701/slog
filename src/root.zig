const std = @import("std");
const testing = std.testing;
const Writer = std.Io.Writer;

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

/// Log output type.
pub const Output = union(enum) {
    file: std.fs.File,
    writer: *std.Io.Writer,
};
// pub const Output = if (builtin.is_test) std.Io.Writer.Allocating else std.fs.File;

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

/// Returns a root logger.
pub fn initRootLogger(alloc: std.mem.Allocator, options: Options) !*Logger {
    var spec = switch (options.log_spec) {
        .from_default_envvar => try LogLevelSpec.initFromEnvvar("ZIG_LOG", alloc),
        .from_envvar => |envvar| try LogLevelSpec.initFromEnvvar(envvar, alloc),
        .from_string => |str| try LogLevelSpec.initFromStringSpec(str, alloc),
    };
    errdefer spec.deinit();

    const output = options.output orelse Output{ .file = std.fs.File.stderr() };
    const frm = switch (options.formatter) {
        .text => f: {
            const use_color = switch (options.color) {
                .always => true,
                .never => false,
                .auto => switch (output) {
                    .file => |f| std.posix.isatty(f.handle),
                    .writer => false,
                },
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
    return Logger.init(options.root_logger_name, spec, log_handler, alloc);
}

comptime {
    _ = @import("./tests.zig");
}
