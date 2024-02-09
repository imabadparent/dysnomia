const dys = @import("../dysnomia.zig");

pub const Emoji = struct {
    /// emoji id
    id: ?dys.Snowflake,
    /// emoji name (can be null only in reaction emoji objects)
    name: ?[]const u8,
    /// roles allowed to use this emoji
    roles: ?[]dys.Snowflake = null,
    /// user taht created this emoji
    user: ?dys.User = null,
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
