const std = @import("std");

inline fn str_lt(a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

inline fn str_eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

fn heap_sort(comptime T: type, lt: anytype, _data: []T) void {
    const MaxHeap = struct {
        data: []T,
        len: usize,

        const Heap = @This();

        const Node = struct {
            i: usize,
            heap: *const Heap,

            pub inline fn val(self: @This()) T {
                return self.heap.data[self.i];
            }

            pub inline fn child(self: @This(), offset: usize) ?@This() {
                const i = offset + 1 + 2 * self.i;
                if (i >= self.heap.len)
                    return null;
                return @This(){ .i = i, .heap = self.heap };
            }
        };

        pub fn init(data: []T) @This() {
            var rtn: @This() = .{ .data = data, .len = data.len };
            rtn.make_heap();
            return rtn;
        }

        fn make_heap(self: *const @This()) void {
            var i: usize = self.len;
            while (i >= 1) : (i -= 1)
                self.bubble_down(self.node_at(i - 1));
        }

        inline fn node_at(self: *const @This(), i: usize) Node {
            return .{ .i = i, .heap = self };
        }

        pub fn extract_max(self: *@This()) T {
            defer {
                self.data[0] = self.data[self.len - 1];
                self.len -= 1;
                self.bubble_down(self.node_at(0));
            }
            return self.data[0];
        }

        fn bubble_down(self: *const @This(), node: Node) void {
            var max_idx: usize = node.i;
            for (0..2) |i| {
                const child = node.child(i) orelse break;
                if (lt(self.node_at(max_idx).val(), child.val()))
                    max_idx = child.i;
            }

            if (max_idx != node.i) {
                const z = self.data[node.i];
                self.data[node.i] = self.data[max_idx];
                self.data[max_idx] = z;
                self.bubble_down(self.node_at(max_idx));
            }
        }
    };

    var heap = MaxHeap.init(_data);
    for (0.._data.len) |i|
        _data[_data.len - 1 - i] = heap.extract_max();
}

test "sort" {
    var words = [_][]const u8{ "hello", "world", "asdf" };
    heap_sort([]const u8, str_lt, &words);
    try std.testing.expect(str_eql("asdf", words[0]));
    try std.testing.expect(str_eql("hello", words[1]));
    try std.testing.expect(str_eql("world", words[2]));
}

// mutates data, return value references original buffer and does not take ownership
fn extract_unique_from_sorted(comptime T: type, eql: anytype, data: []T) []T {
    if (data.len < 1)
        return data;
    var i: usize = 1;
    var prev = data[0];
    for (data[1..]) |x| {
        if (!eql(prev, x)) {
            data[i] = x;
            i += 1;
            prev = x;
        }
    }
    return data[0..i];
}

pub fn extract_unique(comptime T: type, lt: anytype, eql: anytype, data: []T) []T {
    heap_sort(T, lt, data);
    return extract_unique_from_sorted(T, eql, data);
}

inline fn prim_lt(a: anytype, b: anytype) bool {
    return a < b;
}

inline fn prim_eql(a: anytype, b: anytype) bool {
    return a == b;
}

test "unique" {
    const msg = "the quick brown fox jumps over the lazy dog";
    var _data: [msg.len]u8 = msg.*;
    var data: []u8 = &_data;
    try std.testing.expect(str_eql(" abcdefghijklmnopqrstuvwxyz", extract_unique(u8, prim_lt, prim_eql, data)));
}
