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
    logger_name,
    message,
    field_name,
};

pub const FieldValueType = enum {
    null,
    bool,
    string,
    number,
};

pub const Color = []const u8;

/// Color schema for the formatter.
pub const ColorSchema = struct {
    items: std.AutoHashMap(ColorItem, Color),
    log_levels: std.AutoHashMap(Level, Color),
    field_types: std.AutoHashMap(FieldValueType, Color),

    pub fn deinit(self: *ColorSchema) void {
        self.items.deinit();
        self.log_levels.deinit();
        self.field_types.deinit();
    }
};

pub fn defaultColorSchema(alloc: std.mem.Allocator) !ColorSchema {
    var schema = ColorSchema{
        .items = std.AutoHashMap(ColorItem, Color).init(alloc),
        .log_levels = std.AutoHashMap(Level, Color).init(alloc),
        .field_types = std.AutoHashMap(FieldValueType, Color).init(alloc),
    };

    try schema.items.put(ColorItem.timestamp, "38;5;243");
    try schema.items.put(ColorItem.logger_name, "36");
    try schema.items.put(ColorItem.field_name, "2;97");

    try schema.log_levels.put(Level.trace, "38;5;244");
    try schema.log_levels.put(Level.debug, "34");
    try schema.log_levels.put(Level.info, "32");
    try schema.log_levels.put(Level.warn, "33");
    try schema.log_levels.put(Level.@"error", "31");

    try schema.field_types.put(FieldValueType.null, "33");
    try schema.field_types.put(FieldValueType.bool, "36");
    try schema.field_types.put(FieldValueType.number, "32");
    try schema.field_types.put(FieldValueType.string, "3;94");
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

        try p.writeLogLevelColor(event.level);
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
            const value_type: FieldValueType = switch (entry.value_ptr.*) {
                .null => .null,
                .bool => .bool,
                .integer, .float => .number,
                else => .string,
            };
            try p.writeFieldTypeColor(value_type);
            try std.json.stringify(entry.value_ptr.*, .{}, w);
            try p.reset();
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
            if (schema.items.get(color_item)) |color| {
                try self.writeColor(color);
            }
        }
    }
    fn writeLogLevelColor(self: *ColorPrinter, level: Level) !void {
        if (self.color_schema) |schema| {
            if (schema.log_levels.get(level)) |color| {
                try self.writeColor(color);
            }
        }
    }

    fn writeFieldTypeColor(self: *ColorPrinter, field_type: FieldValueType) !void {
        if (self.color_schema) |schema| {
            if (schema.field_types.get(field_type)) |color| {
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
