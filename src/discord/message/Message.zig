const dys = @import("../../dysnomia.zig");
const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;

const Message = @This();
const Channel = dys.discord.channel.Channel;

pub const Nonce = union(enum) {
    int: i64,
    string: []const u8,

    /// Interface function for `std.json`
    pub fn jsonParse(
        alloc: Allocator,
        source: anytype,
        options: json.ParseOptions,
    ) json.ParseError(@TypeOf(source.*))!Nonce {
        const value = try json.innerParse(json.Value, alloc, source, options);
        return jsonParseFromValue(alloc, value, options);
    }

    /// Interface function for `std.json`
    pub fn jsonParseFromValue(
        _: Allocator,
        source: json.Value,
        _: json.ParseOptions,
    ) !Nonce {
        return switch (source) {
            .integer => |n| .{ .int = n },
            .string, .number_string => |str| .{ .string = str },
            else => error.UnexpectedToken,
        };
    }

    /// Interface function for `std.json`
    pub fn jsonStringify(self: Nonce, writer: anytype) !void {
        return switch (self) {
            .int => writer.print("{d}", .{self.int}),
            .string => writer.print("\"{s}\"", .{self.string}),
        };
    }
};

pub const Flags = packed struct(u64) {
    crossposted: bool = false,
    is_crosspost: bool = false,
    suppress_embeds: bool = false,
    source_message_deleted: bool = false,
    urgent: bool = false,
    has_thread: bool = false,
    ephemeral: bool = false,
    loading: bool = false,
    failed_to_mention_some_roles_in_thread: bool = false,
    _padding: u3 = 0,
    suppress_notifications: bool = false,
    is_voice_message: bool = false,

    _padding2: u50 = 0,

    /// Interface function for `std.json`
    pub fn jsonParse(
        alloc: Allocator,
        source: anytype,
        options: json.ParseOptions,
    ) json.ParseError(@TypeOf(source.*))!Flags {
        const id = try json.innerParse(u64, alloc, source, options);
        return @bitCast(id);
    }

    /// Interface function for `std.json`
    pub fn jsonParseFromValue(
        _: Allocator,
        source: json.Value,
        _: json.ParseOptions,
    ) !Flags {
        return switch (source) {
            .integer => @bitCast(source.integer),
            .string, .number_string => @bitCast(try std.fmt.parseInt(u64, source.string, 10)),
            else => error.UnexpectedToken,
        };
    }

    /// Interface function for `std.json`
    pub fn jsonStringify(self: Flags, writer: anytype) !void {
        try writer.print("\"{d}\"", .{@as(u64, @bitCast(self))});
    }
};

pub const ChannelMention = struct {
    id: dys.discord.Snowflake,
    guild_id: dys.discord.Snowflake,
    type: Channel.Type,
    name: []const u8,
};

pub const Attachment = struct {
    pub const Flags = packed struct(u64) {
        _padding: u2 = 0,
        is_remix: bool = false,
        _padding2: u61 = 0,

        pub fn jsonParse(
            alloc: Allocator,
            source: anytype,
            options: json.ParseOptions,
        ) json.ParseError(@TypeOf(source.*))!@This() {
            const id = try json.innerParse(u64, alloc, source, options);
            return @bitCast(id);
        }

        /// Interface function for `std.json`
        pub fn jsonParseFromValue(
            _: Allocator,
            source: json.Value,
            _: json.ParseOptions,
        ) !@This() {
            return switch (source) {
                .integer => @bitCast(source.integer),
                else => error.UnexpectedToken,
            };
        }

        /// Interface function for `std.json`
        pub fn jsonStringify(self: @This(), writer: anytype) !void {
            try writer.print("\"{d}\"", .{@as(u64, @bitCast(self))});
        }
    };

    id: dys.discord.Snowflake,
    filename: []const u8,
    title: ?[]const u8 = null,
    description: ?[]const u8 = null,
    content_type: ?[]const u8 = null,
    size: i64,
    url: []const u8,
    proxy_url: []const u8,
    height: ?i64 = null,
    width: ?i64 = null,
    ephemeral: ?bool = null,
    duration_secs: ?f64 = null,
    waveform: ?[]const u8 = null,
    flags: ?@This().Flags = null,
};

