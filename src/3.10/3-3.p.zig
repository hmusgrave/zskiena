const std = @import("std");

inline fn normalize(a: u8) u8 {
    // TODO: look up the order?
    if (comptime 'a' < 'A') {
        return if ('a' <= a and a <= 'z') a else a - ('A' - 'a');
    } else {
        return if ('a' <= a and a <= 'z') a else a + ('a' - 'A');
    }
}

inline fn eql(a: u8, b: u8) bool {
    return normalize(a) == normalize(b);
}

inline fn abs(x: anytype) @TypeOf(x) {
    return if (x < 0) -x else x;
}

inline fn sgn(x: anytype) @TypeOf(x) {
    return if (x == 0) x else @divExact(x, abs(x));
}

inline fn move(x: usize, dx: i8) ?usize {
    if (dx < 0) {
        const negated: usize = @intCast(-dx);
        if (x > 0)
            return x - negated;
        return null;
    }
    const bigger: usize = @intCast(dx);
    return x + bigger;
}

const DirectionIter = struct {
    dx: i8,
    dy: i8,
    started: bool,

    pub fn init() @This() {
        return .{
            .dx = 1,
            .dy = 0,
            .started = false,
        };
    }

    pub fn next(self: *@This()) ?[2]i8 {
        if (self.dx == 1 and self.dy == 0 and self.started)
            return null;
        defer {
            self.started = true;
            const dx = sgn(self.dx + self.dy);
            const dy = sgn(-self.dx + self.dy);
            self.dx = dx;
            self.dy = dy;
        }
        return [2]i8{ self.dx, self.dy };
    }

    pub fn matches_lower(self: *@This(), mat: []const u8, m: usize, n: usize, x: usize, y: usize, phrase: []const u8) bool {
        while (self.next()) |dir| {
            var path = PathIter.init(mat, m, n, x, y, dir[0], dir[1]);
            if (path.matches_lower(phrase))
                return true;
        }
        return false;
    }
};

const PathIter = struct {
    mat: []const u8,
    m: usize,
    n: usize,
    dx: i8,
    dy: i8,
    next_x: usize,
    next_y: usize,

    pub fn init(mat: []const u8, m: usize, n: usize, x: usize, y: usize, dx: i8, dy: i8) @This() {
        return @This(){ .mat = mat, .m = m, .n = n, .next_x = x, .next_y = y, .dx = dx, .dy = dy };
    }

    pub fn next(self: *@This()) ?u8 {
        if (self.next_x < 0 or self.next_y < 0)
            return null;
        if (self.next_x >= self.m or self.next_y >= self.n)
            return null;
        defer {
            self.next_x = move(self.next_x, self.dx) orelse self.m + 1;
            self.next_y = move(self.next_y, self.dy) orelse self.n + 1;
        }
        return self.mat[self.n * self.next_x + self.next_y];
    }

    pub fn matches_lower(self: *@This(), phrase: []const u8) bool {
        for (phrase) |c| {
            if (!eql(c, self.next() orelse return false))
                return false;
        }
        return true;
    }
};

pub fn first_occurence(grid: []const u8, m: usize, n: usize, phrase: []const u8) ?[2]usize {
    for (0..m) |i| {
        for (0..n) |j| {
            var dir = DirectionIter.init();
            if (dir.matches_lower(grid, m, n, i, j, phrase))
                return [2]usize{ i, j };
        }
    }
    return null;
}

test {
    const grid = "abcDEFGhigghEbkWalDorkFtyAwaldORmFtsimrLqsrcbyoArBeDeyvKlcbqwikomkstrEBGadhrbyUiqlxcnBjf";
    const m = 8;
    const n = 11;

    try std.testing.expectEqualDeep([2]usize{ 1, 4 }, first_occurence(grid, m, n, "Waldorf").?);
    try std.testing.expectEqualDeep([2]usize{ 1, 2 }, first_occurence(grid, m, n, "Bambi").?);
    try std.testing.expectEqualDeep([2]usize{ 0, 1 }, first_occurence(grid, m, n, "Betty").?);
    try std.testing.expectEqualDeep([2]usize{ 6, 7 }, first_occurence(grid, m, n, "Dagbert").?);
}
