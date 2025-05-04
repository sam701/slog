const std = @import("std");
const File = std.fs.File;

const zeit = @import("zeit");

const Output = @import("./LogHandler.zig").Output;
const LogEvent = @import("./util.zig").LogEvent;
const Level = @import("./util.zig").Level;

pub const ColorUsage = union(enum) {
    always: *const ColorSchema,
    auto: *const ColorSchema,
    never,
};

pub const ColorItem = enum {
    timestamp,

    log_level_trace,
    log_level_debug,
    log_level_info,
    log_level_warn,
    log_level_error,

    logger_name,
    message,
    field_name,
    field_value_string,
    field_value_number,
    field_value_boolean,
};

/// Color schema for the formatter.
pub const ColorSchema = std.AutoHashMap(ColorItem, []const u8);

pub fn defaultColorSchema(alloc: std.mem.Allocator) !ColorSchema {
    var schema = ColorSchema.init(alloc);
    try schema.put(ColorItem.timestamp, "38;5;246");
    try schema.put(ColorItem.log_level_trace, "38;5;244");
    try schema.put(ColorItem.log_level_debug, "34;1");
    try schema.put(ColorItem.log_level_info, "38;5;247");
    try schema.put(ColorItem.log_level_warn, "38;5;248");
    try schema.put(ColorItem.log_level_error, "38;5;249");
    try schema.put(ColorItem.logger_name, "36");
    try schema.put(ColorItem.message, "38;5;251");
    try schema.put(ColorItem.field_name, "38;5;246");
    try schema.put(ColorItem.field_value_string, "38;5;253");
    try schema.put(ColorItem.field_value_number, "38;5;254");
    try schema.put(ColorItem.field_value_boolean, "38;5;255");
    return schema;
}

pub const Formatter = union(enum) {
    text: ColorUsage,
    json,

    pub fn format(self: *Formatter, output: Output, event: *const LogEvent) !void {
        var w = output.writer();

        var p = ColorPrinter{ .w = w, .color_schema = self.text.auto };

        try p.writeItemColor(.timestamp);
        try event.timestamp.time().gofmt(w, "2006-01-02T15:04:05.000");
        try p.reset();
        try w.writeByte(' ');

        try p.writeItemColor(.log_level_debug);
        try w.writeAll(levelName(event.level));
        try p.reset();
        try w.writeByte(' ');

        try p.writeItemColor(.logger_name);
        try w.writeAll(event.logger_name);
        try p.reset();
        try w.writeByte(' ');

        try p.writeItemColor(.message);
        try w.writeAll(event.message);
        try p.reset();
        try w.writeByte(' ');

        var it = event.fields.iterator();
        var cnt: usize = 0;
        while (it.next()) |entry| : (cnt += 1) {
            if (cnt > 0) try w.writeByte(' ');
            try p.writeItemColor(.field_name);
            try w.print("{s}=", .{entry.key_ptr.*});
            try p.reset();
            try std.json.stringify(entry.value_ptr.*, .{}, w);
        }
        try w.writeByte('\n');
    }

    fn levelName(level: Level) []const u8 {
        return switch (level) {
            .trace => "TRC",
            .debug => "DBG",
            .info => "INF",
            .warn => "WRN",
            .@"error" => "ERR",
        };
    }
};

const ColorPrinter = struct {
    w: std.fs.File.Writer,
    color_schema: ?*const ColorSchema,

    const colorClear = "0";

    fn writeItemColor(self: *ColorPrinter, color_item: ColorItem) !void {
        if (self.color_schema) |schema| {
            if (schema.get(color_item)) |color| {
                try self.writeColor(color);
            }
        }
    }

    fn writeColor(self: *ColorPrinter, color: []const u8) !void {
        try self.w.writeByte(0x1b);
        try self.w.writeByte('[');
        try self.w.writeAll(color);
        try self.w.writeByte('m');
    }
    fn reset(self: *ColorPrinter) !void {
        if (self.color_schema != null) try self.writeColor(colorClear);
    }
};