pub const Embed = @import("Embed.zig");

pub const Type = enum(u64) {
    default = 0,
    recipient_add = 1,
    recipient_remove = 2,
    call = 3,
    channel_name_change = 4,
    channel_icon_change = 5,
    channel_pinned_message = 6,
    user_join = 7,
    guild_boost = 8,
    guild_boost_tier_1 = 9,
    guild_boost_tier_2 = 10,
    guild_boost_tier_3 = 11,
    channel_follow_add = 12,
    guild_discovery_disqualified = 14,
    guild_discovery_requalified = 15,
    guild_discovery_grace_period_initial_warning = 16,
    guild_discovery_grace_period_final_warning = 17,
    thread_created = 18,
    reply = 19,
    chat_input_command = 20,
    thread_starter_message = 21,
    guild_invite_reminder = 22,
    context_menu_command = 23,
    auto_moderation_action = 24,
    role_subscription_purchase = 25,
    interaction_premium_upsell = 26,
    stage_start = 27,
    stage_end = 28,
    stage_speaker = 29,
    stage_topic = 31,
    guild_application_premium_subscription = 32,
    guild_incident_alert_mode_enabled = 36,
    guild_incident_alert_mode_disabled = 37,
    guild_incident_report_raid = 38,
    guild_incident_report_false_alarm = 39,
    purchase_notification = 44,
    poll_result = 46,
    _,

    /// Whether this message type can be deleted
    pub inline fn deletable(self: @This()) bool {
        return switch (self) {
            .recipient_add,
            .recipient_remove,
            .call,
            .channel_name_change,
            .channel_icon_change,
            .thread_starter_message,
            => false,
            _ => true,
        };
    }

    /// Interface function for `std.json`
    pub fn jsonStringify(self: @This(), writer: anytype) !void {
        return writer.print("{d}", .{@intFromEnum(self)});
    }
};

id: dys.discord.Snowflake,
channel_id: dys.discord.Snowflake,
author: dys.discord.user.User,
content: []const u8,
timestamp: dys.discord.Timestamp,
edited_timestamp: ?dys.discord.Timestamp,
tts: bool,
mention_everyone: bool,
mentions: []dys.discord.user.User,
mention_roles: []dys.discord.Snowflake,
mention_channels: ?[]ChannelMention = null,
attachments: []Attachment,
embeds: []Embed,
reactions: ?json.Value = null, // TODO: type should be `[]Reaction`
nonce: ?Nonce = null,
pinned: bool,
webhook_id: ?dys.discord.Snowflake = null,
type: Type,
activity: ?json.Value = null, // TODO: type should be MessageActivity
application: ?json.Value = null, // TODO: Figure what "partial application" means
application_id: ?dys.discord.Snowflake = null,
message_reference: ?json.Value = null, // TODO: type should be `MessageReference`
flags: ?Flags = null,
referenced_message: ?*Message = null,
interaction: ?json.Value = null, // TODO: type should be `MessageInteraction`
thread: ?json.Value = null, //TODO: type should be `Channel`
components: ?json.Value = null, // TODO: type should be `[]MessageComponent`
sticker_items: ?json.Value = null, // TODO: type should be `[]MessageStickerItem`
stickers: ?json.Value = null, // TODO: type should be `[]Sticker`
position: ?u64 = null,
role_subscription_data: ?json.Value = null, // TODO: type should be `RoleSubscriptionData`
resolved: ?json.Value = null, // TODO: type should be `Resolved`
poll: ?json.Value = null, // TODO: type should be `Poll`
call: ?json.Value = null, // TODO: type should be `MessageCall`

/// Only present in messages recieved from the gateway
guild_id: ?dys.discord.Snowflake = null,
//// Only present in messages recieved from the gateway
member: ?dys.discord.guild.GuildMember = null,
