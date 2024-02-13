const std = @import("std");
const dys = @import("dysnomia");

const config_path = "examples/config.json";

// This sets the log function to that of the library
// This isn't necessary, but I think it looks better
pub const std_options = .{
    .logFn = dys.logFn,
};

fn onReady(_: *dys.Client, event: dys.events.Ready) !void {
    std.log.info("logged in as: {s}", .{event.user.username});
}

fn onMessageCreate(self: *dys.Client, event: dys.events.MessageCreate) !void {
    if (event.payload.author.bot) return;
    const msg = event.payload;

    const channel = try self.getChannel(msg.channel_id);

    if (std.mem.startsWith(u8, msg.content, "!ping")) {
        std.debug.print("{s} sent a ping in #{?s}\n", .{ msg.author.username, channel.name });

        _ = try self.createMessage(channel.id, .{ .content = "pong" });
    }
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
        .direct_messages = true,
    };

    client.callbacks = .{
        .on_ready = &onReady,
        .on_message_create = &onMessageCreate,
    };

    try client.connect();
}
