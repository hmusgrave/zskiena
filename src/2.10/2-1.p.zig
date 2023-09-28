const std = @import("std");

pub fn carry_count(_x: u32, _y: u32) u8 {
    var x = @max(_x, _y);
    var y = @min(_x, _y);

    var carry: u8 = 0;
    var count: u8 = 0;

    while (x > 0) {
        const xd: u8 = @intCast(x % 10);
        x /= 10;

        const yd: u8 = @intCast(y % 10);
        y /= 10;

        var tmp = xd + yd + carry;
        carry = tmp / 10;
        count += @intFromBool(tmp >= 10);
    }

    return count;
}

test {
    try std.testing.expectEqual(@as(u8, 0), carry_count(123, 456));
    try std.testing.expectEqual(@as(u8, 3), carry_count(555, 555));
    try std.testing.expectEqual(@as(u8, 1), carry_count(123, 594));
}
