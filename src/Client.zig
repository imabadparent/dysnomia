const std = @import("std");
const ws = @import("websocket");
const dys = @import("dysnomia.zig");
const http = std.http;
const Request = http.Client.Request;
const json = std.json;

const Client = @This();

const EventList = std.ArrayList(dys.discord.gateway.events.Event);

fn Buffer(comptime size: comptime_int) type {
    return struct {
        const Self = @This();

        const Writer = std.io.Writer(*Self, error{OutOfMemory}, write);

        buf: [size]u8 = .{0} ** size,
        pos: usize = 0,

        fn writer(self: *Self) Writer {
            return Writer{ .context = self };
        }

        fn write(self: *Self, data: []const u8) !usize {
            if (self.pos >= self.buf.len) return error.OutOfMemory;

            var pos: usize = 0;
            while (self.pos + pos < self.buf.len and pos < data.len) : (pos += 1) {
                self.buf[self.pos + pos] = data[pos];
            }
            self.pos += pos;

            return pos;
        }
    };
}

/// A helper function for creating callback function types
pub fn Callback(comptime T: type) type {
    return *const fn (self: *Client, event: T) anyerror!void;
}

/// Config for the bot, can be parsed from json using `dysnomia.parseConfig("path/to/config");`
pub const Config = struct {
    /// Optional, whether to connect as a bot (default) or not. Note: connecting with a normal user
    /// token is generally against Discord ToS. Use at your own risk.
    bot: ?bool = true,
    /// The token used to connect to discord.
    token: []const u8,
};

/// The base url for the discord api
const base = "https://discord.com/api/v10";

/// Gateway intents, tells Discord what events we want to listen to and what information to send
intents: dys.discord.gateway.Intents = .{},
callbacks: struct {
    /// Called when the client recieves the `Ready` event
    on_ready: ?Callback(dys.discord.gateway.events.Ready) = null,
    /// Called when the client recieves the `MessageCreate` event
    on_message_create: ?Callback(dys.discord.gateway.events.MessageCreate) = null,
    /// Called when the client recieves an event that is not yet covered by the library.
    /// This allows users to handle raw events that the library doesn't yet have types for
    on_unknown: ?Callback(json.Value) = null,
} = .{},

// Private fields
_arena: std.heap.ArenaAllocator,
/// The token used to login to a Discord account
_token: []const u8,
/// The underlying http client from `std.zig`
_httpclient: http.Client,
_headers: Request.Headers,
/// The underlying ws client from `websocket.zig`
_wsclient: ?ws.Client = null,
/// Whether the client has sent a `Close` event
_sent_close: bool = false,
/// stack of websocket events
_events: EventList,
/// The interval at which to send heartbeat events
_heartbeat_interval: ?i64 = null,
/// Whether we are waiting for a heartbeat acknowledgement
_awaiting_ack: bool = false,
_seq: ?i64 = null,

/// Create the bot, run the `connect()` method to start
/// Caller should call `deinit()` when done
pub fn init(allocator: std.mem.Allocator, config: Config) !Client {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const tok = if (config.bot orelse true)
        try std.fmt.allocPrint(arena.allocator(), "Bot {s}", .{config.token})
    else
        try std.fmt.allocPrint(arena.allocator(), "Bearer {s}", .{config.token});

    return Client{
        .callbacks = .{},
        ._arena = arena,
        ._token = tok,
        ._httpclient = http.Client{ .allocator = allocator },
        ._headers = .{ .user_agent = .{
            .override = "DiscordBot (https://github.com/imabadparent/dysnomia, 0.1.0)",
        }, .authorization = .{ .override = tok }, .content_type = .{ .override = "application/json" } },
        ._events = EventList.init(allocator),
    };
}

/// Deinitializes the bot, freeing all its memory
pub fn deinit(self: *Client) void {
    self._httpclient.deinit();
    self._events.deinit();
    self._arena.deinit();
}

