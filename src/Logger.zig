const std = @import("std");
const Allocator = std.mem.Allocator;
const ObjectMap = std.json.ObjectMap;
const Value = std.json.Value;

const EventDispatcher = @import("handler.zig").EventDispatcher;
const util = @import("util.zig");
const Level = util.Level;
const LogEvent = util.LogEvent;

const This = @This();

name: []const u8,
allocator: std.mem.Allocator,
constant_fields: ?ObjectMap = null,
dispatcher: EventDispatcher,

pub fn init(name: []const u8, allocator: Allocator, dispatcher: EventDispatcher) This {
    return This{
        .name = allocator.dupe(u8, name),
        .allocator = allocator,
        .dispatcher = dispatcher,
    };
}

pub fn deinit(self: *This) void {
    if (self.constant_fields) |fields| {
        fields.deinit();
    }
    self.allocator.free(self.name);
}

pub fn newChildLogger(self: *const This, name: []const u8) This {
    var lname = try self.allocator.alloc(u8, self.name.len + name.len + 1);
    @memcpy(lname, self.name);
    lname[self.name.len] = '.';
    @memcpy(lname[self.name.len + 1 ..], lname);

    return This{
        .name = lname,
        .allocator = self.allocator,
        .constant_fields = if (self.constant_fields) |fields| fields.clone() else null,
        .dispatcher = self.dispatcher.createChildDispatcher(name),
    };
}

pub fn trace(self: *const This, message: []const u8, fields: anytype) void {
    self.log(Level.Trace, message, fields);
}

pub fn debug(self: *const This, message: []const u8, fields: anytype) void {
    self.log(Level.Debug, message, fields);
}

pub fn info(self: *const This, message: []const u8, fields: anytype) void {
    self.log(Level.Info, message, fields);
}

pub fn warn(self: *const This, message: []const u8, fields: anytype) void {
    self.log(Level.Warn, message, fields);
}

pub fn err(self: *const This, message: []const u8, fields: anytype) void {
    self.log(Level.Error, message, fields);
}

fn log(self: *const This, level: Level, message: []const u8, fields: anytype) void {
    // TODO: consider to get rid of the LogEvent to avoid unnecessary memory allocation.
    const event = LogEvent{
        .timestamp_millis = std.time.milliTimestamp(),
        .logger_name = self.name,
        .level = level,
        .message = message,
        .constant_fields = self.constant_fields,
        .fields = try self.toObjectMap(fields),
    };
    defer event.fields.deinit();

    try self.dispatcher.dispatch(&event);
}

fn toObjectMap(self: *const This, fields: anytype) !ObjectMap {
    var map = try ObjectMap.init(self.allocator);

    const FieldsType = @TypeOf(fields);
    const ti = @typeInfo(FieldsType);
    if (ti != .@"struct") {
        @compileError(std.fmt.comptimePrint("expected struct, but found {s}={any}", .{ @typeName(FieldsType), fields }));
    }

    const ff = ti.@"struct".fields;
    inline for (ff) |field| {
        std.debug.print("aa = {any}\n", .{@typeInfo(field.type)});
        const field_type = @typeInfo(field.type);
        const value: Value = val: switch (field_type) {
            .pointer => |pti| {
                const cti = @typeInfo(pti.child);
                if (cti == .array and cti.array.child == u8) {
                    break :val Value{ .string = @field(fields, field.name) };
                }
                unreachable;
            },
            .int => Value{ .integer = @field(fields, field.name) },
            .float => Value{ .float = @field(fields, field.name) },
            else => {
                @compileError(std.fmt.comptimePrint("unsupported type: {any}", .{field_type}));
            },
        };
        try map.put(field.name, value);
    }

    return map;
}
