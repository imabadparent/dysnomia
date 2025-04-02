const std = @import("std");
const dys = @import("dysnomia");
const events = dys.discord.gateway.events;

const config_path = "examples/config.json";

/// Setup a listener for the Ready event
/// All listeners take 2 arguments: the client that recieved the event, and the event itself
fn onReady(_: std.mem.Allocator, _: *dys.Client, event: events.Ready) !void {
    std.log.info("logged in as: {s}", .{event.user.username});
}

/// Setup a listener for the ChannelCreate event so we can send a message in it
pub fn onChannelCreate(_: std.mem.Allocator, client: *dys.Client, event: events.ChannelCreate) !void {
    const channel = event.payload;
    std.log.info("channel created: {s}", .{channel.name orelse "unnamed"});

    // send a message in the channel
    _ = try client.createMessage(channel.id, .{ .content = "hello!" });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // the config contains properties necessary to setting up the bot, such as its token and whether
    // it is a bot account or a user account (Discord ToS prohibits automation of user accounts)
    const config = try dys.parseConfig(alloc, config_path);
    defer config.deinit();

    // initialize the client
    var client = try dys.Client.init(alloc, config.value);
    defer client.deinit();

    // establish intents that allow us to read the content of messages and send messages in both guild
    // and direct message channels
    client.intents = .{
        .guilds = true,
    };

    // tell the client about the functions we established earlier to listen to specific events
    client.callbacks = .{
        .on_ready = &onReady,
        .on_channel_create = &onChannelCreate,
    };

    // finally, we can connect to our discrd bot account with our client
    try client.connect();
}
