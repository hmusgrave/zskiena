const std = @import("std");
const Allocator = std.mem.Allocator;

inline fn dist(comptime F: type, a: anytype, b: anytype) F {
    return @sqrt(@reduce(.Add, (a - b) * (a - b)));
}

pub fn NearestNeighbor(comptime F: type) type {
    const Point = @Vector(2, F);
    const List = std.ArrayList(Point);

    return struct {
        remaining: List,
        p: ?Point,
        initial: ?Point,

        fn closest(self: *const @This(), p: Point) ?usize {
            if (self.remaining.items.len < 1)
                return null;
            const items = self.remaining.items;
            var min_d = dist(F, p, items[0]);
            var min_i: usize = 0;
            for (items[1..], 1..) |q, i| {
                const d = dist(F, p, q);
                if (d < min_d) {
                    min_d = d;
                    min_i = i;
                }
            }
            return min_i;
        }

        pub fn init(allocator: Allocator, points: []Point) !@This() {
            if (points.len < 1)
                return @This(){ .remaining = undefined, .p = null, .initial = null };

            var remaining = List.init(allocator);
            errdefer remaining.deinit();

            try remaining.appendSlice(points[1..]);
            return @This(){
                .remaining = remaining,
                .p = points[0],
                .initial = points[0],
            };
        }

        pub fn deinit(self: *const @This()) void {
            self.remaining.deinit();
        }

        pub fn next(self: *@This()) ?Point {
            if (self.p) |p| {
                defer {
                    if (self.closest(p)) |qi| {
                        self.p = self.remaining.swapRemove(qi);
                    } else {
                        self.p = null;
                    }
                }
                return p;
            } else {
                defer self.initial = null;
                return self.initial;
            }
        }
    };
}

pub fn ClosestPair(comptime F: type) type {
    const Point = @Vector(2, F);

    // TODO: The "link" operation described in the book's pseudocode
    // should really be a constant-time thingamajig that doesn't imply
    // a traversal order. That'd be easier if this were a doubly-linked list
    // and if the traversal logic ensured we never looped back to the same node
    // immediately.
    //
    // It doesn't affect the Big-O complexity to have to reverse the list
    // half the time, but it's definitely a wasted effort.
    //
    // Ignoring that point completely because it's only supposed to be a
    // simple exercise, and this particular data-structure probably won't
    // be re-used much (ever?).
    const Node = struct {
        next: ?*@This(),
        val: *Point,
    };

    // head might equal tail, and when they
    // are equal that does not imply a chain
    // of length 1 (examine next pointers)
    const Chain = struct {
        head: *Node,
        tail: *Node,

        pub fn reverse(self: *@This()) void {
            if (self.head == self.tail) {
                return;
            }
            var prev: *Node = self.head;
            var prepped: ?*Node = self.head.next;
            while (prepped != null) {
                const c = prepped.?.next;
                prepped.?.next = prev;
                prepped = c;
            }
        }
    };

    return struct {
        root: ?Node,
        p: ?Node,
        allocator: Allocator,
        nodes: []Node,

        pub fn next(self: *@This()) ?Point {
            if (self.p) |p| {
                defer self.p = if (p.next) |q| q.* else null;
                return p.val.*;
            } else {
                defer self.root = null;
                if (self.root) |r|
                    return r.val.*;
                return null;
            }
        }

        pub fn init(allocator: Allocator, points: []Point) !@This() {
            var nodes = try allocator.alloc(Node, points.len);
            errdefer allocator.free(nodes);

            var chains = std.ArrayList(Chain).init(allocator);
            defer chains.deinit();
            try chains.ensureTotalCapacity(points.len);

            for (nodes, points) |*n, *p|
                n.* = .{ .next = null, .val = p };

            for (nodes) |*n|
                chains.appendAssumeCapacity(.{ .head = n, .tail = n });

            if (points.len == 0) {
                return @This(){
                    .root = null,
                    .p = null,
                    .allocator = allocator,
                    .nodes = nodes,
                };
            }

            for (0..points.len - 1) |_| {
                var min_d: ?F = null;
                var min_i: ?usize = null;
                var min_j: ?usize = null;
                var left_match_is_head: bool = true;
                var right_match_is_head: bool = true;
                for (chains.items, 0..) |*x, i| {
                    if (i + 1 >= chains.items.len)
                        continue;
                    for (chains.items[i + 1 ..], i + 1..) |*y, j| {
                        for (0..4) |k| {
                            const left_is_head = (k & 2) == 2;
                            const right_is_head = (k & 1) == 1;
                            const left = if (left_is_head) x.head else x.tail;
                            const right = if (right_is_head) y.head else y.tail;
                            const d = dist(F, left.val.*, right.val.*);
                            if (d <= (min_d orelse d)) {
                                min_d = d;
                                min_i = i;
                                min_j = j;
                                left_match_is_head = left_is_head;
                                right_match_is_head = right_is_head;
                            }
                        }
                    }
                }
                {
                    var left_chain = chains.items[min_i.?];
                    var right_chain = chains.items[min_j.?];
                    if (left_match_is_head == right_match_is_head)
                        right_chain.reverse();
                    if (left_match_is_head) {
                        const z = min_i;
                        min_i = min_j;
                        min_j = z;

                        const w = left_chain;
                        left_chain = right_chain;
                        right_chain = w;
                    }
                    left_chain.tail.next = right_chain.head;
                    _ = chains.swapRemove(min_j.?);
                }
            }

            return @This(){
                .root = chains.items[0].head.*,
                .p = chains.items[0].head.*,
                .nodes = nodes,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *const @This()) void {
            defer self.allocator.free(self.nodes);
        }
    };
}

fn score(comptime F: type, comptime I: type, iter: *I) F {
    var total: F = 0;
    var prev: ?@Vector(2, F) = null;
    while (iter.next()) |p| {
        defer prev = p;
        if (prev) |q|
            total += dist(F, p, q);
    }
    return total;
}

test {
    const allocator = std.testing.allocator;
    const F = f32;
    var _points = [_]@Vector(2, F){ .{ 0, 1 }, .{ 1, 1 }, .{ 2, 1 }, .{ 2, 0 }, .{ 1, 0 }, .{ 0, 0 } };
    var points: []@Vector(2, F) = _points[0..];

    const NN = NearestNeighbor(F);
    var nn_iter = try NN.init(allocator, points);
    defer nn_iter.deinit();
    const nn_score = score(F, NN, &nn_iter);

    const CP = ClosestPair(F);
    var cp_iter = try CP.init(allocator, points);
    defer cp_iter.deinit();
    const cp_score = score(F, CP, &cp_iter);

    _ = nn_score;
    _ = cp_score;
}
