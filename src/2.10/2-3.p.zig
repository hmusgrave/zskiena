const std = @import("std");

fn isqrt(n: u32) u32 {
    var x = n;
    var y = (x + 1) >> 1;
    while (y < x) {
        x = y;
        y = (x + (n / x)) >> 1;
    }
    return x;
}

pub fn light_more_light(n: u32) bool {
    const s = isqrt(n);
    return s * s == n;
}

test {
    try std.testing.expectEqual(false, light_more_light(3));
    try std.testing.expectEqual(true, light_more_light(6241));
    try std.testing.expectEqual(false, light_more_light(8191));
}