/// Connect to discord gateway and start listening for events.
/// This is the function that triggers the main event loop, and should only be called after
/// initial bot setup, such as adding intents and callbacks, is done.
pub fn connect(self: *Client) !void {
    // Don't try to start a new connection if we already have a websocket client
    if (self._wsclient) |_| return;

    const gateway = try self.getGateway();
    // ensure we are allowed to start a new session
    if (gateway.session_start_limit.remaining <= 0) return error.NoSessionsLeft;
    // create the arena for the client to operate in; all of the clients allocations use this arena
    const allocator = self._arena.allocator();

    // strip the first six characters (`wss://`) of the gateway url because websocket.zig expects
    // a url without a protocol
    const host = gateway.url[6..];
    self._wsclient = try ws.connect(
        allocator,
        host,
        443,
        .{
            .tls = true,
            .handle_close = true,
        },
    );

    // set the api version (10) and the econding format (json)
    const options = "/?v=10&encoding=json";
    const headers = try std.fmt.allocPrint(allocator, "host: {s}\r\n", .{host});
    try self._wsclient.?.handshake(options, .{ .headers = headers });

    // start the main event loop
    try self.eventLoop();
}

/// Internal use only
/// Needs to be public for websocket.zig
///
/// handles the raw events and creates an `Event` struct to add to the Event stack
pub fn handle(self: *Client, msg: ws.Message) !void {
    if (msg.type == .close) {
        if (msg.data.len < 2) return error.NoCloseCode;
        const code: u16 = std.mem.readInt(u16, msg.data[0..2], .big);

        try self._events.append(.{ .close = .{
            .code = @enumFromInt(code),
            .reconnect = (code <= 4009 and code != 4004),
            .reason = msg.data[2..],
        } });
        return;
    }
    if (msg.type != .text) return error.UnexpectedPayload;

    const allocator = self._arena.allocator();
    const g_event = json.parseFromSliceLeaky(
        dys.discord.gateway.GatewayEvent,
        allocator,
        msg.data,
        .{},
    ) catch |err| {
        dys.log.err("error handling event: {}", .{err});
        return err;
    };

    dys.log.debug(
        "received event: {s}",
        .{@tagName(g_event.d)},
    );
    self._seq = g_event.s;

    try self._events.append(g_event.d);
}

/// Internal use only
/// Needs to be public for websocket.zig
///
/// Triggers when the client receives a close event
pub fn close(self: *Client) void {
    self._sent_close = true;
}

/// Handle an event from the event stack
/// When processing a ReceiveEvent, the function checks whether the client has a callback for that
/// event, and calls it if it exists. When processing a SendEvent, the function calls the correlated
/// send function
fn processEvent(self: *Client, event: dys.discord.gateway.events.Event) !void {
    switch (event) {
        .close => |e| {
            if (!self._sent_close) return self.sendClose(e) else return error.Closed;
        },
        .heartbeat => {
            try self.sendHeartbeat();
        },
        .heartbeat_ack => {
            self._awaiting_ack = false;
        },
        .hello => |e| {
            self._heartbeat_interval = e.heartbeat_interval;
            try self.sendIdentify();
        },
        .ready => |e| {
            if (self.callbacks.on_ready) |on_ready| {
                on_ready(self, e) catch |err| {
                    dys.log.err("on_ready callback failed with error: {}", .{err});
                };
            }
        },
        .message_create => |e| {
            if (self.callbacks.on_message_create) |on_message_create| {
                on_message_create(self, e) catch |err| {
                    dys.log.err("on_message_create callback failed with error: {}", .{err});
                };
            }
        },
        .unknown => |e| {
            if (self.callbacks.on_unknown) |on_unknown| {
                on_unknown(self, e) catch |err| {
                    dys.log.err("on_unknown callback failed with error: {}", .{err});
                };
            }
        },

        else => {},
    }
}

