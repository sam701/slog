const std = @import("std");
const ObjectMap = std.json.ObjectMap;
const LogLevelSpec = @import("./LogLevelSpec.zig");

pub const Registry = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return Registry{ .allocator = allocator };
    }
};

comptime {
    _ = @import("./LogLevelSpec.zig");
}
