const std = @import("std");
const Allocator = std.mem.Allocator;

const Cache = struct {
    i: usize,
    j: usize,
    entries: []bool,
    allocator: Allocator,

    pub fn init(allocator: Allocator, i: u32, j: u32) !@This() {
        var entries = try allocator.alloc(bool, j - i + 1);
        for (entries) |*b|
            b.* = false;

        return @This(){
            .i = i,
            .j = j,
            .entries = entries,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *const @This()) void {
        self.allocator.free(self.entries);
    }

    pub fn seen(self: *const @This(), k: usize) bool {
        return k >= self.i and k <= self.j and self.entries[k - self.i];
    }

    pub fn mark_seen(self: *@This(), k: usize) void {
        if (k >= self.i and k <= self.j)
            self.entries[k - self.i] = true;
    }
};

pub fn collatz(allocator: Allocator, i: u32, j: u32) !u32 {
    var cache = try Cache.init(allocator, i, j);
    defer cache.deinit();

    var max_cycle_length: u32 = 0;

    for (i..j + 1) |k| {
        if (cache.seen(k))
            continue;
        var n: u32 = @intCast(k);
        var cycle_length: u32 = 1;
        while (n != 1) {
            if ((n & 1) == 1) {
                n = 3 * n + 1;
            } else {
                n = n >> 1;
            }
            cache.mark_seen(n);
            cycle_length += 1;
        }
        max_cycle_length = @max(max_cycle_length, cycle_length);
    }

    return max_cycle_length;
}

test {
    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(u32, 20), try collatz(allocator, 1, 10));
    try std.testing.expectEqual(@as(u32, 125), try collatz(allocator, 100, 200));
    try std.testing.expectEqual(@as(u32, 89), try collatz(allocator, 201, 210));
    try std.testing.expectEqual(@as(u32, 174), try collatz(allocator, 900, 1000));
}
