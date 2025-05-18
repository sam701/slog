const std = @import("std");
const Allocator = std.mem.Allocator;
const ObjectMap = std.json.ObjectMap;
const Value = std.json.Value;

const zeit = @import("zeit");
const TimeZone = zeit.TimeZone;

const EventDispatcher = @import("./EventDispatcher.zig");
const LogHandler = @import("./LogHandler.zig");
const LogLevelSpec = @import("./LogLevelSpec.zig");
const Node = @import("./LogLevelSpecNode.zig");
const util = @import("./util.zig");
const Level = util.Level;
const LogEvent = util.LogEvent;

const Self = @This();

name: ?[]const u8,
allocator: std.mem.Allocator,
constant_fields: ?ObjectMap = null,
dispatcher: EventDispatcher,
parent: ?*Self,
kids: std.ArrayList(*Self),

timezone: *TimeZone,

pub fn initRoot(name: ?[]const u8, spec: LogLevelSpec, handler: *LogHandler, alloc: Allocator) !*Self {
    const node = spec.root;
    const self = try alloc.create(Self);

    const tz = try alloc.create(TimeZone);
    tz.* = try zeit.local(alloc, null);

    self.* = .{
        .name = name,
        .allocator = alloc,
        .dispatcher = EventDispatcher{
            .handler = handler,
            .spec = node,
            .log_level = node.logLevel(),
        },
        .parent = null,
        .kids = std.ArrayList(*Self).init(alloc),
        .timezone = tz,
    };
    return self;
}

pub fn deinit(self: *Self) void {
    for (self.kids.items) |kid| kid.deinit();
    self.kids.deinit();

    if (self.constant_fields) |*fields| fields.deinit();
    if (self.name) |name| self.allocator.free(name);
    if (self.parent) |parent| {
        parent.removeKid(self);
    } else {
        self.timezone.deinit();
        self.allocator.destroy(self.timezone);

        self.dispatcher.handler.deinit();
        if (self.dispatcher.spec) |spec| spec.deinit();

        self.allocator.destroy(self.dispatcher.handler);
    }
    self.allocator.destroy(self);
}

pub fn initChildLogger(self: *Self, name: []const u8) !*Self {
    var lname: []u8 = undefined;
    if (self.name) |self_name| {
        lname = try self.allocator.alloc(u8, self_name.len + name.len + 1);
        @memcpy(lname[0..self_name.len], self_name);
        lname[self_name.len] = '.';
        @memcpy(lname[self_name.len + 1 ..], name);
    } else {
        lname = try self.allocator.dupe(u8, name);
    }

    const kid = try self.allocator.create(Self);

    kid.* = Self{
        .name = lname,
        .allocator = self.allocator,
        .constant_fields = if (self.constant_fields) |fields| try fields.clone() else null,
        .dispatcher = self.dispatcher.createChildDispatcher(name),
        .parent = self,
        .kids = std.ArrayList(*Self).init(self.allocator),
        .timezone = self.timezone,
    };
    try self.kids.append(kid);
    return kid;
}

fn removeKid(self: *Self, kid_ptr: *const Self) void {
    var kids_index: ?usize = null;
    for (self.kids.items, 0..) |kid, ix| {
        if (kid == kid_ptr) {
            kids_index = ix;
            break;
        }
    }
    if (kids_index) |ix| {
        _ = self.kids.swapRemove(ix);
    } else unreachable;
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
    return self.log(Level.warn, message, fields);
}

pub fn err(self: *Self, message: []const u8, fields: anytype) !void {
    return self.log(Level.@"error", message, fields);
}

fn log(self: *Self, level: Level, message: []const u8, fields: anytype) !void {
    // TODO: consider to get rid of the LogEvent to avoid unnecessary memory allocation.
    var event = LogEvent{
        .timestamp = try zeit.instant(.{ .source = .now, .timezone = self.timezone }),
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
            .bool => Value{ .bool = @field(fields, field.name) },
            .null => Value.null,
            else => {
                @compileError(std.fmt.comptimePrint("unsupported type: {any}", .{field_type}));
            },
        };
        try map.put(field.name, value);
    }

    return map;
}
