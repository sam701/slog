const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

const Node = @import("./LogLevelSpecNode.zig");
const Level = @import("./util.zig").Level;

// const Logger = @import("Logger.zig");
const Self = @This();

root: *Node,

const defaultSpec: []const u8 = "info";

pub fn initFromEnvvar(envvarName: []const u8, allocator: Allocator) !Self {
    const spec: []const u8 = std.process.getEnvVarOwned(allocator, envvarName) catch defaultSpec;
    defer if (spec.ptr != defaultSpec.ptr) allocator.free(spec);

    return initFromStringSpec(spec, allocator) catch
        return initFromStringSpec(defaultSpec, allocator);
}

pub fn initFromStringSpec(spec: []const u8, alloc: Allocator) !Self {
    var root = try alloc.create(Node);
    errdefer alloc.destroy(root);
    root.* = Node{
        .name = "root",
        .parent = null,
        .configured_log_level = Level.info,
        .kids = std.StringHashMap(*Node).init(alloc),
        .allocator = alloc,
    };
    var spec2 = spec;
    while (try parseChunk(spec2, alloc)) |result| {
        defer if (result.chunk.path) |path| alloc.free(path);

        var node = root;

        if (result.chunk.path) |path| {
            node = try root.getKid(path);
        }
        node.configured_log_level = result.chunk.level;

        spec2 = result.rest;
    }
    return .{
        .root = root,
    };
}

pub fn deinit(self: *Self) void {
    self.root.deinit();
}

pub fn findNode(self: *const Self, module_name: []const u8) *const Node {
    return self.root.kids.get(module_name) orelse self.root;
}

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
    var cfg = try Self.initFromStringSpec("debug", testing.allocator);
    defer cfg.deinit();

    try testing.expectEqual(Level.debug, cfg.root.configured_log_level);
    try testing.expectEqual(0, cfg.root.kids.count());
}

test "default" {
    var cfg = try Self.initFromStringSpec("info", testing.allocator);
    defer cfg.deinit();

    try testing.expectEqual(Level.info, cfg.root.configured_log_level);
    try testing.expectEqual(0, cfg.root.kids.count());
}

test "one path" {
    var cfg = try Self.initFromStringSpec("error,mod1.mod2=warn,mod1.mod3.mod4=trace", testing.allocator);
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
