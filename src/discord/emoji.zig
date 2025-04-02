const dys = @import("../dysnomia.zig");

// This file contains types listed in [Emoji](https://discord.com/developers/docs/resources/emoji)

/// [Emoji](https://discord.com/developers/docs/resources/emoji#emoji-object-emoji-structure)
pub const Emoji = struct {
    /// emoji id
    id: ?dys.discord.Snowflake,
    /// emoji name (can be null only in reaction emoji objects)
    name: ?[]const u8,
    /// roles allowed to use this emoji
    roles: ?[]dys.discord.Snowflake = null,
    /// user that created this emoji
    user: ?dys.discord.user.User = null,
    /// whether this emoji must be wrapped in colons
    require_colons: bool = true,
    /// whether this emoji is managed
    managed: bool = false,
    /// whether this emoji is animated
    animated: bool = false,
    /// whether this emoji can be used
    /// may be false due to loss of server boosts
    available: bool = true,
};
