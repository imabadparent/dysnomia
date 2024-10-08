const std = @import("std");
const dys = @import("dysnomia");

const config_path = "examples/config.json";

/// Setup a listener for the Ready event
/// All listeners take 2 arguments: the client that recieved the event, and the event itself
fn onReady(_: std.mem.Allocator, _: *dys.Client, event: dys.discord.gateway.events.Ready) !void {
    std.log.info("logged in as: {s}", .{event.user.username});
}

/// Setup a listener for the MessageCreate event so we can reply to "!ping" with "pong"
fn onMessageCreate(
    allocator: std.mem.Allocator,
    self: *dys.Client,
    event: dys.discord.gateway.events.MessageCreate,
) !void {
    // Don't respond to bots
    if (event.payload.author.bot) return;

    // recieve the message from the event
    const msg = event.payload;
    // given the channel id (which we get from the message) we can query for the channel object
    const channel = try self.getChannel(msg.channel_id);

    if (std.mem.startsWith(u8, msg.content, "!embed")) {
        var it = std.mem.tokenizeScalar(u8, msg.content, ' ');
        // skip the `!embed` token
        _ = it.next();

        var args = std.ArrayList([]const u8).init(allocator);
        defer args.deinit();
        while (it.next()) |arg| {
            try args.append(arg);
        }
        const items = try args.toOwnedSlice();
        defer allocator.free(items);
        if (items.len < 2) {
            _ = try self.createMessage(channel.id, .{ .content = "Usage: !embed <title> <description> [color]" });
            return;
        }
        const color = if (items.len >= 3) blk: {
            const str = if (items[2][0] == '#') items[2][1..] else items[2];
            const hex = std.fmt.parseInt(u24, str, 16) catch {
                break :blk dys.discord.Color.fromHex(0x000000);
            };
            break :blk dys.discord.Color.fromHex(hex);
        } else dys.discord.Color.fromHex(0x000000);

        const embed = dys.discord.channel.Message.Embed{
            .title = items[0],
            .description = items[1],
            .color = color,
        };
        _ = try self.createMessage(channel.id, .{ .embeds = &.{embed} });
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
