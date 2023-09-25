const std = @import("std");

pub fn idiv(x: u32, y: u32) !u32 {
    if (y == 0)
        return error.DivideByZero;
    if (x == 0)
        return 0;
    // y_powers[i] holds y * (2**i)
    var y_powers: [32]u32 = undefined;
    y_powers[0] = y;
    for (y_powers[1..], 0..) |*p, i|
        p.* = y_powers[i] +| y_powers[i];
    var j: usize = 32;
    var z = x;
    var rtn: u32 = 0;
    while (j > 0) : (j -= 1) {
        const i = j - 1;
        rtn <<= 1;
        if (y_powers[i] <= z) {
            if (z - y_powers[i] < y_powers[i]) {
                rtn += 1;
                z -= y_powers[i];
            }
        }
    }
    return rtn;
}

fn check_idiv(x: u32, y: u32) !void {
    if (y == 0) {
        try std.testing.expectError(error.DivideByZero, idiv(x, y));
    } else {
        try std.testing.expectEqual(@as(u32, x / y), try idiv(x, y));
    }
}

test {
    for (0..10) |i| {
        for (0..10) |j| {
            try check_idiv(@intCast(i), @intCast(j));
        }
    }
}
