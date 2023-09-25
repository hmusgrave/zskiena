const std = @import("std");
const Allocator = std.mem.Allocator;

inline fn top_choice(ballot: []usize, exclusions: []bool) usize {
    // ignore error handling since we're calling this once
    // and never using it again in any other code
    var lowest_numeric_rank: usize = ballot.len + 1;
    var rtn: usize = 0;
    for (ballot, exclusions, 0..) |b, e, i| {
        if (e)
            continue;
        if (b < lowest_numeric_rank) {
            lowest_numeric_rank = b;
            rtn = i;
        }
    }
    return rtn;
}

pub fn vote(allocator: Allocator, ballots: [][]usize) !usize {
    if (ballots.len == 0)
        return error.Void;

    var d: usize = ballots[0].len;
    for (ballots[1..]) |b| {
        if (b.len != d)
            return error.CandidateCount;
    }

    // if votes are at least threshold the candidate
    // wins
    const threshold = 1 + (ballots.len >> 1);

    var votes = try allocator.alloc(usize, d);
    defer allocator.free(votes);

    var excluded = try allocator.alloc(bool, d);
    defer allocator.free(excluded);
    for (excluded) |*e|
        e.* = false;

    for (0..d) |_| {
        for (votes) |*v|
            v.* = 0;
        for (ballots) |b|
            votes[top_choice(b, excluded)] += 1;
        var min_vote = votes[0];
        var min_i: usize = 0;
        for (votes, 0..) |v, i| {
            if (v >= threshold)
                return i;
            if (v < min_vote) {
                min_vote = v;
                min_i = i;
            }
        }
        excluded[min_i] = true;
    }

    unreachable;
}

test {
    const allocator = std.testing.allocator;
    var a: [3]usize = .{ 1, 2, 3 };
    var b: [3]usize = .{ 2, 1, 3 };
    var c: [3]usize = .{ 2, 3, 1 };
    var d: [3]usize = .{ 1, 2, 3 };
    var e: [3]usize = .{ 3, 1, 2 };
    var f: [5][]usize = .{ &a, &b, &c, &d, &e };
    try std.testing.expectEqual(@as(usize, 0), try vote(allocator, &f));
}
