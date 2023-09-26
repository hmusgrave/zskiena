const std = @import("std");

pub fn multiplication_game(n: u32) u1 {
    // returns whether the 0th player or the 1st player wins
    if (n <= 9)
        return 0;
    var thresh: u64 = 9 * 2;
    var next_mul: u64 = 9;
    var next_winner: u1 = 1;
    while (true) : (next_winner = 1 - next_winner) {
        if (n <= thresh)
            return next_winner;
        thresh *= next_mul;
        next_mul = if (next_mul == 2) 9 else 2;
    }
}

test {
    try std.testing.expectEqual(@as(u1, 0), multiplication_game(5));
    try std.testing.expectEqual(@as(u1, 0), multiplication_game(162));
    try std.testing.expectEqual(@as(u1, 1), multiplication_game(17));
    try std.testing.expectEqual(@as(u1, 0), multiplication_game(34012226));
}
