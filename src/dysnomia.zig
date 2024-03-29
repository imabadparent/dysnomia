const std = @import("std");

pub const log = std.log.scoped(.dysnomia);

pub const std_options = .{
    .logFn = logFn,
};

pub const Client = @import("Client.zig");
const types = @import("types.zig");

pub usingnamespace types;

const dys = @This();
/// Will parse your config from a json file for you
/// Allows you to not hardcode your token
pub fn parseConfig(
    allocator: std.mem.Allocator,
    config_path: []const u8,
) !std.json.Parsed(Client.Config) {
    const config = try std.fs.cwd().readFileAlloc(allocator, config_path, 4096);
    defer allocator.free(config);

    const parsed = std.json.parseFromSlice(
        Client.Config,
        allocator,
        config,
        .{ .allocate = .alloc_always },
    ) catch |err| {
        std.log.err("Error parsing config: {}\n", .{err});
        return err;
    };

    return parsed;
}

test {
    _ = @import("types.zig");
}

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    // [TIME][SCOPE][LEVEL] MESSAGE
    const prefix = "[" ++ @tagName(scope) ++ "]" ++ "[" ++ comptime level.asText() ++ "] ";

    std.debug.print(prefix ++ format ++ "\n", args);
}
