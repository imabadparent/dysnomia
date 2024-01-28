const std = @import("std");
const json = std.json;
const types = @import("types.zig");

const Activity = types.Activity;

pub const Event = union(enum) {
    unknown,
    heartbeat_ack,
    hello: HelloEvent,
    heartbeat: ?i64,
    identify: IdentifyEvent,
    update_presence: UpdatePresenceEvent,

    pub fn jsonStringify(self: *const Event, writer: anytype) !void {
        switch (self.*) {
            .hello => |event| try writer.write(event),
            .heartbeat => |event| try writer.write(event),
            .identify => |event| try writer.write(event),
            .update_presence => |event| try writer.write(event),
            .unknown, .heartbeat_ack => try writer.write("null"),
        }
    }
};

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
