const std = @import("std");
const json = std.json;
const types = @import("types.zig");

const Activity = types.Activity;

pub const Event = union(enum) {
    unknown,
    // recieve events
    heartbeat_ack,
    close: CloseEvent,
    hello: HelloEvent,

    // send events
    heartbeat: ?i64,
    identify: IdentifyEvent,
    update_presence: UpdatePresenceEvent,

    // receive events
    ready: ReadyEvent,

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

pub const CloseEvent = struct {
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

pub const HelloEvent = struct {
    heartbeat_interval: i64,
};

pub const IdentifyEvent = struct {
    token: []const u8,
    properties: struct {
        os: []const u8,
        browser: []const u8 = "dysnomia",
        device: []const u8 = "dysnomia",
    },
    compress: ?bool = false,
    large_threshold: ?i64 = 50,
    shard: ?[2]i64 = null,
    presence: ?UpdatePresenceEvent = null,
    intents: i64 = 0,
};

/// this event is sent by the bot
/// different to PresenceUpdateEvent, which is sent by discord
pub const UpdatePresenceEvent = struct {
    since: ?i64 = null,
    activies: []Activity = &.{},
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

pub const ReadyEvent = struct {
    v: i64,
    guilds: []types.UnavailableGuild,
    session_id: []const u8,
    resume_gateway_url: []const u8,
    shard: [2]i64 = .{ 0, 0 },
    application: types.PartialApplication,
};
