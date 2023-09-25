const std = @import("std");

const indices: [5][6]usize = .{
    .{ 1, 3, 7, 9, 12, 13 },
    .{ 3, 4, 6, 7, 11, 14 },
    .{ 0, 1, 2, 5, 10, 12 },
    .{ 2, 4, 5, 8, 9, 14 },
    .{ 0, 6, 8, 10, 11, 13 },
};

pub fn tickets(winning_superset: [15]usize) [5][6]usize {
    var rtn: [5][6]usize = undefined;
    for (rtn[0..], indices) |*row_out, row_in| {
        for (row_out, row_in) |*out, in|
            out.* = winning_superset[in];
    }
    return rtn;
}

test {
    _ = tickets(.{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 });
}
