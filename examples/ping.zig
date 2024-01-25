const std = @import("std");
const zigcord = @import("zigcord");

const config_path = "examples/config.json";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var client = try zigcord.Client.initConfig(alloc, config_path);
    defer client.deinit();

    std.debug.print("token -> {s}\n", .{client.token});
}
