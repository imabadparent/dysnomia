const std = @import("std");
const json = std.json;
const rest = @import("rest_types.zig");
pub usingnamespace rest;
pub const events = @import("event_types.zig");

const Allocator = std.mem.Allocator;

const discord_epoch = 1_420_070_400_000;

pub const Snowflake = packed struct(u64) {
    /// milliseconds since or `discord_epoch`
    timestamp: u42,
    worker_id: u5,
    process_id: u5,
    /// incremented for every id generated on a process
    increment: u12,

    pub fn fromString(string: []const u8) !Snowflake {
        const id = try std.fmt.parseInt(u64, string, 10);
        return fromId(id);
    }
    pub inline fn fromId(id: u64) Snowflake {
        return @bitCast(id);
    }

    pub fn toId(self: Snowflake) u64 {
        return @bitCast(self);
    }

    pub fn jsonParse(
        alloc: Allocator,
        source: anytype,
        options: json.ParseOptions,
    ) json.ParseError(@TypeOf(source.*))!Snowflake {
        const id = try json.innerParse(u64, alloc, source, options);
        return fromId(id);
    }

    pub fn jsonParseFromValue(
        _: Allocator,
        source: json.Value,
        _: json.ParseOptions,
    ) !Snowflake {
        return switch (source) {
            .integer => fromId(@intCast(source.integer)),
            .string, .number_string => fromId(try std.fmt.parseInt(u64, source.string, 10)),
            else => error.UnexpectedToken,
        };
    }

    pub fn jsonStringify(self: Snowflake, writer: anytype) !void {
        try writer.print("\"{d}\"", .{self.toId()});
    }
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
        if (data == .null and op != .heartbeak_ack) return error.UnexpectedToken;

        result.d = switch (op) {
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
                            events.ReadyEvent,
                            alloc,
                            data,
                            .{ .ignore_unknown_fields = true },
                        );
                        break :blk events.Event{ .ready = value };
                    },
                    else => break :blk .unknown,
                }
            },
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
