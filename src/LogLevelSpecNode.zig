const std = @import("std");
const Allocator = std.mem.Allocator;

const Level = @import("./util.zig").Level;

const Self = @This();

name: []const u8,
configured_log_level: ?Level = null,

parent: ?*Self,
kids: std.StringHashMap(*Self),

pub fn deinit(self: *Self, alloc: Allocator) void {
    var it = self.kids.valueIterator();
    while (it.next()) |v| {
        v.*.deinit(alloc);
        alloc.destroy(v.*);
    }
    self.kids.deinit();
    if (self.parent != null) alloc.free(self.name);
}

pub fn logLevel(self: *const Self) Level {
    return if (self.configured_log_level) |level| level else if (self.parent) |parent| parent.logLevel() else unreachable;
}

pub fn getKid(self: *Self, path: []const []const u8, alloc: Allocator) !*Self {
    if (path.len == 0) return self;

    const head = path[0];

    if (self.kids.get(head)) |kid| {
        return kid.getKid(path[1..], alloc);
    } else {
        var kid = try alloc.create(Self);
        kid.* = Self{
            .name = try alloc.dupe(u8, head),
            .parent = self,
            .kids = std.StringHashMap(*Self).init(alloc),
        };
        try self.kids.put(kid.name, kid);
        return kid.getKid(path[1..], alloc);
    }
}