/// main event loop, when this returns the gateway has been closed
fn eventLoop(self: *Client) !void {
    // start listening for events in a new thread, so the main thread can process them
    const thread = try self._wsclient.?.readLoopInNewThread(self);
    thread.detach();

    // The number of heartbeats we have sent
    var beats: usize = 0;
    // When the next heartbeat must be sent by, as a timestamp relative to `discord_epoch`
    var deadline: ?i64 = null;

    // if we have sent a close event, either initiating a close or responding to a close event
    // sent by discord, we want to stop the main loop and exit
    while (!self._sent_close) {
        // go through each event and process them
        while (self._events.popOrNull()) |event| {
            self.processEvent(event) catch |err| {
                // if we encounter an error while processing events we send discord a close event
                // so we can safely exit
                dys.log.err("closing because of error: {}", .{err});
                if (!self._sent_close) try self.sendClose(.{
                    .code = .protocol_error,
                    .reconnect = false,
                    .reason = @errorName(err),
                });
                return err;
            };
            // if, after processing all the events, we did not recieve an expected heartbeat ack,
            // we should assume the gateway should be closed as Discord has become unresponsive
            if (self._awaiting_ack) {
                dys.log.err("did not receive heartbeat_ack", .{});
                try self.sendClose(.{
                    .code = .protocol_error,
                    .reconnect = false,
                    .reason = "Missed heartbeat_ack",
                });
            }
        }

        // If we have started the heartbeat cycle, we must continue sending heartbeats at a set
        // interval, until we send a close event
        if (self._heartbeat_interval) |interval| {
            if (deadline) |d| {
                if (d <= std.time.milliTimestamp()) {
                    beats += 1;
                    try self.sendHeartbeat();
                    deadline = std.time.milliTimestamp() + interval;
                }
            } else {
                deadline = std.time.milliTimestamp() + interval;
            }
        }
    }
}

/// Send a close event, triggering a the gateway to close
fn sendClose(self: *Client, event: dys.discord.gateway.events.Close) !void {
    dys.log.warn("gateway closed: {s}", .{event.reason});
    self._sent_close = true;
    const code_int: u16 = if (@intFromEnum(event.code) <= std.math.maxInt(u16))
        @intCast(@intFromEnum(event.code))
    else
        1002;
    var code_bytes: [2]u8 = std.mem.toBytes(code_int);
    try self._wsclient.?.writeFrame(.close, &code_bytes);

    // we want to reconnect if the close event told us to
    if (event.reconnect) {
        //TODO: reconnect
    }
}

/// send a GatewayEvent through the websocket client
inline fn send(self: *Client, event: dys.discord.gateway.GatewayEvent) !void {
    std.debug.assert(self._wsclient != null);

    var buf = Buffer(4096){};
    try json.stringify(event, .{ .emit_null_optional_fields = false }, buf.writer());
    try self._wsclient.?.writeText(buf.buf[0..buf.pos]);
}

/// Send a heartbeat to discord, and tell the client we are now expecting an acknowledgement
fn sendHeartbeat(self: *Client) !void {
    const event = dys.discord.gateway.GatewayEvent{
        .op = @intFromEnum(dys.discord.gateway.GatewayEvent.Opcode.heartbeat),
        .d = .{ .heartbeat = self._seq },
    };
    try self.send(event);
    self._awaiting_ack = true;
}

/// Identify our client with Discord
fn sendIdentify(self: *Client) !void {
    const id = dys.discord.gateway.events.Identify{
        .token = self._token,
        .properties = .{
            .os = &std.posix.uname().sysname,
        },
        .intents = @bitCast(self.intents),
    };

    const event = dys.discord.gateway.GatewayEvent{
        .op = @intFromEnum(dys.discord.gateway.GatewayEvent.Opcode.identify),
        .d = .{ .identify = id },
    };
    try self.send(event);
}

// REST methods

