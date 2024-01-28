const std = @import("std");
const json = std.json;
pub const events = @import("event_types.zig");

const Allocator = std.mem.Allocator;

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
    d: events.Event,
    s: ?i64 = null,
    t: ?[]const u8 = null,

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
        if (data == .null and op != .heartbeak_ack) return error.UnexpectedToken;

        result.d = switch (op) {
            .hello => blk: {
                const value = try json.innerParseFromValue(
                    events.HelloEvent,
                    alloc,
                    data,
                    .{ .ignore_unknown_fields = true },
                );
                break :blk .{ .hello = value };
            },
            .identify => blk: {
                const value = try json.innerParseFromValue(
                    events.IdentifyEvent,
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
    created_at: i64,
    timestamps: ?struct {
        start: ?i64 = null,
        end: ?i64 = null,
    } = null,
    state: ?[]const u8 = null,

    pub fn init(name: []const u8, @"type": Type) Activity {
        return Activity{
            .name = name,
            .type = @intFromEnum(@"type"),
            .created_at = std.time.milliTimestamp(),
        };
    }
};

pub const Intents = packed struct(i64) {
    guilds: bool = false,
    /// priveledged
    guild_members: bool = false,
    guild_moderation: bool = false,
    guild_emojis_and_stickers: bool = false,
    guild_integrations: bool = false,
    guild_webhooks: bool = false,
    guild_invites: bool = false,
    /// priveledged
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
    auto_moderation_configuration: bool = false,
    auto_moderation_execution: bool = false,

    _padding: u46 = 0,
};
