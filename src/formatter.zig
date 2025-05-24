const std = @import("std");
const File = std.fs.File;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const LogHandler = @import("./LogHandler.zig");
const testing = std.testing;

const zeit = @import("zeit");

const Output = @import("./root.zig").Output;
const LogEvent = @import("./util.zig").LogEvent;
const Level = @import("./util.zig").Level;

pub const ColorableItem = enum {
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
    values_arena: ?ArenaAllocator = null,
    items: std.AutoHashMap(ColorableItem, Color),
    log_levels: std.AutoHashMap(Level, Color),
    field_types: std.AutoHashMap(FieldValueType, Color),

    pub fn initDefaultEnvVar(alloc: Allocator) !*ColorSchema {
        return initEmpty("ZIG_LOG_COLOR", alloc);
    }

    pub fn initEnvVar(envvar: []const u8, alloc: Allocator) !ColorSchema {
        const spec: []const u8 = std.process.getEnvVarOwned(alloc, envvar) catch return initDefault(alloc);
        defer alloc.free(spec);

        return initString(spec, alloc) catch return initDefault(alloc);
    }

    fn initEmpty(alloc: Allocator) !ColorSchema {
        return .{
            .items = std.AutoHashMap(ColorableItem, Color).init(alloc),
            .log_levels = std.AutoHashMap(Level, Color).init(alloc),
            .field_types = std.AutoHashMap(FieldValueType, Color).init(alloc),
        };
    }

    pub fn initString(text: []const u8, alloc: Allocator) !ColorSchema {
        var schema = try initEmpty(alloc);
        schema.values_arena = ArenaAllocator.init(alloc);
        errdefer schema.deinit();

        const al = schema.values_arena.?.allocator();
        var txt = text;
        while (try parseColorDefinition(txt)) |result| {
            const def = result.def;
            switch (def.item) {
                .item => |item| {
                    try schema.items.put(item, try al.dupe(u8, def.color));
                },
                .log_level => |level| {
                    try schema.log_levels.put(level, try al.dupe(u8, def.color));
                },
                .field_type => |ft| {
                    try schema.field_types.put(ft, try al.dupe(u8, def.color));
                },
            }
            txt = result.rest;
        }
        return schema;
    }

    const ColorKey = union(enum) {
        item: ColorableItem,
        log_level: Level,
        field_type: FieldValueType,
    };
    const ColorDefinition = struct {
        item: ColorKey,
        color: []const u8,
    };
    const ColorDefinitionResult = struct {
        def: ColorDefinition,
        rest: []const u8,
    };

    fn parseColorDefinition(text: []const u8) !?ColorDefinitionResult {
        if (text.len == 0) return null;

        var key_name: ?[]const u8 = null;

        var start: usize = 0;
        var ix: usize = 0;
        while (ix < text.len) : (ix += 1) {
            switch (text[ix]) {
                '=' => {
                    key_name = text[start..ix];
                    start = ix + 1;
                },
                ',' => {
                    break;
                },
                else => {},
            }
        }
        if (key_name == null) return error.InvalidColorFormat;
        return .{
            .def = .{
                .item = getColorKey(key_name orelse return error.InvalidColorFormat) orelse return error.InvalidColorFormat,
                .color = text[start..ix],
            },
            .rest = text[@min(ix + 1, text.len)..],
        };
    }
    fn getColorKey(text: []const u8) ?ColorKey {
        const eql = std.mem.eql;
        if (eql(u8, text, "timestamp")) return ColorKey{ .item = .timestamp };
        if (eql(u8, text, "message")) return ColorKey{ .item = .message };
        if (eql(u8, text, "logger")) return ColorKey{ .item = .logger_name };
        if (eql(u8, text, "field_name")) return ColorKey{ .item = .field_name };

        if (eql(u8, text, "trace")) return ColorKey{ .log_level = .trace };
        if (eql(u8, text, "debug")) return ColorKey{ .log_level = .debug };
        if (eql(u8, text, "info")) return ColorKey{ .log_level = .info };
        if (eql(u8, text, "warn")) return ColorKey{ .log_level = .warn };
        if (eql(u8, text, "error")) return ColorKey{ .log_level = .@"error" };

        if (eql(u8, text, "null")) return ColorKey{ .field_type = .null };
        if (eql(u8, text, "bool")) return ColorKey{ .field_type = .bool };
        if (eql(u8, text, "number")) return ColorKey{ .field_type = .number };
        if (eql(u8, text, "string")) return ColorKey{ .field_type = .string };

        return null;
    }

    pub fn initDefault(alloc: std.mem.Allocator) !ColorSchema {
        var schema = try initEmpty(alloc);
        errdefer schema.deinit();

        try schema.items.put(ColorableItem.timestamp, "38;5;243");
        try schema.items.put(ColorableItem.logger_name, "36");
        try schema.items.put(ColorableItem.field_name, "2;97");

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

    pub fn deinit(self: *ColorSchema) void {
        if (self.values_arena) |arena| arena.deinit();
        self.items.deinit();
        self.log_levels.deinit();
        self.field_types.deinit();
    }
};

test "color format 1" {
    var ck = ColorSchema.getColorKey("info");
    try testing.expectEqual(ColorSchema.ColorKey{ .log_level = .info }, ck);

    ck = ColorSchema.getColorKey("abc");
    try testing.expectEqual(null, ck);

    var sc = try ColorSchema.initString("message=31,info=33,string=32;1", testing.allocator);
    defer sc.deinit();

    try testing.expectEqual(1, sc.items.count());
    try testing.expectEqualSlices(u8, sc.items.get(.message).?, "31");

    try testing.expectEqual(1, sc.log_levels.count());
    try testing.expectEqualSlices(u8, sc.log_levels.get(.info).?, "33");

    try testing.expectEqual(1, sc.field_types.count());
    try testing.expectEqualSlices(u8, sc.field_types.get(.string).?, "32;1");
}

pub const Formatter = union(enum) {
    text: ?ColorSchema,
    json,

    pub fn deinit(self: *Formatter) void {
        if (self.text) |*cs| {
            cs.deinit();
        }
    }

    pub fn format(self: *Formatter, w: LogHandler.Writer, event: *const LogEvent) !void {
        var p = ColorPrinter{ .w = w, .color_schema = if (self.text) |txt| &txt else null };

        try p.writeItemColor(.timestamp);
        try event.timestamp.time().gofmt(w, "2006-01-02T15:04:05.000");
        try p.reset();
        try w.writeByte(' ');

        try p.writeLogLevelColor(event.level);
        try w.writeAll(levelName(event.level));
        try p.reset();
        try w.writeByte(' ');

        if (event.logger_name) |lname| {
            try p.writeItemColor(.logger_name);
            try w.writeAll(lname);
            try p.reset();
            try w.writeByte(' ');
        }

        try p.writeItemColor(.message);
        try w.writeAll(event.message);
        try p.reset();
        try w.writeByte(' ');

        for (event.fields, 0..) |entry, ix| {
            if (ix > 0) try w.writeByte(' ');
            try p.writeItemColor(.field_name);
            try w.print("{s}=", .{entry.name});
            try p.reset();
            const value_type: FieldValueType = switch (entry.value) {
                .null => .null,
                .bool => .bool,
                .integer, .float => .number,
                else => .string,
            };
            try p.writeFieldTypeColor(value_type);
            try std.json.stringify(entry.value, .{}, w);
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
    w: LogHandler.Writer,
    color_schema: ?*const ColorSchema,

    const colorClear = "0";

    fn writeItemColor(self: *ColorPrinter, color_item: ColorableItem) !void {
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
