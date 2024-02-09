const std = @import("std");
const json = std.json;
pub const events = @import("event_types.zig");

pub usingnamespace @import("discord/channel.zig");
pub usingnamespace @import("discord/emoji.zig");
pub usingnamespace @import("discord/guild.zig");
pub usingnamespace @import("discord/user.zig");

const Allocator = std.mem.Allocator;

/// The first second of 2015, which discord uses for timestamps
pub const discord_epoch = 1_420_070_400_000;

/// Discord uses these for identification. The packed struct represents what each
/// part of a `u64` represents, for our convenience. When sent to or received from
/// discord, a snowflake is represented as a `u64`.
pub const Snowflake = packed struct(u64) {
    /// milliseconds since 2015 or `discord_epoch`
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

    pub inline fn toId(self: Snowflake) u64 {
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

pub const Timestamp = struct {
    year: u32,
    month: u8,
    day: u8,

    hour: u8,
    minute: u8,
    second: u8,
    microsecond: u32,

    pub fn fromString(str: []const u8) !Timestamp {
        const t_sep = std.mem.indexOfScalar(u8, str, 'T') orelse return error.BadFormat;
        const s_sep = std.mem.indexOfScalar(u8, str, '.') orelse return error.BadFormat;
        const tz_sep = std.mem.indexOfScalar(u8, str, '+') orelse return error.BadFormat;

        var date_it = std.mem.splitScalar(u8, str[0..t_sep], '-');
        const year_str = date_it.next() orelse return error.BadFormat;
        const month_str = date_it.next() orelse return error.BadFormat;
        const day_str = date_it.next() orelse return error.BadFormat;

        var time_it = std.mem.splitScalar(u8, str[t_sep + 1 .. s_sep], ':');
        const hour_str = time_it.next() orelse return error.BadFormat;
        const minute_str = time_it.next() orelse return error.BadFormat;
        const second_str = time_it.next() orelse return error.BadFormat;
        const micro_str = str[s_sep + 1 .. tz_sep];

        return Timestamp{
            .year = try std.fmt.parseInt(u32, year_str, 10),
            .month = try std.fmt.parseInt(u8, month_str, 10),
            .day = try std.fmt.parseInt(u8, day_str, 10),
            .hour = try std.fmt.parseInt(u8, hour_str, 10),
            .minute = try std.fmt.parseInt(u8, minute_str, 10),
            .second = try std.fmt.parseInt(u8, second_str, 10),
            .microsecond = try std.fmt.parseInt(u32, micro_str, 10) * 10,
        };
    }

    pub fn toString(self: Timestamp) ![]const u8 {
        var buf: [32]u8 = .{0} ** 32;
        return try std.fmt.bufPrint(
            &buf,
            "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.{d:0>6}+00:00",
            .{
                self.year,
                self.month,
                self.day,
                self.hour,
                self.minute,
                self.second,
                self.microsecond / 10,
            },
        );
    }

    pub fn jsonParse(
        alloc: Allocator,
        source: anytype,
        options: json.ParseOptions,
    ) json.ParseError(@TypeOf(source.*))!Timestamp {
        const str = try json.innerParse([]const u8, alloc, source, options);
        return fromString(str) catch error.UnexpectedToken;
    }

    pub fn jsonParseFromValue(
        _: Allocator,
        source: json.Value,
        _: json.ParseOptions,
    ) !Timestamp {
        return switch (source) {
            .string => |str| fromString(str) catch error.UnexpectedToken,
            else => error.UnexpectedToken,
        };
    }

    pub fn jsonStringify(self: Timestamp, writer: anytype) !void {
        try writer.print("\"{s}\"", .{self.toString() catch ""});
    }
};

test "Timestamp.fromString" {
    const timestamp = try Timestamp.fromString("2021-08-23T04:20:01.100000+00:00");
    try std.testing.expect(timestamp.year == 2021);
    try std.testing.expect(timestamp.month == 8);
    try std.testing.expect(timestamp.day == 23);
    try std.testing.expect(timestamp.hour == 4);
    try std.testing.expect(timestamp.minute == 20);
    try std.testing.expect(timestamp.second == 1);
    try std.testing.expect(timestamp.microsecond == 1000000);
}

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

pub const PartialApplication = struct {
    id: Snowflake,
    flags: i64 = 0,
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
