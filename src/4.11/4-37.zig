const std = @import("std");
const Allocator = std.mem.Allocator;

pub inline fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub inline fn lt(a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

fn selection_sort(_data: [][]const u8) void {
    var data = _data;

    const min_idx_unsafe = struct {
        fn f(slc: [][]const u8) usize {
            var i: usize = 0;
            var s: []const u8 = slc[0];
            for (slc[1..], 1..) |t, j| {
                if (lt(t, s)) {
                    i = j;
                    s = t;
                }
            }
            return i;
        }
    }.f;

    while (data.len > 1) : (data = data[1..]) {
        const i = min_idx_unsafe(data);
        if (i > 0) {
            const z = data[0];
            data[0] = data[i];
            data[i] = z;
        }
    }
}

test "selection" {
    var words = [_][]const u8{ "hello", "world", "asdf" };
    selection_sort(&words);
    try std.testing.expect(eql("asdf", words[0]));
    try std.testing.expect(eql("hello", words[1]));
    try std.testing.expect(eql("world", words[2]));
}

const MaxHeap = struct {
    data: [][]const u8,
    len: usize,

    const Heap = @This();

    const Node = struct {
        i: usize,
        heap: *const Heap,

        pub inline fn val(self: @This()) []const u8 {
            return self.heap.data[self.i];
        }

        pub inline fn child(self: @This(), offset: usize) ?@This() {
            const i = offset + 1 + 2 * self.i;
            if (i >= self.heap.len)
                return null;
            return @This(){ .i = i, .heap = self.heap };
        }
    };

    pub fn init(data: [][]const u8) @This() {
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

    pub fn extract_max(self: *@This()) []const u8 {
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
            if (lt(node.val(), child.val()))
                max_idx = child.i;
        }

        if (max_idx != node.i) {
            std.mem.swap([]const u8, &self.data[node.i], &self.data[max_idx]);
            self.bubble_down(self.node_at(max_idx));
        }
    }
};

fn heap_sort(data: [][]const u8) void {
    var heap = MaxHeap.init(data);
    for (0..data.len) |i|
        data[data.len - 1 - i] = heap.extract_max();
}

test "heap" {
    var words = [_][]const u8{ "hello", "world", "asdf" };
    heap_sort(&words);
    try std.testing.expect(eql("asdf", words[0]));
    try std.testing.expect(eql("hello", words[1]));
    try std.testing.expect(eql("world", words[2]));
}

fn merge_sort(allocator: Allocator, data: [][]const u8) !void {
    var buffer = try allocator.alloc([]const u8, data.len);
    defer allocator.free(buffer);
    _merge_sort_unsafe(data, buffer);
}

fn _merge_sort_unsafe(data: [][]const u8, buffer: [][]const u8) void {
    defer {
        for (data[0..], buffer[0..]) |x, *t|
            t.* = x;
    }
    if (data.len < 10) {
        selection_sort(data);
        return;
    }
    const i = data.len >> 1;
    _merge_sort_unsafe(data[0..i], buffer[0..i]);
    _merge_sort_unsafe(data[i..], buffer[i..]);
    _merge_unsafe(buffer[0..i], buffer[i..], data);
}

fn _merge_unsafe(_a: []const []const u8, _b: []const []const u8, _out: [][]const u8) void {
    var a = _a;
    var b = _b;
    var out = _out;
    while (a.len > 0 and b.len > 0) {
        defer out = out[1..];
        if (lt(a[0], b[0])) {
            defer a = a[1..];
            out[0] = a[0];
        } else {
            defer b = b[1..];
            out[0] = b[0];
        }
    }
    var c = if (a.len > b.len) a else b;
    for (c, out) |x, *t|
        t.* = x;
}

test "merge" {
    var words = [_][]const u8{ "hello", "world", "asdf" };
    try merge_sort(std.testing.allocator, &words);
    try std.testing.expect(eql("asdf", words[0]));
    try std.testing.expect(eql("hello", words[1]));
    try std.testing.expect(eql("world", words[2]));
}

fn quick_sort(data: [][]const u8) void {
    if (data.len < 10) {
        selection_sort(data);
        return;
    }
    //if (data.len < 1)
    //    return;
    const p = partition(data, data.len - 1);
    quick_sort(data[0..p]);
    quick_sort(data[p + 1 ..]);
}

fn partition(data: [][]const u8, p: usize) usize {
    var first_high: usize = 0;
    for (0..data.len) |i| {
        if (lt(data[i], data[p])) {
            std.mem.swap([]const u8, &data[i], &data[first_high]);
            first_high += 1;
        }
    }
    std.mem.swap([]const u8, &data[p], &data[first_high]);
    return first_high;
}

test "quick" {
    var words = [_][]const u8{ "hello", "world", "asdf" };
    quick_sort(&words);
    try std.testing.expect(eql("asdf", words[0]));
    try std.testing.expect(eql("hello", words[1]));
    try std.testing.expect(eql("world", words[2]));
}

const novel = @embedFile("4-37.txt");

fn to_words(allocator: Allocator) ![][]const u8 {
    //var text = novel[0..novel.len];
    var text = novel[0..1000];

    var i: usize = 0;
    var iter = std.mem.tokenizeAny(u8, text, " ");
    while (iter.next()) |_|
        i += 1;

    var result = try allocator.alloc([]const u8, i);
    iter = std.mem.tokenizeAny(u8, text, " ");
    i = 0;
    while (iter.next()) |word| : (i += 1)
        result[i] = word;

    return result;
}

fn timeit_ns(allocator: Allocator, sort: anytype) !u64 {
    var book = try to_words(allocator);
    defer allocator.free(book);

    var timer = try std.time.Timer.start();
    if (comptime @typeInfo(@TypeOf(sort)).Fn.params.len == 2) {
        try sort(allocator, book);
    } else {
        sort(book);
    }
    return timer.read();
}

test "benchmark" {
    if (false) {
        const a = try timeit_ns(std.testing.allocator, selection_sort);
        const b = try timeit_ns(std.testing.allocator, heap_sort);
        const c = try timeit_ns(std.testing.allocator, merge_sort);
        const d = try timeit_ns(std.testing.allocator, quick_sort);

        std.debug.print("-\n{}\n{}\n{}\n{}\n", .{ a, b, c, d });
    }
}
