const std = @import("std");
const zigcord = @import("zigcord");

const config_path = "examples/config.json";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const config = try zigcord.parseConfig(alloc, config_path);
    defer config.deinit();

    var client = try zigcord.Client.init(alloc, config.value, .{});
    defer client.deinit();

    try client.connect();
}
