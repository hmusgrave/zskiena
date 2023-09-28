const std = @import("std");
const Allocator = std.mem.Allocator;

const novel = @embedFile("3-16.txt");

const HeapArena = struct {
    parent_allocator: Allocator,
    arena: *std.heap.ArenaAllocator,
    allocator: Allocator,

    pub fn init(allocator: Allocator) !@This() {
        var arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);

        arena.* = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        return @This(){
            .parent_allocator = allocator,
            .arena = arena,
            .allocator = arena.allocator(),
        };
    }

    pub fn deinit(self: *const @This()) void {
        defer self.parent_allocator.destroy(self.arena);
        defer self.arena.deinit();
    }
};

pub inline fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub inline fn lt(a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

pub inline fn hash_range(a: []const u8, max: usize) usize {
    var hasher = std.hash.Wyhash.init(42);
    hasher.update(a);
    const hash_result: u64 = hasher.final();
    if (comptime @sizeOf(u64) >= @sizeOf(usize)) {
        const z: usize = @truncate(hash_result);
        return z % max;
    } else {
        const z: usize = @intCast(hash_result);
        return z % max;
    }
}

pub const ListSet = struct {
    pub const Node = struct {
        val: []const u8,
        child: ?*@This(),
    };

    root: ?*Node,
    arena: HeapArena,
    len: usize,

    pub fn init(allocator: Allocator) !@This() {
        return @This(){
            .root = null,
            .arena = try HeapArena.init(allocator),
            .len = 0,
        };
    }

    pub fn deinit(self: *const @This()) void {
        self.arena.deinit();
    }

    pub fn insert(self: *@This(), key: []const u8) !void {
        if (self.contains(key))
            return;
        var node = try self.arena.allocator.create(Node);
        node.* = .{
            .val = key,
            .child = self.root,
        };
        self.len += 1;
        self.root = node;
    }

    pub fn contains(self: *@This(), key: []const u8) bool {
        var node = self.root orelse return false;
        while (node.child) |child| : (node = child) {
            if (eql(node.val, key))
                return true;
        }
        return eql(node.val, key);
    }
};

test {
    var set = try ListSet.init(std.testing.allocator);
    defer set.deinit();

    // truncating to keep test suite fast
    var iter = std.mem.tokenizeAny(u8, novel[0..10000], " ");
    while (iter.next()) |word|
        try set.insert(word);
    try std.testing.expectEqual(@as(usize, 826), set.len);
}

pub const TreeSet = struct {
    pub const Node = struct {
        val: []const u8,
        left: ?*@This(),
        right: ?*@This(),
    };

    root: ?*Node,
    arena: HeapArena,
    len: usize,

    pub fn init(allocator: Allocator) !@This() {
        return @This(){
            .root = null,
            .arena = try HeapArena.init(allocator),
            .len = 0,
        };
    }

    pub fn deinit(self: *const @This()) void {
        self.arena.deinit();
    }

    inline fn create(self: *@This(), key: []const u8) !*Node {
        var rtn = try self.arena.allocator.create(Node);
        self.len += 1;
        rtn.* = .{
            .val = key,
            .left = null,
            .right = null,
        };
        return rtn;
    }

    pub fn insert(self: *@This(), key: []const u8) !void {
        var node = self.root orelse {
            self.root = try self.create(key);
            return;
        };

        while (true) {
            if (eql(node.val, key))
                return;
            if (lt(node.val, key)) {
                if (node.right) |right| {
                    node = right;
                } else {
                    node.right = try self.create(key);
                    return;
                }
            } else {
                if (node.left) |left| {
                    node = left;
                } else {
                    node.left = try self.create(key);
                    return;
                }
            }
        }
    }
};

test {
    var set = try TreeSet.init(std.testing.allocator);
    defer set.deinit();

    var iter = std.mem.tokenizeAny(u8, novel, " ");
    while (iter.next()) |word|
        try set.insert(word);
    try std.testing.expectEqual(@as(usize, 23060), set.len);
}

pub const HashSet = struct {
    pub const Bucket = struct {
        data: [8]?[]const u8,
    };

    buckets: []Bucket,
    arena: HeapArena,
    len: usize,

    pub fn init(allocator: Allocator) !@This() {
        var arena = try HeapArena.init(allocator);
        errdefer arena.deinit();

        var buckets = try arena.allocator.alloc(Bucket, 1 << 10);
        for (buckets) |*bucket| {
            for (bucket.data[0..]) |*p|
                p.* = null;
        }

        return @This(){
            .buckets = buckets,
            .arena = arena,
            .len = 0,
        };
    }

    pub fn deinit(self: *const @This()) void {
        self.arena.deinit();
    }

    fn double(self: *@This()) !void {
        @setCold(true);
        var new_buckets = try self.arena.allocator.alloc(Bucket, self.buckets.len * 2);
        defer {
            self.arena.allocator.free(self.buckets); // actually leaks memory with current Arena impl
            self.buckets = new_buckets;
        }
        for (new_buckets) |*bucket| {
            for (bucket.data[0..]) |*p|
                p.* = null;
        }
        for (self.buckets) |bucket| {
            for (bucket.data[0..]) |slot| {
                const val = slot orelse break;
                const idx = hash_range(val, new_buckets.len);
                var new_bucket = &new_buckets[idx];
                var _first_empty: ?usize = null;
                for (new_bucket.data[0..], 0..) |*new_slot, i| {
                    if (new_slot.*) |_|
                        continue;
                    _first_empty = i;
                    break;
                }
                const first_empty = _first_empty orelse return error.TooManyCollisions;
                new_bucket.data[first_empty] = val;
            }
        }
    }

    pub fn insert(self: *@This(), key: []const u8) !void {
        if (self.len >= self.buckets.len / 2)
            try self.double();
        const idx = hash_range(key, self.buckets.len);
        var bucket = &self.buckets[idx];
        var _first_empty: ?usize = null;
        for (bucket.data[0..], 0..) |*slot, i| {
            var other = slot.* orelse {
                _first_empty = i;
                break;
            };
            if (eql(other, key))
                return;
        }
        const first_empty = _first_empty orelse return error.TooManyCollisions;
        self.len += 1;
        bucket.data[first_empty] = key;
    }
};

test {
    var set = try HashSet.init(std.testing.allocator);
    defer set.deinit();

    var iter = std.mem.tokenizeAny(u8, novel, " ");
    while (iter.next()) |word|
        try set.insert(word);
    try std.testing.expectEqual(@as(usize, 23060), set.len);
}
