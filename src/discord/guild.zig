const dys = @import("../dysnomia.zig");

// This file contains types listed in [Guild](https://discord.com/developers/docs/resources/guild)

/// [Guild Member](https://discord.com/developers/docs/resources/guild)
pub const GuildMember = struct {
    user: ?*dys.User = null,
    nick: ?[]const u8 = "",
    avatar: ?[]const u8 = "",
    roles: []dys.Snowflake,
    joined_at: dys.Timestamp,
    premium_since: ?dys.Timestamp = null,
    deaf: bool,
    mute: bool,
    flags: u64, // TODO: make this a packed struct
    pending: bool = false,
    permissions: []const u8 = "",
    communication_disabled_until: ?dys.Timestamp = null,
};

/// [Unavailable Guild](https://discord.com/developers/docs/resources/guild)
pub const UnavailableGuild = struct {
    id: dys.Snowflake,
    unvailable: bool = true,
};
