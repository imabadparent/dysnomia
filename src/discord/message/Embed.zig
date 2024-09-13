const dys = @import("../../dysnomia.zig");
const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;

const Embed = @This();

pub const Type = enum {
    rich,
    image,
    video,
    gifv,
    article,
    link,
    poll_result,

    /// Interface function for `std.json`
    pub fn jsonParse(
        alloc: Allocator,
        source: anytype,
        options: json.ParseOptions,
    ) json.ParseError(@TypeOf(source.*))!Type {
        const value = try json.innerParse(json.Value, alloc, source, options);
        return jsonParseFromValue(alloc, value, options);
    }

    /// Interface function for `std.json`
    pub fn jsonParseFromValue(
        _: Allocator,
        source: json.Value,
        _: json.ParseOptions,
    ) !Type {
        return switch (source) {
            .string => |str| blk: {
                const value = std.meta.stringToEnum(Type, str);
                if (value) |v| {
                    break :blk v;
                } else {
                    break :blk error.UnexpectedToken;
                }
            },
            else => error.UnexpectedToken,
        };
    }

    /// Interface function for `std.json`
    pub fn jsonStringify(self: Type, writer: anytype) !void {
        writer.print("\"{s}\"", .{@tagName(self)});
    }
};

pub const Footer = struct {
    text: []const u8,
    icon_url: ?[]const u8 = null,
    proxy_icon_url: ?[]const u8 = null,
};

pub const Image = struct {
    url: []const u8,
    proxy_url: ?[]const u8 = null,
    height: ?u64 = null,
    width: ?u64 = null,
};

pub const Thumbnail = struct {
    url: []const u8,
    proxy_url: ?[]const u8 = null,
    height: ?u64 = null,
    width: ?u64 = null,
};

pub const Video = struct {
    url: []const u8,
    proxy_url: ?[]const u8 = null,
    height: ?u64 = null,
    width: ?u64 = null,
};

pub const Provider = struct {
    name: ?[]const u8 = null,
    url: ?[]const u8 = null,
};

pub const Author = struct {
    name: []const u8,
    url: ?[]const u8 = null,
    icon_url: ?[]const u8 = null,
    proxy_icon_url: ?[]const u8 = null,
};

pub const Field = struct {
    name: []const u8,
    value: []const u8,
    @"inline": ?bool = null,
};

title: ?[]const u8 = null,
type: ?Type = null,
description: ?[]const u8 = null,
url: ?[]const u8 = null,
timestamp: ?dys.discord.Timestamp = null,
color: ?dys.discord.Color = null,
footer: ?Footer = null,
image: ?Image = null,
thumbnail: ?Thumbnail = null,
video: ?Video = null,
provider: ?Provider = null,
author: ?Author = null,
fields: ?[]Field = null,
