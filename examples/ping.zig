const std = @import("std");
const zigcord = @import("zigcord");

pub fn main() !void {
    std.debug.print("2 + 2 = {d}\n", .{zigcord.add(2, 2)});
}
