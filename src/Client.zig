const std = @import("std");
const ws = @import("websocket");
const dys = @import("dysnomia.zig");
const http = std.http;
const json = std.json;

const Client = @This();

const EventList = std.ArrayList(dys.events.Event);

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

const base = "https://discord.com/api/v10";

/// Gateway intents, tells discord what events we want to listen to
intents: dys.Intents = .{},
callbacks: struct {
    /// Called when the client recieves the `Ready` event
    on_ready: ?Callback(dys.events.Ready) = null,
    on_message_create: ?Callback(dys.events.MessageCreate) = null,
    on_unknown: ?Callback(json.Value) = null,
} = .{},

_arena: std.heap.ArenaAllocator,
_token: []const u8,
_httpclient: std.http.Client,
_headers: std.http.Headers,
_wsclient: ?ws.Client = null,
_sent_close: bool = false,

/// stack of websocket events
_events: EventList,
_heartbeat_interval: ?i64 = null,
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

    var headers = http.Headers.init(arena.allocator());
    try headers.append("Authorization", tok);
    try headers.append("User-Agent", "DiscordBot (https://github.com/imabadparent/dysnomia, 0.1.0)");

    return Client{
        .callbacks = .{},
        ._arena = arena,
        ._token = tok,
        ._httpclient = http.Client{ .allocator = allocator },
        ._headers = headers,
        ._events = EventList.init(allocator),
    };
}

pub fn deinit(self: *Client) void {
    self._httpclient.deinit();
    self._events.deinit();
    self._arena.deinit();
}

/// Connect to discord gateway and start listening for events
pub fn connect(self: *Client) !void {
    if (self._wsclient) |_| return;
    const gateway = try self.getGateway();
    if (gateway.session_start_limit.remaining <= 0) return error.NoSessionsLeft;
    const allocator = self._arena.allocator();

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

    const options = "/?v=10&encoding=json";
    const headers = try std.fmt.allocPrint(allocator, "host: {s}\r\n", .{host});
    try self._wsclient.?.handshake(options, .{ .headers = headers });

    try self.eventLoop();
}

/// Internal use only
/// Needs to be public for websocket.zig
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
        dys.GatewayEvent,
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
pub fn close(self: *Client) void {
    self._sent_close = true;
}

