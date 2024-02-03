const std = @import("std");
const json = std.json;
const types = @import("types.zig");

const Allocator = std.mem.Allocator;

pub const Event = union(enum) {
    unknown,
    // recieve events
    heartbeat_ack,
    close: Close,
    hello: Hello,

    // send events
    heartbeat: ?i64,
    identify: Identify,
    update_presence: UpdatePresence,

    // receive events
    ready: Ready,

    message_create: MessageCreate,

    pub fn jsonStringify(self: Event, writer: anytype) !void {
        switch (self) {
            .hello => |event| try writer.write(event),
            .heartbeat => |event| try writer.write(event),
            .identify => |event| try writer.write(event),
            .update_presence => |event| try writer.write(event),

            .ready => |event| try writer.write(event),

            else => try writer.write("null"),
        }
    }
};

pub const Close = struct {
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

// Send Events

pub const Hello = struct {
    heartbeat_interval: i64,
};

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

/// this event is sent by the bot
/// different to PresenceUpdateEvent, which is sent by discord
pub const UpdatePresence = struct {
    since: ?i64 = null,
    activies: []types.Activity = &.{},
    status: enum {
        online,
        dnd,
        idle,
        invisible,
        offline,
    },
    afk: bool,
};

// Receive Events

pub const Ready = struct {
    v: i64,
    user: types.User,
    guilds: []types.UnavailableGuild,
    session_id: []const u8,
    resume_gateway_url: []const u8,
    shard: [2]i64 = .{ 0, 0 },
    application: types.PartialApplication,
};

pub const MessageCreate = struct {
    message: types.Message,

    pub fn jsonParse(
        alloc: Allocator,
        source: anytype,
        options: json.ParseOptions,
    ) json.ParseError(@TypeOf(source.*))!MessageCreate {
        const message = try json.innerParse(types.Message, alloc, source, options);
        return .{ .message = message };
    }

    pub fn jsonParseFromValue(
        alloc: Allocator,
        source: json.Value,
        options: json.ParseOptions,
    ) !MessageCreate {
        const message = try json.innerParseFromValue(
            types.Message,
            alloc,
            source,
            options,
        );
        return .{ .message = message };
    }

    pub fn jsonStringify(self: MessageCreate, writer: anytype) !void {
        try json.stringify(self.message, .{}, writer);
    }
};
