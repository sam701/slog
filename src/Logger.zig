const std = @import("std");
const Allocator = std.mem.Allocator;
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
const Field = util.Field;

const Self = @This();

name: ?[]const u8,
allocator: std.mem.Allocator,
constant_fields: ?[]Field = null,
dispatcher: EventDispatcher,
parent: ?*Self,
kids: std.ArrayList(*Self),

timezone: *TimeZone,

pub fn initRoot(name: ?[]const u8, spec: LogLevelSpec, handler: *LogHandler, alloc: Allocator) !*Self {
    var node = spec.root;
    const self = try alloc.create(Self);

    const tz = try alloc.create(TimeZone);
    tz.* = try zeit.local(alloc, null);

    if (name) |root_name| {
        if (spec.root.kids.get(root_name)) |kid| {
            // If there is a kid with the same name as the root, promote it to the root.
            kid.configured_log_level = kid.logLevel();
            kid.parent = null;
            node = kid;
            _ = spec.root.kids.remove(root_name);

            var s = spec;
            s.deinit();
        }
    }

    self.* = .{
        .name = if (name) |n| try alloc.dupe(u8, n) else null,
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

    if (self.constant_fields) |fields| fields: {
        if (self.parent) |parent| {
            if (parent.constant_fields) |parent_fields| {
                if (parent_fields.ptr == fields.ptr) break :fields;
            }
        }
        self.deinitFields(fields, true);
    }

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

fn deinitFields(self: *const Self, fields: []Field, free_values: bool) void {
    for (fields) |f| {
        if (free_values) {
            self.allocator.free(f.name);
            switch (f.value) {
                .string => |str| self.allocator.free(str),
                else => {},
            }
        }
    }
    self.allocator.free(fields);
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
        .constant_fields = self.constant_fields,
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

pub fn trace(self: *Self, message: []const u8, fields: anytype) void {
    return self.log(Level.trace, message, fields) catch return;
}

pub fn debug(self: *Self, message: []const u8, fields: anytype) void {
    return self.log(Level.debug, message, fields) catch return;
}

pub fn info(self: *Self, message: []const u8, fields: anytype) void {
    return self.log(Level.info, message, fields) catch return;
}

pub fn warn(self: *Self, message: []const u8, fields: anytype) void {
    return self.log(Level.warn, message, fields) catch return;
}

pub fn err(self: *Self, message: []const u8, fields: anytype) void {
    return self.log(Level.@"error", message, fields) catch return;
}

fn log(self: *Self, level: Level, message: []const u8, fields: anytype) !void {
    // TODO: consider to get rid of the LogEvent to avoid unnecessary memory allocation.
    var event = LogEvent{
        .timestamp = try zeit.instant(.{ .source = .now, .timezone = self.timezone }),
        .logger_name = self.name,
        .level = level,
        .message = message,
        .constant_fields = self.constant_fields,
        .fields = try self.toFieldList(fields),
    };
    defer self.deinitFields(event.fields, false);

    try self.dispatcher.dispatch(&event);
}

fn toFieldList(self: *const Self, fields: anytype) ![]Field {
    var field_list = std.ArrayList(Field).init(self.allocator);

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
                if (pti.child == u8 or cti == .array and cti.array.child == u8) {
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
        try field_list.append(Field{ .name = field.name, .value = value });
    }

    return field_list.toOwnedSlice();
}
