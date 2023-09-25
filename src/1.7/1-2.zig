const std = @import("std");

pub fn the_trip(cents: []u64) u64 {
    if (cents.len == 0)
        return 0;

    var total: u64 = 0;
    for (cents) |c|
        total += c;

    const integer_average = total / cents.len;
    if (total % integer_average == 0) {
        var rtn: u64 = 0;
        for (cents) |c| {
            if (c > integer_average) {
                rtn += c - integer_average;
            }
        }
        return rtn;
    } else {
        var lower: u64 = 0;
        var upper: u64 = 0;
        for (cents) |c| {
            if (c > integer_average + 1) {
                upper += c - (integer_average + 1);
            } else if (c < integer_average) {
                lower += integer_average - c;
            }
        }
        return @max(lower, upper);
    }
}

test {
    var a = [_]u64{ 1000, 2000, 3000 };
    try std.testing.expectEqual(@as(u64, 1000), the_trip(&a));

    var b = [_]u64{ 1500, 1501, 300, 301 };
    try std.testing.expectEqual(@as(u64, 1199), the_trip(&b));
}
