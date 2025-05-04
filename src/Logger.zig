const std = @import("std");
const Allocator = std.mem.Allocator;
const ObjectMap = std.json.ObjectMap;
const Value = std.json.Value;

const zeit = @import("zeit");

const EventDispatcher = @import("./EventDispatcher.zig");
const LogHandler = @import("./LogHandler.zig");
const LogLevelSpec = @import("./LogLevelSpec.zig");
const Node = @import("./LogLevelSpecNode.zig");
const util = @import("./util.zig");
const Level = util.Level;
const LogEvent = util.LogEvent;

const Self = @This();

name: []const u8,
allocator: std.mem.Allocator,
constant_fields: ?ObjectMap = null,
dispatcher: EventDispatcher,

pub fn init(name: []const u8, spec: *const LogLevelSpec, handler: *LogHandler) !Self {
    const node = spec.findNode(name);
    return Self{
        .name = try spec.allocator.dupe(u8, name),
        .allocator = spec.allocator,
        .dispatcher = EventDispatcher{
            .handler = handler,
            .spec = node,
            .log_level = node.logLevel(),
        },
    };
}

pub fn deinit(self: *Self) void {
    if (self.constant_fields) |*fields| fields.deinit();
    self.allocator.free(self.name);
}

pub fn newChildLogger(self: *const Self, name: []const u8) !Self {
    var lname = try self.allocator.alloc(u8, self.name.len + name.len + 1);
    @memcpy(lname[0..self.name.len], self.name);
    lname[self.name.len] = '.';
    @memcpy(lname[self.name.len + 1 ..], name);

    return Self{
        .name = lname,
        .allocator = self.allocator,
        .constant_fields = if (self.constant_fields) |fields| try fields.clone() else null,
        .dispatcher = self.dispatcher.createChildDispatcher(name),
    };
}

pub fn trace(self: *Self, message: []const u8, fields: anytype) !void {
    return self.log(Level.trace, message, fields);
}

pub fn debug(self: *Self, message: []const u8, fields: anytype) !void {
    return self.log(Level.debug, message, fields);
}

pub fn info(self: *Self, message: []const u8, fields: anytype) !void {
    return self.log(Level.info, message, fields);
}

pub fn warn(self: *Self, message: []const u8, fields: anytype) !void {
    self.log(Level.warn, message, fields);
}

pub fn err(self: *Self, message: []const u8, fields: anytype) !void {
    return self.log(Level.@"error", message, fields);
}

fn log(self: *Self, level: Level, message: []const u8, fields: anytype) !void {
    const ts = try zeit.local(self.allocator, null);
    defer ts.deinit();

    // TODO: consider to get rid of the LogEvent to avoid unnecessary memory allocation.
    var event = LogEvent{
        .timestamp = try zeit.instant(.{ .source = .now, .timezone = &ts }),
        .logger_name = self.name,
        .level = level,
        .message = message,
        .constant_fields = self.constant_fields,
        .fields = try self.toObjectMap(fields),
    };
    defer event.fields.deinit();

    try self.dispatcher.dispatch(&event);
}

fn toObjectMap(self: *const Self, fields: anytype) !ObjectMap {
    var map = ObjectMap.init(self.allocator);

    const FieldsType = @TypeOf(fields);
    const ti = @typeInfo(FieldsType);
    if (ti != .@"struct") {
        @compileError(std.fmt.comptimePrint("expected struct, but found {s}={any}", .{ @typeName(FieldsType), fields }));
    }

    const ff = ti.@"struct".fields;
    inline for (ff) |field| {
        const field_type = @typeInfo(field.type);
        const value: Value = val: switch (field_type) {
            .pointer => |pti| {
                const cti = @typeInfo(pti.child);
                if (cti == .array and cti.array.child == u8) {
                    break :val Value{ .string = @field(fields, field.name) };
                }
                unreachable;
            },
            .int, .comptime_int => Value{ .integer = @field(fields, field.name) },
            .float, .comptime_float => Value{ .float = @field(fields, field.name) },
            else => {
                @compileError(std.fmt.comptimePrint("unsupported type: {any}", .{field_type}));
            },
        };
        try map.put(field.name, value);
    }

    return map;
}
