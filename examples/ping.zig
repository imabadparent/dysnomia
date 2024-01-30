const std = @import("std");
const dys = @import("zigcord");

const config_path = "examples/config.json";

fn onHello(client: *dys.Client, _: dys.events.HelloEvent) !void {
    const user = client.getCurrentUser() catch |err| {
        std.log.err("could not get current user: {}", .{err});
        return;
    };
    std.debug.print("logged in as: {s}\n", .{user.username});
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
    };

    client.callbacks = .{
        .on_hello = &onHello,
    };

    try client.connect();
}
