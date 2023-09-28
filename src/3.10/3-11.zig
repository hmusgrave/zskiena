const std = @import("std");
const Allocator = std.mem.Allocator;
const Random = std.rand.Random;

pub fn RangeMin(comptime T: type) type {
    const Node = struct {
        left_i: usize,
        right_i: usize,
        i: usize,
        val: *T,
        raw: []T,

        pub inline fn init(raw: []T) ?@This() {
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
        table: []T,
        data: []const T,
        allocator: Allocator,

        pub fn init(allocator: Allocator, data: []const T) !@This() {
            var table = try allocator.alloc(T, data.len);
            for (table, data) |*x, d|
                x.* = d;
            var rtn = @This(){
                .table = table,
                .data = data,
                .allocator = allocator,
            };
            for (data, 1..) |x, i| // book 1-indexes
                rtn.add(i, x);
            return rtn;
        }

        pub fn deinit(self: *const @This()) void {
            self.allocator.free(self.table);
        }

        pub fn add(self: *@This(), _i: usize, x: T) void {
            const i = _i - 1; // book 1-indexes
            var node = Node.init(self.table) orelse return;
            while (true) {
                node.val.* = @min(x, node.val.*);
                if (i == node.i)
                    return;
                if (i < node.i) {
                    node = node.left() orelse return;
                } else {
                    node = node.right() orelse return;
                }
            }
        }

        pub inline fn range_min(self: *const @This(), _i: usize, _j: usize) ?T {
            const i = _i - 1; // book 1-indexes
            const j = _j - 1; // book 1-indexes
            var node = Node.init(self.table) orelse return null;
            return self._range_min(i, j, node);
        }

        inline fn null_min(a: ?T, b: ?T) ?T {
            if (a) |x|
                return @min(x, b orelse x);
            return b;
        }

        fn _range_min(self: *const @This(), i: ?usize, j: ?usize, _node: ?Node) ?T {
            var node = _node orelse return null;
            var include_self = blk: {
                if (i == null and j == null)
                    break :blk true;
                if (i == null)
                    break :blk node.i <= j.?;
                if (j == null)
                    break :blk node.i >= i.?;
                break :blk i.? <= node.i and node.i <= j.?;
            };

            const left_upper_bound = if (include_self) null else j;
            const right_lower_bound = if (include_self) null else i;

            var rtn = self._range_min(i, left_upper_bound, node.left());
            rtn = null_min(rtn, self._range_min(right_lower_bound, j, node.right()));
            if (include_self)
                rtn = null_min(rtn, self.data[node.i]);
            return rtn;
        }
    };
}

test {
    var data = [_]usize{ 4, 0, 5, 8, 1, 2 };
    var rm = try RangeMin(usize).init(std.testing.allocator, &data);
    defer rm.deinit();

    try std.testing.expectEqual(@as(?usize, 0), rm.range_min(1, 2));
    try std.testing.expectEqual(@as(?usize, 0), rm.range_min(1, 3));
    try std.testing.expectEqual(@as(?usize, 4), rm.range_min(1, 1));
    try std.testing.expectEqual(@as(?usize, 5), rm.range_min(3, 4));
    try std.testing.expectEqual(@as(?usize, 1), rm.range_min(3, 5));
    try std.testing.expectEqual(@as(?usize, 1), rm.range_min(3, 6));
}
