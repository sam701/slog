const LogHandler = @import("./LogHandler.zig");
const SpecNode = @import("./LogLevelSpecNode.zig");
const util = @import("./util.zig");
const Level = util.Level;
const LogEvent = util.LogEvent;

const Self = @This();

handler: *LogHandler,
log_level: Level,
spec: ?*const SpecNode = null,

pub fn dispatch(self: *const Self, event: *const LogEvent) !void {
    if (@intFromEnum(event.level) >= @intFromEnum(self.log_level)) {
        try self.handler.handle(event);
    }
}

pub fn createChildDispatcher(self: *const Self, name: []const u8) Self {
    if (self.spec) |spec| {
        if (spec.kids.get(name)) |child_spec| {
            return Self{
                .handler = self.handler,
                .log_level = child_spec.logLevel(),
                .spec = child_spec,
            };
        }
    }
    return Self{
        .handler = self.handler,
        .log_level = self.log_level,
    };
}
