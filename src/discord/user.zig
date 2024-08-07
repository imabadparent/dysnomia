const dys = @import("../dysnomia.zig");

// This file contains types listed in [User](https://discord.com/developers/docs/resources/user)

/// [User](https://discord.com/developers/docs/resources/user#user-object)
pub const User = struct {
    id: dys.Snowflake,
    username: []const u8,
    discriminator: []const u8,
    global_name: ?[]const u8,
    avatar: ?[]const u8,
    bot: bool = false,
    system: bool = false,
    mfa_enabled: bool = false,
    banner: ?[]const u8 = null,
    accent_color: ?u64 = null,
    locale: []const u8 = "",
    verified: bool = false,
    email: ?[]const u8 = null,
    flags: u64 = 0, // TODO: Create enum for UserFlags
    premium_type: u64 = 0, // TODO: Create enum for PremiumType
    public_flags: u64 = 0, // TODO: Create enum for UserFlags
    avatar_decorations: ?[]const u8 = null,
    //// Only a valid value in mentions from messages received from the gateway
    member: ?dys.GuildMember = null,
};
