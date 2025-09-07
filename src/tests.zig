const std = @import("std");
const Writer = std.Io.Writer;
const Logger = @import("./Logger.zig");
const Options = @import("./root.zig").Options;
const initRootLogger = @import("./root.zig").initRootLogger;
const SpecSource = @import("./root.zig").SpecSource;
const testing = std.testing;

const TestingLogger = struct {
    allocating: *Writer.Allocating,
    logger: *Logger,

    fn init(options: Options) !TestingLogger {
        var al = try testing.allocator.create(Writer.Allocating);
        al.* = Writer.Allocating.init(testing.allocator);

        var opt = options;
        opt.output = .{ .writer = &al.writer };
        return .{
            .allocating = al,
            .logger = try initRootLogger(testing.allocator, opt),
        };
    }

    pub fn deinit(self: *TestingLogger) void {
        const al = self.allocating.allocator;
        self.allocating.deinit();
        self.logger.deinit();
        al.destroy(self.allocating);
    }

    fn hasPattern(self: TestingLogger, pattern: []const u8) !void {
        try testing.expect(std.mem.indexOf(u8, self.allocating.written(), pattern).? >= 0);
    }

    fn hasNotPattern(self: TestingLogger, pattern: []const u8) !void {
        try testing.expect(std.mem.indexOf(u8, self.allocating.written(), pattern) == null);
    }
};

test "text logger" {
    var tl = try TestingLogger.init(.{
        .log_spec = SpecSource{ .from_string = "warn" },
        .color = .always,
    });
    defer tl.deinit();

    var log2 = try tl.logger.initChildLogger("kid1");

    tl.logger.info("info test aa11", .{ .field1 = "value1", .name = "John", .age = 30 });
    log2.trace("Hello, aa22", .{ .field1 = "value1", .name = "John", .age = 30 });
    log2.debug("Hello, aa33", .{ .field1 = "value1", .name = "John", .age = 30 });
    log2.info("Hello, aa44", .{ .field1 = "value1", .name = "John", .age = 30e2 });
    log2.warn("Hello, aa55", .{ .field1 = "value1", .name = "John", .age = 30.34534 });
    log2.err("Hello, aa66", .{ .field1 = "value1", .name = "John Smith", .age = 30, .active = true, .nothing = null });

    var log3 = try log2.initChildLogger("kid1-1");
    var log4 = try log2.initChildLogger("kid1-2");
    try testing.expectEqual(2, log2.kids.items.len);
    log3.warn("abc77", .{ .f1 = "v1" });
    log4.err("abc88", .{ .f1 = "v1" });

    log3.deinit();
    try testing.expectEqual(1, log2.kids.items.len);

    try tl.hasNotPattern("aa11");
    try tl.hasNotPattern("aa22");
    try tl.hasNotPattern("aa33");
    try tl.hasNotPattern("aa44");
    try tl.hasPattern("aa55");
    try tl.hasPattern("aa66");
    try tl.hasPattern("abc77");
    try tl.hasPattern("abc88");
}

test "json logger" {
    var tl = try TestingLogger.init(.{ .formatter = .json });
    tl.logger.info("Hello\tslog!", .{ .field1 = "value1", .field2 = "value1", .rate = 30 });
    defer tl.deinit();

    try tl.hasPattern("message\":\"Hello\\t");
    try tl.hasPattern("field1\":\"value1\"");
}

test "root logger level abc" {
    var tl = try TestingLogger.init(.{
        .root_logger_name = "abc",
        .log_spec = SpecSource{ .from_string = "info,abc=debug,n1=trace" },
    });
    defer tl.deinit();
    tl.logger.debug("abcd", .{});

    try tl.hasPattern("abcd");
}

test "root logger level 2" {
    var tl = try TestingLogger.init(.{
        .root_logger_name = "abc",
        .log_spec = SpecSource{ .from_string = "abc=debug,n1=trace" },
    });
    defer tl.deinit();
    tl.logger.debug("abcd", .{});

    try tl.hasPattern("abcd");
}

test "logger with dots in name" {
    var tl = try TestingLogger.init(.{
        .root_logger_name = "ab.cd.ef",
        .log_spec = SpecSource{ .from_string = "error,ab=info" },
    });
    defer tl.deinit();
    tl.logger.info("text1", .{});
    tl.logger.debug("text2", .{});

    try tl.hasPattern("text1");
    try tl.hasNotPattern("text2");
}

test "logger with dots in name: deep spec" {
    var tl = try TestingLogger.init(.{
        .root_logger_name = "ab.cd.ef",
        .log_spec = SpecSource{ .from_string = "error,ab.cd=debug,ab.cd.ef.gh=warn" },
    });
    defer tl.deinit();
    tl.logger.info("text1", .{});
    tl.logger.debug("text2", .{});

    try tl.hasPattern("text1");
    try tl.hasPattern("text2");

    var log2 = try tl.logger.initChildLogger("gh");
    log2.info("text3", .{});
    try tl.hasNotPattern("text3");
}

test "logger with dots in name: child logger" {
    var tl = try TestingLogger.init(.{
        .log_spec = SpecSource{ .from_string = "error,ab.cd=info,ab.cd.ef=debug" },
    });
    defer tl.deinit();

    var log2 = try tl.logger.initChildLogger("ab.cd");
    log2.info("text1", .{});
    log2.debug("text2", .{});
    try tl.hasPattern("text1");
    try tl.hasNotPattern("text2");

    var log3 = try log2.initChildLogger("ef");
    log3.info("text3", .{});
    log3.debug("text4", .{});
    try tl.hasPattern("text3");
    try tl.hasPattern("text4");
}
