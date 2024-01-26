const std = @import("std");
const json = std.json;
pub usingnamespace @import("event_types.zig");

const types = @This();

pub const Gateway = struct {
    url: []const u8,
    shards: u32,
    session_start_limit: struct {
        total: u32,
        remaining: u32,
        reset_after: u32,
        max_concurrency: u32,
    },
};

pub const GatewayEvent = struct {
    pub const Opcode = enum(i64) {
        dispatch = 0,
        heartbeat = 1,
        identify = 2,
        presence_update = 3,
        voice_state_update = 4,
        @"resume" = 6,
        reconnect = 7,
        request_guild_members = 8,
        invalid_session = 9,
        hello = 10,
        heartbeak_ack = 11,
    };
    op: i64,
    d: json.Value,
    s: ?i64 = null,
    t: ?[]const u8 = null,
};

pub const Activity = struct {
    const Type = enum(i64) {
        game = 0,
        streaming = 1,
        listening = 2,
        watching = 3,
        custom = 4,
        competing = 5,
    };
    name: []const u8,
    type: i64,
    url: ?[]const u8 = null,
    created_at: i64 = std.time.milliTimestamp(),
    timestamps: ?struct {
        start: ?i64 = null,
        end: ?i64 = null,
    } = null,
};
