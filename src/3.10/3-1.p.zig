const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn jolly(allocator: Allocator, comptime T: type, seq: []T) !bool {
    if (seq.len < 1)
        return error.OutOfSpec;
    if (seq.len == 1)
        return true;

    var unique = try std.DynamicBitSet.initEmpty(allocator, seq.len - 1);
    defer unique.deinit();

    for (seq[0 .. seq.len - 1], seq[1..]) |a, b| {
        const adiff: usize = @intCast(if (a > b) a - b else b - a);
        if (adiff < 1 or adiff >= seq.len)
            return false;
        unique.set(adiff - 1);
    }

    return unique.count() == seq.len - 1;
}

test {
    var seq = [_]i8{ 1, 4, 2, 3 };
    try std.testing.expect(try jolly(std.testing.allocator, i8, &seq));
}

test {
    var seq = [_]u8{ 1, 4, 2, 3, 9 };
    try std.testing.expect(!try jolly(std.testing.allocator, u8, &seq));
}
