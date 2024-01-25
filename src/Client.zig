const std = @import("std");
const http = std.http;
const json = std.json;

const Self = @This();

const Config = struct {
    token: []const u8,
};

const base = "https://discord.com/api/v10/";

token: []const u8,
arena: std.heap.ArenaAllocator,

pub fn init(allocator: std.mem.Allocator, token: []const u8) !Self {
    var result: Self = undefined;
    result.arena = std.heap.ArenaAllocator.init(allocator);
    const tok = try result.arena.allocator().alloc(u8, token.len + 4);
    @memcpy(tok[0..4], "Bot ");
    @memcpy(tok[4..], token);
    result.token = tok;

    return result;
}

pub fn initConfig(allocator: std.mem.Allocator, config_path: []const u8) !Self {
    const config = try std.fs.cwd().readFileAlloc(allocator, config_path, 4096);
    defer allocator.free(config);
    const parsed = json.parseFromSlice(
        Config,
        allocator,
        config,
        .{ .allocate = .alloc_always },
    ) catch |err| {
        std.log.err("Error parsing config: {}\n", .{err});
        return err;
    };
    defer parsed.deinit();

    return init(allocator, parsed.value.token);
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

pub fn connect(self: *Self) !void {
    const endpoint = base ++ "/gateway/bot";
    var client = http.Client{ .allocator = self.arena.allocator() };
    defer client.deinit();

    var headers = http.Headers.init(self.arena.allocator());
    defer headers.deinit();
    try headers.append("Authorization", self.token);

    var result = try client.fetch(self.arena.allocator(), .{ .location = endpoint });
    defer result.deinit();
    if (result.status != .ok) return error.UnableToGetGateway;
}
