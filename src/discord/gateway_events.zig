const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;

const dys = @import("../dysnomia.zig");

// This file is for types listed in [Gateway Events](https://discord.com/developers/docs/topics/gateway-events)

/// A tagged union for processing and identifying events. This is not technically a Discord type,
/// but it does corespond with the `d` field of Discord's gateway event payload
pub const Event = union(enum) {
    unknown: json.Value,

    heartbeat_ack,
    close: Close,

    // recieve events
    hello: Hello,
    ready: Ready,
    message_create: MessageCreate,

    // send events
    heartbeat: ?i64,
    identify: Identify,
    update_presence: UpdatePresence,

    // Interface function for `std.json`
    pub fn jsonStringify(self: Event, writer: anytype) !void {
        switch (self) {
            // receive events
            .ready => |event| try writer.write(event),
            .hello => |event| try writer.write(event),

            // send events
            .heartbeat => |event| try writer.write(event),
            .identify => |event| try writer.write(event),
            .update_presence => |event| try writer.write(event),

            else => try writer.write("null"),
        }
    }
};

/// This is a special event that closes the connection; It can be sent and received by both ends of
/// the Websocket, and should be echoed back back the receiving end
pub const Close = struct {
    /// The close code, usually gives a reason for why the connection is closing
    const Code = enum(i64) {
        // rfc standard defined
        normal = 1000,
        leaving = 1001,
        protocol_error = 1002,
        bad_data = 1003,
        reserved = 1004,
        no_code = 1005,
        abnormal_close = 1006,
        corrupt_data = 1007,
        policy_violation = 1008,
        message_too_big = 1009,
        missing_extensions = 1010,
        unfullfilled_request = 1011,
        tls_error = 1015,

        // discord specific
        unknown_error = 4000,
        unknown_opcode = 4001,
        decode_error = 4002,
        not_auth = 4003,
        auth_failed = 4004,
        already_auth = 4005,
        invalid_seq = 4007,
        rate_limit = 4008,
        time_out = 4009,
        invalid_shard = 4010,
        sharding_required = 4011,
        invalid_api_ver = 4012,
        invalid_intents = 4013,
        disallowed_intents = 4014,

        _,
    };
    code: Code,
    reconnect: bool,
    reason: []const u8,
};

// Send Events (Events sent by the bot to discord)

/// [Identify](https://discord.com/developers/docs/topics/gateway-events#identify)
pub const Identify = struct {
    token: []const u8,
    properties: struct {
        os: []const u8,
        browser: []const u8 = "dysnomia",
        device: []const u8 = "dysnomia",
    },
    compress: ?bool = false,
    large_threshold: ?i64 = 50,
    shard: ?[2]i64 = null,
    presence: ?UpdatePresence = null,
    intents: i64 = 0,
};

/// (Not to be confused with: PresenceUpdateEvent, which is sent by discord)
/// [Update Presence](https://discord.com/developers/docs/topics/gateway-events#update-presence)
pub const UpdatePresence = struct {
    since: ?i64 = null,
    activies: []dys.discord.Activity = &.{},
    status: enum {
        online,
        dnd,
        idle,
        invisible,
        offline,
    },
    afk: bool,
};

// Receive Events (Events the bot receives from discord)

/// [Hello](https://discord.com/developers/docs/topics/gateway-events#hello)
pub const Hello = struct {
    heartbeat_interval: i64,
};

/// [Ready](https://discord.com/developers/docs/topics/gateway-events#ready)
pub const Ready = struct {
    v: i64,
    user: dys.discord.user.User,
    guilds: []dys.discord.guild.UnavailableGuild,
    session_id: []const u8,
    resume_gateway_url: []const u8,
    shard: [2]i64 = .{ 0, 0 },
    application: dys.discord.PartialApplication,
};

/// Used when a gateway event is a container for a REST type
/// ie: ChannelCreate or MessageCreate
fn Container(comptime T: type) type {
    return struct {
        const Self = @This();
        payload: T,

        pub fn jsonParse(
            alloc: Allocator,
            source: anytype,
            options: json.ParseOptions,
        ) json.ParseError(@TypeOf(source.*))!Self {
            const payload = try json.innerParse(T, alloc, source, options);
            return .{ .payload = payload };
        }

        pub fn jsonParseFromValue(
            alloc: Allocator,
            source: json.Value,
            options: json.ParseOptions,
        ) !Self {
            const payload = try json.innerParseFromValue(
                T,
                alloc,
                source,
                options,
            );
            return .{ .payload = payload };
        }

        pub fn jsonStringify(self: Self, writer: anytype) !void {
            try json.stringify(self.payload, .{}, writer);
        }
    };
}

pub const ChannelCreate = Container(dys.discord.channel.Channel);
pub const MessageCreate = Container(dys.discord.channel.Message);
