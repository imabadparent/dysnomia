const dys = @import("../dysnomia.zig");
const json = @import("std").json;

// This file is for types listed [here](https://discord.com/developers/docs/resources/channel)

/// [Discord channel](https://discord.com/developers/docs/resources/channel#channel-object)
pub const Channel = struct {
    id: dys.Snowflake,
    type: u64, // TODO: make this a packed struct
    guild_id: ?dys.Snowflake = null,
    position: ?u64 = null,
    permission_overwrites: ?json.Value = null, // TODO: type should be `[]Overwrite`
    name: ?[]const u8 = null,
    topic: ?[]const u8 = null,
    nsfw: ?bool = null,
    last_message_id: ?dys.Snowflake = null,
    bitrate: ?u64 = null,
    user_limit: ?u64 = null,
    rate_limit_per_user: ?u64 = null,
    recipients: ?[]dys.User = null,
    icon: ?[]const u8 = null,
    owner_id: ?dys.Snowflake = null,
    application_id: ?dys.Snowflake = null,
    managed: ?bool = null,
    parent_id: ?dys.Snowflake = null,
    last_pin_timestamp: ?dys.Timestamp = null,
    rtc_region: ?[]const u8 = null,
    video_quality_mode: ?u64 = null, // TODO: make this an enum
    message_count: ?u64 = null,
    member_count: ?u64 = null,
    thread_metadata: ?json.Value = null, // TODO: type should be `ThreadMetadata`
    member: ?json.Value = null, // TODO: type should be `ThreadMember`
    default_auto_archive_duration: ?u64 = null,
    permissions: ?[]const u8 = null,
    flags: ?u64 = null, // TODO: make this a packed struct
    total_message_sent: ?u64 = null,
    available_tags: ?json.Value = null, // TODO: type should be `[]Tag`
    applied_tags: ?dys.Snowflake = null,
    default_reaction_emoji: ?json.Value = null, // TODO: type should be `DefaultReaction`
    default_thread_rate_limit_per_user: ?u64 = null,
    default_sort_order: ?u64 = null, // TODO: make this an enum
    default_forum_layout: ?u64 = null, // TODO: make this an enum
};

/// [Discord message](https://discord.com/developers/docs/resources/channel#message-object)
pub const Message = struct {
    id: dys.Snowflake,
    channel_id: dys.Snowflake,
    author: dys.User,
    content: []const u8,
    timestamp: dys.Timestamp,
    edited_timestamp: ?dys.Timestamp,
    tts: bool,
    mention_everyone: bool,
    mentions: []dys.User,
    mention_roles: []dys.Snowflake,
    mention_channels: ?json.Value = null, // TODO: type should be `[]ChannelMention`
    attachments: json.Value, // TODO: type should be `[]Attachment`
    embeds: json.Value, // TODO: type should be `[]Embed`
    reactions: ?json.Value = null, // TODO: type should be `[]Reaction`
    nonce: ?json.Value = null, // TODO: type should be `Nonce`
    pinned: bool,
    webhook_id: ?dys.Snowflake = null,
    type: u64, // TODO: create enum for `MessageType`
    activity: ?json.Value = null, // TODO: type should be MessageActivity
    application: ?json.Value = null, // TODO: Figure what "partial application" means
    application_id: ?dys.Snowflake = null,
    message_reference: ?json.Value = null, // TODO: type should be `MessageReference`
    flags: ?u64 = null, // TODO: create packed struct for `MessageFlags`
    referenced_message: ?*Message = null,
    interaction: ?json.Value = null, // TODO: type should be `MessageInteraction`
    thread: ?json.Value = null, //TODO: type should be `Channel`
    components: ?json.Value = null, // TODO: type should be `[]MessageComponent`
    sticker_items: ?json.Value = null, // TODO: type should be `[]MessageStickerItem`
    stickers: ?json.Value = null, // TODO: type should be `[]Sticker`
    position: ?u64 = null,
    role_subscription_data: ?json.Value = null, // TODO: type should be `RoleSubscriptionData`
    resolved: ?json.Value = null, // TODO: type should be `Resolved`

    /// Only present in messages recieved from the gateway
    guild_id: ?dys.Snowflake = null,
    //// Only present in messages recieved from the gateway
    member: ?dys.GuildMember = null,
};
