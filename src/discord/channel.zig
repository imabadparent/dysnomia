const dys = @import("../dysnomia.zig");
const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;

// This file is for types listed in [Channel](https://discord.com/developers/docs/resources/channel)
// Also contains types from [Message](https://discord.com/com/developers/docs/resources/message) as
// they require a channel to be sent

/// [Message](https://discord.com/developers/docs/resources/message#message-object)
pub const Message = @import("message/Message.zig");

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
