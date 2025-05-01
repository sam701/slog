const std = @import("std");
const Allocator = std.mem.Allocator;
const util = @import("util.zig");
const Level = util.Level;
const OutputStream = util.OutputStream;
const ColorUsage = util.ColorUsage;
const LogLevelSpecNode = util.LogLevelSpecNode;
const Logger = @import("Logger.zig");

const This = @This();

root: LogLevelSpecNode,
allocator: std.mem.Allocator,

pub fn initFromDefaultEnvvar(allocator: Allocator) !This {
    return initFromEnvvar("ZIG_LOG", allocator);
}

pub fn initFromEnvvar(envvarName: []const u8, allocator: Allocator) !This {
    const spec = try std.process.getEnvVarOwned(allocator, envvarName);
    defer allocator.free(spec);
    return initFromStringSpec(spec);
}

pub fn initFromStringSpec(spec: []const u8, allocator: Allocator) !This {
    unreachable;
}

pub fn createLogger(self: *const This, name: []const u8) !Logger {
    unreachable;
}
