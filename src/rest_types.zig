const std = @import("std");
const json = std.json;

const types = @import("types.zig");

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

/// [Discord message](https://discord.com/developers/docs/resources/channel#message-object)
pub const Message = struct {
    id: types.Snowflake,
    channel_id: types.Snowflake,
    author: User,
    content: []const u8,
    timestamp: types.Timestamp,
    edited_timestamp: ?types.Timestamp,
    tts: bool,
    mention_everyone: bool,
    mentions: []User,
    mention_roles: []types.Snowflake,
    // TODO: mention_channels: []ChannelMention,
    // TODO: attachments: []attachments,
    // TODO: embeds: []Embed,
    // TODO: reactions: []Reaction,
    // TODO: nonce: Nonce,
    pinned: bool,
    webhook_id: ?types.Snowflake = null,
    type: u64, // NOTE: Change to enum?

    // FIX: finish the rest of this struct

    /// Only present in messages recieved from the gateway
    guild_id: ?types.Snowflake = null,
    //// Only present in messages recieved from the gateway
    member: ?types.GuildMember = null,
};

pub const User = struct {
    id: types.Snowflake,
    username: []const u8,
    discriminator: []const u8,
    global_name: ?[]const u8,
    avatar: ?[]const u8,
    bot: bool = false,
    system: bool = false,
    mfa_enabled: bool = false,
    banner: ?[]const u8 = null,
    accent_color: ?i64 = null,
    locale: []const u8 = "",
    verified: bool = false,
    email: ?[]const u8 = null,
    flags: i64 = 0,
    premium_type: i64 = 0,
    public_flags: i64 = 0,
    avatar_decorations: ?[]const u8 = null,
    //// Only a valid value in mentions from messages received from the gateway
    member: ?GuildMember = null,
};

pub const GuildMember = struct {
    user: ?*User = null,
    nick: ?[]const u8 = "",
    avatar: ?[]const u8 = "",
    roles: []types.Snowflake,
    joined_at: types.Timestamp,
    premium_since: ?types.Timestamp = null,
    deaf: bool,
    mute: bool,
    flags: u64, // TODO: make this a packed struct
    pending: bool = false,
    permissions: []const u8 = "",
    communication_disabled_until: ?types.Timestamp = null,
};

pub const UnavailableGuild = struct {
    id: types.Snowflake,
    unvailable: bool = true,
};

pub const PartialApplication = struct {
    id: types.Snowflake,
    flags: i64 = 0,
};
