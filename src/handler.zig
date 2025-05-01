const util = @import("util.zig");
const OutputStream = util.OutputStream;
const Formatter = util.Formatter;
const Level = util.Level;

pub const LogHandler = struct {
    output_stream: OutputStream,
    formatter: Formatter,

    fn handle(self: *const LogHandler, event: *const LogEvent) !void {
        try self.formatter.format(self.output_stream, event);
    }
};

pub const EventDispatcher = struct {
    handler: *const LogHandler,
    log_level: Level,
    spec: ?*const LogLevelSpec = null,

    pub fn dispatch(self: *const EventDispatcher, event: *const LogEvent) !void {
        if (event.level >= self.log_level) {
            try self.handler.handle(event);
        }
    }

    pub fn createChildDispatcher(self: *const EventDispatcher, name: []const u8) EventDispatcher {
        if (self.spec) |spec| {
            if (spec.kids.get(name)) |child_spec| {
                return EventDispatcher{
                    .handler = self.handler,
                    .log_level = self.child_spec.log_level,
                    .spec = child_spec,
                };
            }
        }
        return EventDispatcher{
            .handler = self.handler,
            .log_level = self.log_level,
        };
    }
};
