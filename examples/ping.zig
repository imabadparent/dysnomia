const std = @import("std");
const dys = @import("dysnomia");

const config_path = "examples/config.json";

/// Setup a listener for the Ready event
/// All listeners take 2 arguments: the client that recieved the event, and the event itself
fn onReady(_: *dys.Client, event: dys.events.Ready) !void {
    std.log.info("logged in as: {s}", .{event.user.username});
}

/// Setup a listener for the MessageCreate event so we can reply to "!ping" with "pong"
fn onMessageCreate(self: *dys.Client, event: dys.events.MessageCreate) !void {
    // Don't respond to bots
    if (event.payload.author.bot) return;

    // recieve the message from the event
    const msg = event.payload;
    // given the channel id (which we get from the message) we can query for the channel object
    const channel = try self.getChannel(msg.channel_id);

    // we only want to respond "pong" if the message starts with the "!ping" command
    if (std.mem.startsWith(u8, msg.content, "!ping")) {
        // log who send the message and in what channel
        std.debug.print("{s} sent a ping in #{?s}\n", .{ msg.author.username, channel.name });

        // try to send a message that says "pong" in the same channel in which the command was sent
        // this function returns the created message object, but we discard it as it is not relevant
        // for our purposes
        _ = try self.createMessage(channel.id, .{ .content = "pong" });
    }
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
        .message_content = true,
        .guild_messages = true,
        .direct_messages = true,
    };

    // tell the client about the functions we established earlier to listen to specific events
    client.callbacks = .{
        .on_ready = &onReady,
        .on_message_create = &onMessageCreate,
    };

    // finally, we can connect to our discrd bot account with our client
    try client.connect();
}
