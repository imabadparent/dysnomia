const std = @import("std");
const json = std.json;
const types = @import("types.zig");

const Activity = types.Activity;

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
};

/// this event is sent by the bot
/// different to PresenceUpdateEvent, which is sent by discord
pub const UpdatePresenceEvent = struct {
    since: ?i64 = null,
    activies: []Activity = .{},
    status: enum {
        online,
        dnd,
        idle,
        invisible,
        offline,
    },
    afk: bool,
};
