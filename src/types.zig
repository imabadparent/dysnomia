const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;

pub const channel = @import("discord/channel.zig");
pub const emoji = @import("discord/emoji.zig");
pub const guild = @import("discord/guild.zig");
pub const user = @import("discord/user.zig");
pub const gateway = @import("discord/gateway.zig");

// the rest of this file is for unsorted types, they might be moved in the future

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

    /// Creates a snowflake from a string, where each character is a digit in the snowflake
    pub fn fromString(string: []const u8) !Snowflake {
        const id = try std.fmt.parseInt(u64, string, 10);
        return fromId(id);
    }
    /// Creates a Snowflake struct from the numerical representation
    pub inline fn fromId(id: u64) Snowflake {
        return @bitCast(id);
    }
    /// returns the numerical representation of a Snowflake struct
    pub inline fn toId(self: Snowflake) u64 {
        return @bitCast(self);
    }

    /// Interface function required for `std.json`
    pub fn jsonParse(
        alloc: Allocator,
        source: anytype,
        options: json.ParseOptions,
    ) json.ParseError(@TypeOf(source.*))!Snowflake {
        const id = try json.innerParse(u64, alloc, source, options);
        return fromId(id);
    }

    /// Interface function required for `std.json`
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

    /// Interface function required for `std.json`
    pub fn jsonStringify(self: Snowflake, writer: anytype) !void {
        try writer.print("\"{d}\"", .{self.toId()});
    }
};

/// A convience struct for operating on Discord's timestamp strings (Note that these are different
/// from the timestamps contained in Snowflakes)
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

pub const PartialApplication = struct {
    id: Snowflake,
    flags: i64 = 0,
};

/// Discord Type
/// [Activity](https://discord.com/developers/docs/topics/gateway-events#activity-object)
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
