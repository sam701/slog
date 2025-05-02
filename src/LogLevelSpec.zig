const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

const Level = @import("./util.zig").Level;

// const Logger = @import("Logger.zig");
const This = @This();

root: *Node,
allocator: std.mem.Allocator,

pub fn initFromDefaultEnvvar(allocator: Allocator) !This {
    return initFromEnvvar("ZIG_LOG", allocator);
}

const defaultSpec: []const u8 = "info";

pub fn initFromEnvvar(envvarName: []const u8, allocator: Allocator) !This {
    const spec: []const u8 = std.process.getEnvVarOwned(allocator, envvarName) catch defaultSpec;
    defer if (spec.ptr != defaultSpec.ptr) allocator.free(spec);

    return initFromStringSpec(spec, allocator);
}

pub fn initFromStringSpec(spec: []const u8, allocator: Allocator) !This {
    var root = try allocator.create(Node);
    root.* = Node{
        .allocator = allocator,
        .name = "root",
        .parent = null,
        .configured_log_level = Level.info,
        .kids = std.StringHashMap(*Node).init(allocator),
    };
    var spec2 = spec;
    while (try parseChunk(spec2, allocator)) |result| {
        defer if (result.chunk.path) |path| allocator.free(path);

        var node = root;

        if (result.chunk.path) |path| {
            node = try root.getKid(path);
        }
        node.configured_log_level = result.chunk.level;

        spec2 = result.rest;
    }
    return .{
        .root = root,
        .allocator = allocator,
    };
}

pub fn deinit(self: *This) void {
    self.root.deinit();
    self.allocator.destroy(self.root);
}

/// Contains log level for a logger name.
const Node = struct {
    name: []const u8,
    parent: ?*Node,
    configured_log_level: ?Level = null,
    allocator: Allocator,
    kids: std.StringHashMap(*Node),

    fn deinit(self: *Node) void {
        var it = self.kids.valueIterator();
        while (it.next()) |v| {
            v.*.deinit();
            self.allocator.destroy(v.*);
        }
        self.kids.deinit();
        if (self.parent != null) self.allocator.free(self.name);
    }

    pub fn logLevel(self: *const Node) Level {
        return if (self.configured_log_level) |level| level else if (self.parent) |parent| parent.logLevel() else unreachable;
    }

    fn getKid(self: *Node, path: []const []const u8) !*Node {
        if (path.len == 0) return self;

        const head = path[0];

        if (self.kids.get(head)) |kid| {
            return kid.getKid(path[1..]);
        } else {
            var kid = try self.allocator.create(Node);
            kid.* = Node{
                .allocator = self.allocator,
                .name = try self.allocator.dupe(u8, head),
                .parent = self,
                .kids = std.StringHashMap(*Node).init(self.allocator),
            };
            try self.kids.put(kid.name, kid);
            return kid.getKid(path[1..]);
        }
    }
};

/// Has the form [path=]level
const SpecChunk = struct {
    path: ?[]const []const u8 = null,
    level: Level,
};

const ParseChunkResult = struct {
    chunk: SpecChunk,
    rest: []const u8,
};

fn parseChunk(text: []const u8, allocator: Allocator) !?ParseChunkResult {
    if (text.len == 0) return null;

    var path_ar = std.ArrayList([]const u8).init(allocator);

    var start: usize = 0;
    var ix: usize = 0;
    while (ix < text.len) : (ix += 1) {
        switch (text[ix]) {
            '.', '=' => {
                try path_ar.append(text[start..ix]);
                start = ix + 1;
            },
            ',' => {
                break;
            },
            else => {},
        }
    }

    var result = ParseChunkResult{
        .chunk = SpecChunk{
            .level = try Level.parse(text[start..ix]),
        },
        .rest = text[@min(ix + 1, text.len)..],
    };
    if (path_ar.items.len > 0)
        result.chunk.path = try path_ar.toOwnedSlice();
    return result;
}

test "one root" {
    var cfg = try This.initFromStringSpec("debug", testing.allocator);
    defer cfg.deinit();

    try testing.expectEqual(Level.debug, cfg.root.configured_log_level);
    try testing.expectEqual(0, cfg.root.kids.count());
}

test "default" {
    var cfg = try This.initFromStringSpec("info", testing.allocator);
    defer cfg.deinit();

    try testing.expectEqual(Level.info, cfg.root.configured_log_level);
    try testing.expectEqual(0, cfg.root.kids.count());
}

test "one path" {
    var cfg = try This.initFromStringSpec("error,mod1.mod2=warn,mod1.mod3.mod4=trace", testing.allocator);
    defer cfg.deinit();

    try testing.expectEqual(Level.@"error", cfg.root.configured_log_level);
    try testing.expectEqual(1, cfg.root.kids.count());

    const mod1 = cfg.root.kids.get("mod1").?;
    try testing.expectEqual(null, mod1.configured_log_level);
    try testing.expectEqual(Level.@"error", mod1.logLevel());
    try testing.expectEqualSlices(u8, "mod1", mod1.name);

    const mod2 = mod1.kids.get("mod2").?;
    try testing.expectEqual(Level.warn, mod2.configured_log_level);
    try testing.expectEqual(Level.warn, mod2.logLevel());
    try testing.expectEqualSlices(u8, "mod2", mod2.name);

    const mod3 = mod1.kids.get("mod3").?;
    try testing.expectEqual(null, mod3.configured_log_level);
    try testing.expectEqual(Level.@"error", mod3.logLevel());
    try testing.expectEqualSlices(u8, "mod3", mod3.name);

    const mod4 = mod3.kids.get("mod4").?;
    try testing.expectEqual(Level.trace, mod4.configured_log_level);
    try testing.expectEqual(Level.trace, mod4.logLevel());
    try testing.expectEqualSlices(u8, "mod4", mod4.name);
}
