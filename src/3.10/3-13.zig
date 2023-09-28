const std = @import("std");
const Allocator = std.mem.Allocator;
const Random = std.rand.Random;

pub fn PartialSum(comptime F: type) type {
    const Node = struct {
        left_i: usize,
        right_i: usize,
        i: usize,
        val: *F,
        raw: []F,

        pub inline fn init(raw: []F) ?@This() {
            if (raw.len == 0)
                return null;
            const mid = range_mid(0, raw.len - 1);
            return @This(){
                .left_i = 0,
                .right_i = raw.len - 1,
                .i = mid,
                .val = &raw[mid],
                .raw = raw,
            };
        }

        pub inline fn sum_le(self: *const @This()) F {
            const bigger = if (self.right()) |r| r.val.* else 0;
            return self.val.* - bigger;
        }

        inline fn range_mid(a: usize, b: usize) usize {
            return (a >> 1) + (b >> 1) + (a & b & 1);
        }

        pub inline fn left(self: *const @This()) ?@This() {
            const right_i = @max(self.left_i, @max(1, self.i) - 1);
            const mid = range_mid(self.left_i, right_i);
            if (mid == self.i)
                return null;
            return @This(){
                .left_i = self.left_i,
                .right_i = right_i,
                .i = mid,
                .val = &self.raw[mid],
                .raw = self.raw,
            };
        }

        pub inline fn right(self: *const @This()) ?@This() {
            const left_i = @min(self.right_i, self.i + 1);
            const mid = range_mid(left_i, self.right_i);
            if (mid == self.i)
                return null;
            return @This(){
                .left_i = left_i,
                .right_i = self.right_i,
                .i = mid,
                .val = &self.raw[mid],
                .raw = self.raw,
            };
        }
    };

    return struct {
        table: []F,
        allocator: Allocator,

        pub fn init(allocator: Allocator, data: []const F) !@This() {
            var table = try allocator.alloc(F, data.len);
            for (table) |*x|
                x.* = 0;
            var rtn = @This(){
                .table = table,
                .allocator = allocator,
            };
            for (data, 1..) |x, i| // book 1-indexes
                rtn.add(i, x);
            return rtn;
        }

        pub fn deinit(self: *const @This()) void {
            self.allocator.free(self.table);
        }

        pub fn add(self: *@This(), _i: usize, x: F) void {
            const i = _i - 1; // book 1-indexes
            var node = Node.init(self.table) orelse return;
            while (true) {
                node.val.* += x;
                if (i == node.i)
                    return;
                if (i < node.i) {
                    node = node.left() orelse return;
                } else {
                    node = node.right() orelse return;
                }
            }
        }

        pub fn prefix_sum(self: *const @This(), _i: usize) F {
            const i = _i - 1; // book 1-indexes
            var node = Node.init(self.table) orelse return 0;
            var total: F = 0;
            while (true) {
                if (i == node.i)
                    return total + node.sum_le();

                if (i < node.i) {
                    node = node.left() orelse return total;
                } else {
                    total += node.sum_le();
                    node = node.right() orelse return total;
                }
            }
        }
    };
}

test {
    var prng = std.rand.DefaultPrng.init(0);
    const rand = prng.random();

    var data = [_]f32{0} ** 10;
    var ps = try PartialSum(f32).init(std.testing.allocator, &data);
    defer ps.deinit();

    for (0..40) |_| {
        var insert_i = rand.uintLessThanBiased(usize, data.len) + 1; // book 1-indexes;
        var prefix_i = rand.uintLessThanBiased(usize, data.len) + 1; // book 1-indexes;
        var val = rand.float(f32);
        ps.add(insert_i, val);
        data[insert_i - 1] += val;
        var expected: f32 = 0;
        for (data[0 .. prefix_i + 1 - 1]) |z|
            expected += z;
        try std.testing.expectApproxEqAbs(expected, ps.prefix_sum(prefix_i), 1e-4);
    }
}
