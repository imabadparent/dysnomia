const dys = @import("../dysnomia.zig");
const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;

// This file is for types listed in [Channel](https://discord.com/developers/docs/resources/channel)
// Also contains types from [Message](https://discord.com/com/developers/docs/resources/message) as
// they require a channel to be sent

/// [Channel](https://discord.com/developers/docs/resources/channel#channel-object)
pub const Channel = struct {
    pub const Type = enum(u64) {
        guild_text = 0,
        dm = 1,
        guild_voice = 2,
        group_dm = 3,
        guild_category = 4,
        guild_announcement = 5,
        announcement_thread = 10,
        public_thread = 11,
        private_thread = 12,
        guild_stage_voice = 13,
        guild_directory = 14,
        guild_forum = 15,
        guild_media = 16,
        _,

        pub fn jsonStringify(self: @This(), writer: anytype) !void {
            writer.write(@intFromEnum(self));
        }
    };
    pub const VideoQualityMode = enum(u64) {
        auto = 1,
        full = 2,
        pub fn jsonStringify(self: @This(), writer: anytype) !void {
            writer.write(@intFromEnum(self));
        }
    };
    pub const Flags = packed struct(u64) {
        pinned: bool,
        _padding0: u2,
        require_tag: bool,
        _padding1: u10,
        hide_media_download_options: bool,
        _padding2: u49,
    };

    id: dys.discord.Snowflake,
    type: Type,
    guild_id: ?dys.discord.Snowflake = null,
    position: ?u64 = null,
    permission_overwrites: ?json.Value = null, // TODO: type should be `[]Overwrite`
    name: ?[]const u8 = null,
    topic: ?[]const u8 = null,
    nsfw: ?bool = null,
    last_message_id: ?dys.discord.Snowflake = null,
    bitrate: ?u64 = null,
    user_limit: ?u64 = null,
    rate_limit_per_user: ?u64 = null,
    recipients: ?[]dys.discord.user.User = null,
    icon: ?[]const u8 = null,
    owner_id: ?dys.discord.Snowflake = null,
    application_id: ?dys.discord.Snowflake = null,
    managed: ?bool = null,
    parent_id: ?dys.discord.Snowflake = null,
    last_pin_timestamp: ?dys.discord.Timestamp = null,
    rtc_region: ?[]const u8 = null,
    video_quality_mode: ?VideoQualityMode = null,
    message_count: ?u64 = null,
    member_count: ?u64 = null,
    thread_metadata: ?json.Value = null, // TODO: type should be `ThreadMetadata`
    member: ?json.Value = null, // TODO: type should be `ThreadMember`
    default_auto_archive_duration: ?u64 = null,
    permissions: ?[]const u8 = null,
    flags: ?u64 = null, // TODO: make this a packed struct
    total_message_sent: ?u64 = null,
    available_tags: ?json.Value = null, // TODO: type should be `[]Tag`
    applied_tags: ?dys.discord.Snowflake = null,
    default_reaction_emoji: ?json.Value = null, // TODO: type should be `DefaultReaction`
    default_thread_rate_limit_per_user: ?u64 = null,
    default_sort_order: ?u64 = null, // TODO: make this an enum
    default_forum_layout: ?u64 = null, // TODO: make this an enum
};

/// [Message](https://discord.com/developers/docs/resources/message#message-object)
pub const Message = struct {
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
    mention_channels: ?json.Value = null, // TODO: type should be `[]ChannelMention`
    attachments: json.Value, // TODO: type should be `[]Attachment`
    embeds: json.Value, // TODO: type should be `[]Embed`
    reactions: ?json.Value = null, // TODO: type should be `[]Reaction`
    nonce: ?Nonce = null,
    pinned: bool,
    webhook_id: ?dys.discord.Snowflake = null,
    type: u64, // TODO: create enum for `MessageType`
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
};

// Create types

/// [Create Message](https://discord.com/developers/docs/resources/message#create-message)
/// At least one of `content`, `embeds`, `sticker_ids`, `components`, or `files`
/// must not be null
pub const CreateMessage = struct {
    content: ?[]const u8 = null,
    nonce: ?Message.Nonce = null,
    tts: ?bool = null,
    embeds: ?json.Value = null, // TODO: type should be `[]Embed`
    allowed_mentions: ?json.Value = null, // TODO: type should be `AllowedMention`
    message_reference: ?json.Value = null, // TODO: type should be `MessageReference`
    components: ?json.Value = null, // TODO: type should be `[]MessageComponent`
    sticker_ids: ?dys.discord.Snowflake = null,
    attachments: ?json.Value = null, // TODO: type should be []Attachment
    flags: ?Message.Flags = null,

    /// List of paths to files to add to the message
    /// Internal use only, to add a file, use `CreateMessage.addFile()`
    _files: ?[][]const u8 = null,
};
