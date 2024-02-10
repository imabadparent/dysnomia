const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;

const dys = @import("../dysnomia.zig");

pub const events = @import("gateway_events.zig");

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

/// Events received from the gateway will always follow this format, with `d`
/// being the payload which is parsed into an `Event` union with the active
/// field coresponding to the event type
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
        heartbeat_ack = 11,
    };
    op: i64,
    d: events.Event,
    s: ?i64 = null,
    t: ?[]u8 = null,

    pub fn jsonParse(
        alloc: Allocator,
        source: anytype,
        options: json.ParseOptions,
    ) json.ParseError(@TypeOf(source.*))!GatewayEvent {
        var result: GatewayEvent = undefined;
        result.s = null;
        result.t = null;

        const info = @typeInfo(GatewayEvent).Struct;

        const first: json.Token = try source.nextAlloc(alloc, .alloc_always);
        if (first != .object_begin) return error.UnexpectedToken;

        var data: json.Value = .null;
        while (true) {
            const token: json.Token = try source.nextAlloc(alloc, .alloc_always);
            const key: []const u8 = switch (token) {
                .object_end => break,
                .string, .allocated_string => |str| str,

                else => return error.UnexpectedToken,
            };

            if (!std.mem.eql(u8, key, "d")) {
                inline for (info.fields) |field| {
                    if (std.mem.eql(u8, key, field.name)) {
                        @field(result, field.name) = try json.innerParse(field.type, alloc, source, options);
                        break;
                    }
                } else {
                    return error.UnknownField;
                }
            } else {
                // `key` is "id"
                // since we dont know if we have the op code yet,
                // we cant parse the data into the correct struct
                // so we save the value to be parsed after everything else
                data = try json.innerParse(json.Value, alloc, source, options);
            }
        }
        const op: Opcode = @enumFromInt(result.op);
        if (data == .null and op != .heartbeat_ack) return error.UnexpectedToken;

        result.d = switch (op) {
            // this is what most events are
            .dispatch => blk: {
                if (result.t == null) return error.MissingField;
                var event_str = result.t.?;
                for (event_str, 0..) |c, i| {
                    if (c == '_') continue;
                    if (c >= 'A' and c <= 'Z') event_str[i] += 'a' - 'A';
                }

                const tag_type = @typeInfo(events.Event).Union.tag_type.?;
                const event = std.meta.stringToEnum(tag_type, event_str);
                if (event == null) break :blk .unknown;
                switch (event.?) {
                    .ready => {
                        const value = try json.innerParseFromValue(
                            events.Ready,
                            alloc,
                            data,
                            .{ .ignore_unknown_fields = true },
                        );
                        break :blk events.Event{ .ready = value };
                    },
                    .message_create => {
                        const value = try json.innerParseFromValue(
                            events.MessageCreate,
                            alloc,
                            data,
                            .{ .ignore_unknown_fields = true },
                        );
                        break :blk events.Event{ .message_create = value };
                    },
                    else => break :blk .unknown,
                }
            },
            .heartbeat_ack => .heartbeat_ack,
            .hello => blk: {
                const value = try json.innerParseFromValue(
                    events.Hello,
                    alloc,
                    data,
                    .{ .ignore_unknown_fields = true },
                );
                break :blk .{ .hello = value };
            },
            .identify => blk: {
                const value = try json.innerParseFromValue(
                    events.Identify,
                    alloc,
                    data,
                    .{ .ignore_unknown_fields = true },
                );
                break :blk .{ .identify = value };
            },
            else => .unknown,
        };

        return result;
    }
};

/// Gateway intents, send to discord as a bitfield
pub const Intents = packed struct(u64) {
    guilds: bool = false,
    /// priveledged
    guild_members: bool = false,
    guild_moderation: bool = false,
    guild_emojis_and_stickers: bool = false,
    guild_integrations: bool = false,
    guild_webhooks: bool = false,
    guild_invites: bool = false,
    /// priveledged
    guild_voice_states: bool = false,
    guild_presences: bool = false,
    guild_messages: bool = false,
    guild_message_reactions: bool = false,
    guild_message_typing: bool = false,
    direct_messages: bool = false,
    direct_message_reactions: bool = false,
    direct_message_typing: bool = false,
    /// priveledged
    message_content: bool = false,
    guild_scheduled_events: bool = false,
    /// discord skips a few bits here, so we do too
    _padding1: u3 = 0,
    auto_moderation_configuration: bool = false,
    auto_moderation_execution: bool = false,

    _padding2: u42 = 0,
};
