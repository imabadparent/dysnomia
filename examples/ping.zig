const std = @import("std");
const dys = @import("dysnomia");

const config_path = "examples/config.json";

fn onReady(_: *dys.Client, event: dys.events.ReadyEvent) !void {
    std.log.info("logged in as: {s}", .{event.user.username});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const config = try dys.parseConfig(alloc, config_path);
    defer config.deinit();

    var client = try dys.Client.init(alloc, config.value);
    defer client.deinit();

    client.intents = .{
        .message_content = true,
        .guild_messages = true,
    };

    client.callbacks = .{
        .on_ready = &onReady,
    };

    try client.connect();
}
