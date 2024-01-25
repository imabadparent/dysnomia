const std = @import("std");

pub fn add(x: i32, y: i32) i32 {
    return x + y;
}

test "add" {
    std.testing.expect(add(2 + 2) == 4);
}