/// Sends a GET request to Discord's REST API
/// T is the type for the response we expect to receive
pub inline fn get(self: *Client, comptime T: type, endpoint: []const u8) !T {
    const allocator = self._arena.allocator();

    // add the api endpoint to the base url
    const url: []u8 = try allocator.alloc(u8, base.len + endpoint.len);
    defer allocator.free(url);
    @memcpy(url[0..base.len], base);
    @memcpy(url[base.len..], endpoint);

    // an array that holds the response and can be dynamically expanded
    // to fit the entire response
    var response = std.ArrayList(u8).init(allocator);
    defer response.deinit();

    // send the request
    const result = try self._httpclient.fetch(.{
        .location = .{ .url = url },
        .headers = self._headers,
        .response_storage = .{ .dynamic = &response },
    });
    // assume something has gone wrong if the status is not ok or there is no response
    if (result.status != .ok or response.items.len == 0) {
        return error.UnableToReachEndpoint;
    }

    // parse the response into the provide type, we can use the leaky variant because we have an
    // arena allocator
    return try json.parseFromSliceLeaky(
        T,
        allocator,
        response.items,
        .{ .allocate = .alloc_always, .ignore_unknown_fields = true },
    );
}

/// Sends a POST request to Discord's REST API
/// `T` is the type of the response, `data` is the data to POST
pub inline fn post(self: *Client, comptime T: type, endpoint: []const u8, data: anytype) !T {
    const allocator = self._arena.allocator();

    // add the api endpoint to the base url
    const url: []u8 = try allocator.alloc(u8, base.len + endpoint.len);
    defer allocator.free(url);
    @memcpy(url[0..base.len], base);
    @memcpy(url[base.len..], endpoint);

    const value = try json.stringifyAlloc(allocator, data, .{ .emit_null_optional_fields = false });

    var header_buffer: [4096]u8 = .{0} ** 4096;
    var req = try self._httpclient.open(
        .POST,
        try std.Uri.parse(url),
        .{
            .server_header_buffer = &header_buffer,
            .redirect_behavior = .unhandled,
            .headers = self._headers,
        },
    );
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = value.len };
    try req.send();

    try req.writeAll(value);

    try req.finish();
    try req.wait();

    if (req.response.status != .ok) return error.BadResponse;

    var reader = json.Reader(4096, @TypeOf(req.reader())).init(allocator, req.reader());
    defer reader.deinit();

    return json.parseFromTokenSourceLeaky(T, allocator, &reader, .{ .ignore_unknown_fields = true });
}

fn getGateway(self: *Client) !dys.discord.gateway.Gateway {
    return self.get(dys.discord.gateway.Gateway, "/gateway/bot");
}

pub fn getCurrentUser(self: *Client) !dys.discord.user.User {
    return try self.get(dys.discord.user.User, "/users/@me");
}

pub fn getUser(self: *Client, id: dys.discord.Snowflake) !dys.discord.user.User {
    const endpoint = try std.fmt.allocPrint(self._arena.allocator(), "/users/{d}", .{id.toId()});
    return self.get(dys.discord.user.User, endpoint);
}

pub fn getChannel(self: *Client, id: dys.discord.Snowflake) !dys.discord.channel.Channel {
    const endpoint = try std.fmt.allocPrint(self._arena.allocator(), "/channels/{d}", .{id.toId()});

    return self.get(dys.discord.channel.Channel, endpoint);
}

pub fn listGuildEmoji(self: *Client, id: dys.discord.Snowflake) ![]dys.discord.emoji.Emoji {
    const endpoint = try std.fmt.allocPrint(self._arena.allocator(), "/guilds/{d}/emojis", .{id.toId()});
    return self.get([]dys.discord.emoji.Emoji, endpoint);
}

pub fn createMessage(
    self: *Client,
    channel_id: dys.discord.Snowflake,
    msg: dys.discord.channel.CreateMessage,
) !dys.discord.channel.Message {
    const endpoint = try std.fmt.allocPrint(
        self._arena.allocator(),
        "/channels/{d}/messages",
        .{channel_id.toId()},
    );

    return self.post(dys.discord.channel.Message, endpoint, msg);
}
