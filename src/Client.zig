const std = @import("std");
const ws = @import("websocket");
const types = @import("types.zig");
const zigcord = @import("zigcord.zig");
const http = std.http;
const json = std.json;

const Client = @This();

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
    on_hello: Callback(HelloEvent) = hello,
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

/// Contains context information
/// fields:
///     callbacks: a set of functions to be used as callbacks for gateway events
///     intents: a bitfield of gateway intents to be used by the bot
pub const Context = struct {
    callbacks: VTable = .{},
};

const base = "https://discord.com/api/v10/";

token: []const u8,
intents: types.Intents = .{},

_arena: std.heap.ArenaAllocator,
_buf: Buffer(4096) = .{},
_vtable: VTable,
_wsclient: ?ws.Client = null,
_seq: ?i64 = null,

/// Create the bot, run the `connect()` method to start
/// Caller should call `deinit()` when done
pub fn init(allocator: std.mem.Allocator, config: Config, ctx: Context) !Client {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const tok = if (config.bot orelse true)
        try std.fmt.allocPrint(arena.allocator(), "Bot {s}", .{config.token})
    else
        try std.fmt.allocPrint(arena.allocator(), "Bearer {s}", .{config.token});

    return Client{
        .token = tok,
        ._arena = arena,
        ._vtable = ctx.callbacks,
    };
}

pub fn deinit(self: *Client) void {
    self._arena.deinit();
}

fn getGateway(self: *Client) !Gateway {
    const endpoint = base ++ "/gateway/bot";
    const allocator = self._arena.allocator();
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    var headers = http.Headers.init(allocator);
    defer headers.deinit();
    try headers.append("Authorization", self.token);

    var result = try client.fetch(allocator, .{
        .location = .{ .url = endpoint },
        .headers = headers,
    });
    defer result.deinit();
    if (result.status != .ok or result.body == null) {
        return error.UnableToReachGateway;
    }

    return try json.parseFromSliceLeaky(
        Gateway,
        allocator,
        result.body.?,
        .{ .allocate = .alloc_always },
    );
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

    try self._wsclient.?.readLoop(self);
}

/// Internal use only
/// Needs to be public for websocket.zig to use it
pub fn handle(self: *Client, msg: ws.Message) !void {
    if (msg.type == .close) {
        try self.handleClose(msg);
    }
    if (msg.type != .text) return;

    const allocator = self._arena.allocator();
    const g_event = try json.parseFromSliceLeaky(GatewayEvent, allocator, msg.data, .{});
    std.log.info(
        "event received: {}\n",
        .{@as(types.GatewayEvent.Opcode, @enumFromInt(g_event.op))},
    );

    self._seq = g_event.s;
    try switch (g_event.d) {
        .hello => |event| self._vtable.on_hello(self, event),
        else => {},
    };
}

pub fn close(_: *Client) void {}

pub fn handleClose(self: *Client, msg: ws.Message) !void {
    //const code: u16 = @as(u16, msg.data[1]) + (@as(u16, msg.data[0]) << 8);
    const code = std.mem.readInt(u16, msg.data[0..2], .big);
    std.debug.print("closed: {d}: {s}\n", .{ code, msg.data[2..] });

    self.close();
}

inline fn send(self: *Client, event: GatewayEvent) !void {
    self._buf.pos = 0;
    try json.stringify(event, .{ .emit_null_optional_fields = false }, self._buf.writer());
    std.debug.print("buf -> {s}\n", .{self._buf.buf});
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

fn hello(self: *Client, event: HelloEvent) !void {
    _ = event;
    try self.sendIdentify();
    //std.time.sleep(10 * std.time.ns_per_s);
}
