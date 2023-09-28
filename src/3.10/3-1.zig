const std = @import("std");

pub const BalanceResult = union(enum) {
    balanced: void,
    first_offense: usize,
};

// 0 is open paren, 1 is close. No need to munge about with
// potentially invalid inputs.
pub fn check_balance(parens: []const u1) BalanceResult {
    var open_count: usize = 0;
    for (parens, 0..) |p, i| {
        if (p == 1 and open_count == 0)
            return .{ .first_offense = i };
        if (p == 0) {
            open_count += 1;
        } else {
            open_count -= 1;
        }
    }

    // there really isn't a first offending parenthese...
    if (open_count != 0)
        return .{ .first_offense = parens.len };

    return .balanced;
}

test {
    const a = [_]u1{ 1, 0, 1, 0 };
    const b = [_]u1{ 0, 1, 1 };
    const c = [_]u1{ 0, 0, 0, 1, 1, 0, 1, 1, 0, 1 };
    const d = [_]u1{ 0, 0, 0 };
    try std.testing.expectEqual(BalanceResult{ .first_offense = 0 }, check_balance(&a));
    try std.testing.expectEqual(BalanceResult{ .first_offense = 2 }, check_balance(&b));
    try std.testing.expectEqual(BalanceResult{ .balanced = {} }, check_balance(&c));
    try std.testing.expectEqual(BalanceResult{ .first_offense = 3 }, check_balance(&d));
}
