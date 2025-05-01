const std = @import("std");
const testing = std.testing;

const ObjectMap = std.json.ObjectMap;

pub const Registry = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return Registry{ .allocator = allocator };
    }
};
