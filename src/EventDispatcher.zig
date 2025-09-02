const std = @import("std");

const LogHandler = @import("./LogHandler.zig");
const SpecNode = @import("./LogLevelSpecNode.zig");
const util = @import("./util.zig");
const Level = util.Level;
const LogEvent = util.LogEvent;

const Self = @This();

handler: *LogHandler,
log_level: Level,
spec: ?*SpecNode = null,

pub fn deinit(self: Self) void {
    self.handler.deinit();
    if (self.spec) |spec| spec.deinit();
}

pub fn dispatch(self: *const Self, event: *const LogEvent) !void {
    if (@intFromEnum(event.level) >= @intFromEnum(self.log_level)) {
        try self.handler.handle(event);
    }
}
pub fn createChildDispatcher(self: *const Self, name: []const u8) Self {
    var result = Self{
        .handler = self.handler,
        .log_level = self.log_level,
    };
    if (self.spec) |spec| {
        var name_chunk_it = std.mem.splitScalar(u8, name, '.');
        var current_spec = spec;
        while (name_chunk_it.next()) |sub_node_name| {
            if (current_spec.kids.get(sub_node_name)) |child_spec| {
                result.log_level = child_spec.logLevel();
                result.spec = child_spec;
                current_spec = child_spec;
            } else break;
        }
    }
    return result;
}
