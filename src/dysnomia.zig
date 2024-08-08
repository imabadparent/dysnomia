const std = @import("std");

pub const log = std.log.scoped(.dysnomia);

/// The client struct which contains everything related to interacting with the Discord account
/// it is logged in as, such as sending and receiving WebSocket events, and sending REST API calls
pub const Client = @import("Client.zig");
/// Contains all of the types related to working with the Discord API
pub const discord = @import("types.zig");

/// Parses the config at `config_path` and returns a parsed json object. The caller is responsible
/// for calling `deinit()` on this object.
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
    std.testing.refAllDecls(@import("types.zig"));
}
