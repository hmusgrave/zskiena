const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Node(comptime F: type) type {
    return struct {
        val: F,
        left: ?*@This(),
        right: ?*@This(),
        parent: ?*@This(),
    };
}

// list semantics, not set
pub fn Tree(comptime F: type) type {
    return struct {
        root: ?*Node(F),
        raw_allocator: Allocator,
        raw_arena: *std.heap.ArenaAllocator,
        arena: Allocator,
        bin_count: usize,

        pub fn init(allocator: Allocator) !@This() {
            var arena = try allocator.create(std.heap.ArenaAllocator);
            arena.* = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            return @This(){ .root = null, .raw_allocator = allocator, .raw_arena = arena, .arena = arena.allocator(), .bin_count = 0 };
        }

        fn walk(self: *const @This(), _node: ?*Node(F)) void {
            var node = _node orelse return;
            self.walk(node.left);
            std.debug.print("{}\n", .{node.val});
            self.walk(node.right);
        }

        pub fn deinit(self: *const @This()) void {
            defer self.raw_allocator.destroy(self.raw_arena);
            defer self.raw_arena.deinit();
        }

        // returns any greatest node not exceeding val
        fn greatest_lower_bound(self: *@This(), val: F) ?*Node(F) {
            var parent = self.root orelse return null;
            while (true) {
                if (parent.val > val) {
                    parent = parent.left orelse return null;
                } else if (parent.right) |right| {
                    if (right.val <= val) {
                        parent = right;
                    } else {
                        // right node isn't the return value, but
                        // one of its left descendants _might_ be

                        // the property we're going to maintain
                        // to preserve our sanity is that ub.val > val
                        //
                        // whenever that's not the case we've broken out of
                        // one loop or another
                        var ub = right;
                        while (true) {
                            if (ub.left) |left| {
                                if (left.val > val) {
                                    ub = left;
                                } else if (left.val == val) {
                                    return left;
                                } else {
                                    parent = left;
                                    break;
                                }
                            } else {
                                return parent;
                            }
                        }
                    }
                } else {
                    return parent;
                }
            }
        }

        // part 1
        pub fn insert_biggest(self: *@This(), val: F) !void {
            if (self.greatest_lower_bound(1 - val)) |glb| {
                self.remove_node(glb);
                glb.val += val;
                self.insert_node(glb);
            } else {
                var node = try self.arena.create(Node(F));
                node.* = .{ .val = val, .left = null, .right = null, .parent = null };
                self.bin_count += 1;
                self.insert_node(node);
            }
        }

        // returns any least node not exceeding val
        fn least_upper_bound(self: *@This(), val: F) ?*Node(F) {
            var parent = self.root orelse return null;
            while (parent.left) |left|
                parent = left;
            return if (parent.val <= val) parent else null;
        }

        // part 2
        pub fn insert_smallest(self: *@This(), val: F) !void {
            if (self.least_upper_bound(1 - val)) |lub| {
                self.remove_node(lub);
                lub.val += val;
                self.insert_node(lub);
            } else {
                var node = try self.arena.create(Node(F));
                node.* = .{ .val = val, .left = null, .right = null, .parent = null };
                self.bin_count += 1;
                self.insert_node(node);
            }
        }

        fn insert_node(self: *@This(), node: *Node(F)) void {
            node.left = null;
            node.right = null;

            var parent = self.root orelse {
                self.root = node;
                node.parent = null;
                return;
            };

            while (true) {
                var branch: *?*Node(F) = if (parent.val <= node.val) &parent.right else &parent.left;
                parent = branch.* orelse {
                    branch.* = node;
                    node.parent = parent;
                    return;
                };
            }
        }

        fn remove_node(self: *@This(), node: *Node(F)) void {
            var repl: ?*Node(F) = if (self.successor(node)) |rep| blk: {
                var rep_parent = rep.parent.?;
                if (node.parent) |grandfather| {
                    var branch: *?*Node(F) = if (grandfather.right == node) &grandfather.right else &grandfather.left;
                    branch.* = rep;
                }
                rep.parent = node.parent;

                if (node.left) |left|
                    left.parent = rep;
                rep.left = node.left;

                if (rep_parent == node)
                    break :blk rep;

                rep_parent.left = rep.right;
                if (rep.right) |rep_right|
                    rep_right.parent = rep_parent;

                rep.right = node.right;
                if (node.right) |node_right|
                    node_right.parent = rep;

                break :blk rep;
            } else blk: {
                var parent = node.parent orelse {
                    if (node.left) |left| {
                        left.parent = null;
                        break :blk left;
                    }
                    break :blk null;
                };
                var branch: *?*Node(F) = if (parent.right == node) &parent.right else &parent.left;
                branch.* = node.left;
                if (node.left) |left|
                    left.parent = parent;
                break :blk node.left;
            };

            if (node == self.root)
                self.root = repl;
        }

        fn successor(self: *const @This(), node: *Node(F)) ?*Node(F) {
            _ = self;
            var parent = node.right orelse return null;
            while (parent.left) |left|
                parent = left;
            return parent;
        }
    };
}

test "part 1" {
    var tree = try Tree(f32).init(std.testing.allocator);
    defer tree.deinit();

    try tree.insert_biggest(0.4);
    try std.testing.expectEqual(@as(usize, 1), tree.bin_count);

    try tree.insert_biggest(0.3);
    try std.testing.expectEqual(@as(usize, 1), tree.bin_count);

    try tree.insert_biggest(0.8);
    try std.testing.expectEqual(@as(usize, 2), tree.bin_count);

    try tree.insert_biggest(0.15);
    try std.testing.expectEqual(@as(usize, 2), tree.bin_count);

    try tree.insert_biggest(0.15);
    try std.testing.expectEqual(@as(usize, 2), tree.bin_count);

    try tree.insert_biggest(0.15);
    try std.testing.expectEqual(@as(usize, 2), tree.bin_count);

    try tree.insert_biggest(0.15);
    try std.testing.expectEqual(@as(usize, 3), tree.bin_count);
}

test "part 2" {
    var tree = try Tree(f32).init(std.testing.allocator);
    defer tree.deinit();

    try tree.insert_smallest(0.4);
    try std.testing.expectEqual(@as(usize, 1), tree.bin_count);

    try tree.insert_smallest(0.3);
    try std.testing.expectEqual(@as(usize, 1), tree.bin_count);

    try tree.insert_smallest(0.8);
    try std.testing.expectEqual(@as(usize, 2), tree.bin_count);

    try tree.insert_smallest(0.15);
    try std.testing.expectEqual(@as(usize, 2), tree.bin_count);

    try tree.insert_smallest(0.15);
    try std.testing.expectEqual(@as(usize, 2), tree.bin_count);

    try tree.insert_smallest(0.15);
    try std.testing.expectEqual(@as(usize, 2), tree.bin_count);

    try tree.insert_smallest(0.15);
    try std.testing.expectEqual(@as(usize, 3), tree.bin_count);
}
