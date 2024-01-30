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

pub const User = struct {
    id: i64,
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
};

pub const UnavailableGuild = struct {
    id: types.Snowflake,
    unvailable: bool = true,
};

pub const PartialApplication = struct {
    id: types.Snowflake,
    flags: i64 = 0,
};
