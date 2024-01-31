const std = @import("std");
const ws = @import("websocket");
const types = @import("types.zig");
const zigcord = @import("zigcord.zig");
const http = std.http;
const json = std.json;

const Client = @This();

const EventList = std.ArrayList(types.events.Event);

const Gateway = types.Gateway;
const GatewayEvent = types.GatewayEvent;
const HelloEvent = types.events.HelloEvent;
const IdentifyEvent = types.events.IdentifyEvent;

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
/// Contains the callbacks for gateway events
const VTable = struct {
    on_hello: ?Callback(HelloEvent) = null,
};

/// Config for the bot, usually parsed from json
/// fields:
///     bot: (optional) whether to connect as a bot (default) or a normal user. Note: connecting as
///     a normal user outside of the official discord app is against ToS. Use at your own risk
///     token: the token to use to connect to discord
pub const Config = struct {
    bot: ?bool = true,
    token: []const u8,
};

const base = "https://discord.com/api/v10/";

token: []const u8,
intents: types.Intents = .{},
callbacks: VTable,

_arena: std.heap.ArenaAllocator,
_httpclient: std.http.Client,
_headers: std.http.Headers,
_wsclient: ?ws.Client = null,
_sent_close: bool = false,
_buf: Buffer(4096) = .{},

/// stack of websocket events
_events: EventList,
_heartbeat_interval: ?i64 = null,
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

    var headers = http.Headers.init(allocator);
    try headers.append("Authorization", tok);

    return Client{
        .token = tok,
        .callbacks = .{},
        ._arena = arena,
        ._httpclient = http.Client{ .allocator = allocator },
        ._headers = headers,
        ._events = EventList.init(allocator),
    };
}

pub fn deinit(self: *Client) void {
    self._httpclient.deinit();
    self._headers.deinit();
    self._events.deinit();
    self._arena.deinit();
}

/// Connect to discord websocket and start listening for events
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
/// Needs to be public for websocket.zig to use it
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
    const g_event = json.parseFromSliceLeaky(GatewayEvent, allocator, msg.data, .{}) catch |err| {
        std.log.err("error: {}", .{err});
        return err;
    };

    std.log.info(
        "received event: {s}",
        .{@tagName(@as(types.GatewayEvent.Opcode, @enumFromInt(g_event.op)))},
    );
    self._seq = g_event.s;

    try self._events.append(g_event.d);
}

/// Needs to be here for websocket.zig
pub fn close(self: *Client) void {
    self._sent_close = true;
}

fn processEvent(self: *Client, event: types.events.Event) !void {
    switch (event) {
        .close => |e| {
            if (!self._sent_close) return self.sendClose(e) else return error.Closed;
        },

        .hello => |e| {
            self._heartbeat_interval = try self.hello(e);
            if (self.callbacks.on_hello) |onHello| {
                try onHello(self, e);
            }
        },

        else => {},
    }
}

/// main event loop, when this returns the program should exit
fn eventLoop(self: *Client) !void {
    const thread = try self._wsclient.?.readLoopInNewThread(self);
    thread.detach();

    var beats: usize = 0;
    var deadline: ?i64 = null;

    while (!self._sent_close) {
        while (self._events.popOrNull()) |event| {
            self.processEvent(event) catch |err| {
                std.log.err("closing because of error: {any}\n", .{err});
                if (!self._sent_close) try self.sendClose(.{
                    .code = .protocol_error,
                    .reconnect = false,
                    .reason = @errorName(err),
                });
                return err;
            };
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

fn sendClose(self: *Client, event: types.events.CloseEvent) !void {
    std.log.warn("gateway closed: {s}", .{event.reason});
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

inline fn send(self: *Client, event: GatewayEvent) !void {
    std.debug.assert(self._wsclient != null);

    self._buf.pos = 0;
    try json.stringify(event, .{ .emit_null_optional_fields = false }, self._buf.writer());
    try self._wsclient.?.writeText(self._buf.buf[0..self._buf.pos]);
}

fn sendHeartbeat(self: *Client) !void {
    const event = GatewayEvent{
        .op = @intFromEnum(GatewayEvent.Opcode.heartbeat),
        .d = .{ .heartbeat = self._seq },
    };
    try self.send(event);
}

fn sendIdentify(self: *Client) !void {
    const id = IdentifyEvent{
        .token = self.token,
        .properties = .{
            .os = &std.os.uname().sysname,
        },
        .intents = @bitCast(self.intents),
    };

    const event = GatewayEvent{
        .op = @intFromEnum(GatewayEvent.Opcode.identify),
        .d = .{ .identify = id },
    };
    try self.send(event);
}

fn hello(self: *Client, event: HelloEvent) !i64 {
    try self.sendIdentify();
    return event.heartbeat_interval;
}

// REST methods
inline fn get(self: *Client, comptime T: type, endpoint: []const u8) !T {
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

fn getGateway(self: *Client) !Gateway {
    return self.get(types.Gateway, "/gateway/bot");
}

pub fn getCurrentUser(self: *Client) !types.User {
    return try self.get(types.User, "/users/@me");
}

pub fn getUser(self: *Client, id: u64) !types.User {
    const endpoint = try std.fmt.allocPrint(self._arena.allocator(), "/users/{d}", .{id.toId()});

    return try self.get(types.User, endpoint);
}