fn processEvent(self: *Client, event: dys.events.Event) !void {
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
    const thread = try self._wsclient.?.readLoopInNewThread(self);
    thread.detach();

    var beats: usize = 0;
    var deadline: ?i64 = null;

    while (!self._sent_close) {
        while (self._events.popOrNull()) |event| {
            self.processEvent(event) catch |err| {
                dys.log.err("closing because of error: {}", .{err});
                if (!self._sent_close) try self.sendClose(.{
                    .code = .protocol_error,
                    .reconnect = false,
                    .reason = @errorName(err),
                });
                return err;
            };
            if (self._awaiting_ack) {
                dys.log.err("did not receive heartbeat_ack", .{});
                try self.sendClose(.{
                    .code = .protocol_error,
                    .reconnect = false,
                    .reason = "Missed heartbeat_ack",
                });
            }
        }

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

fn sendClose(self: *Client, event: dys.events.Close) !void {
    dys.log.warn("gateway closed: {s}", .{event.reason});
    self._sent_close = true;
    const code_int: u16 = if (@intFromEnum(event.code) <= std.math.maxInt(u16))
        @intCast(@intFromEnum(event.code))
    else
        1002;
    var code_bytes: [2]u8 = std.mem.toBytes(code_int);
    try self._wsclient.?.writeFrame(.close, &code_bytes);

    if (event.reconnect) {
        //TODO: reconnect
    }
}

inline fn send(self: *Client, event: dys.GatewayEvent) !void {
    std.debug.assert(self._wsclient != null);

    var buf = Buffer(4096){};
    try json.stringify(event, .{ .emit_null_optional_fields = false }, buf.writer());
    try self._wsclient.?.writeText(buf.buf[0..buf.pos]);
}

fn sendHeartbeat(self: *Client) !void {
    const event = dys.GatewayEvent{
        .op = @intFromEnum(dys.GatewayEvent.Opcode.heartbeat),
        .d = .{ .heartbeat = self._seq },
    };
    try self.send(event);
    self._awaiting_ack = true;
}

fn sendIdentify(self: *Client) !void {
    const id = dys.events.Identify{
        .token = self._token,
        .properties = .{
            .os = &std.os.uname().sysname,
        },
        .intents = @bitCast(self.intents),
    };

    const event = dys.GatewayEvent{
        .op = @intFromEnum(dys.GatewayEvent.Opcode.identify),
        .d = .{ .identify = id },
    };
    try self.send(event);
}

// REST methods
pub inline fn get(self: *Client, comptime T: type, endpoint: []const u8) !T {
    const allocator = self._arena.allocator();

    const url: []u8 = try allocator.alloc(u8, base.len + endpoint.len);
    defer allocator.free(url);
    @memcpy(url[0..base.len], base);
    @memcpy(url[base.len..], endpoint);

    var result = try self._httpclient.fetch(allocator, .{
        .location = .{ .url = url },
        .headers = self._headers,
    });
    defer result.deinit();
    if (result.status != .ok or result.body == null) {
        return error.UnableToReachEndpoint;
    }

    return try json.parseFromSliceLeaky(
        T,
        allocator,
        result.body.?,
        .{ .allocate = .alloc_always, .ignore_unknown_fields = true },
    );
}

pub inline fn post(self: *Client, comptime T: type, endpoint: []const u8, data: anytype) !T {
    const allocator = self._arena.allocator();

    const url: []u8 = try allocator.alloc(u8, base.len + endpoint.len);
    defer allocator.free(url);
    @memcpy(url[0..base.len], base);
    @memcpy(url[base.len..], endpoint);

    const value = try json.stringifyAlloc(allocator, data, .{ .emit_null_optional_fields = false });

    var headers = try self._headers.clone(allocator);
    defer headers.deinit();
    try headers.append("Content-Type", "application/json");

    var req = try self._httpclient.open(.POST, try std.Uri.parse(url), headers, .{ .handle_redirects = false });
    defer req.deinit();
    req.transfer_encoding = .{ .content_length = value.len };
    try req.send(.{});

    try req.writeAll(value);

    try req.finish();
    try req.wait();

    if (req.response.status != .ok) return error.BadResponse;

    var reader = json.Reader(4096, @TypeOf(req.reader())).init(allocator, req.reader());
    defer reader.deinit();

    return json.parseFromTokenSourceLeaky(T, allocator, &reader, .{ .ignore_unknown_fields = true });
    //return json.parseFromSliceLeaky(T, allocator, result.body.?, .{ .ignore_unknown_fields = true });
}

fn getGateway(self: *Client) !dys.Gateway {
    return self.get(dys.Gateway, "/gateway/bot");
}

pub fn getCurrentUser(self: *Client) !dys.User {
    return try self.get(dys.User, "/users/@me");
}

pub fn getUser(self: *Client, id: dys.Snowflake) !dys.User {
    const endpoint = try std.fmt.allocPrint(self._arena.allocator(), "/users/{d}", .{id.toId()});

    return self.get(dys.User, endpoint);
}

pub fn getChannel(self: *Client, id: dys.Snowflake) !dys.Channel {
    const endpoint = try std.fmt.allocPrint(self._arena.allocator(), "/channels/{d}", .{id.toId()});

    return self.get(dys.Channel, endpoint);
}

pub fn listGuildEmoji(self: *Client, id: dys.Snowflake) ![]dys.Emoji {
    const endpoint = try std.fmt.allocPrint(self._arena.allocator(), "/guilds/{d}/emojis", .{id.toId()});
    return self.get([]dys.Emoji, endpoint);
}

pub fn createMessage(
    self: *Client,
    channel_id: dys.Snowflake,
    msg: dys.CreateMessage,
) !dys.Message {
    const endpoint = try std.fmt.allocPrint(
        self._arena.allocator(),
        "/channels/{d}/messages",
        .{channel_id.toId()},
    );

    return self.post(dys.Message, endpoint, msg);
}
