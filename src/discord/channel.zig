const dys = @import("../dysnomia.zig");
const json = @import("std").json;

// This file is for types listed [here](https://discord.com/developers/docs/resources/channel)

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
    type: u64, // NOTE: create enum for `MessageType`

    // FIX: finish the rest of this struct

    /// Only present in messages recieved from the gateway
    guild_id: ?dys.Snowflake = null,
    //// Only present in messages recieved from the gateway
    member: ?dys.GuildMember = null,
};
