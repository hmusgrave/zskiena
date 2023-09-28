const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Set(comptime U: type) type {
    const Node = struct {
        val: U,
        parent: ?*@This(),
        left: ?*@This(),
        right: ?*@This(),
        descendants: usize,
    };

    return struct {
        root: ?*Node,
        allocator: Allocator,

        pub fn init(allocator: Allocator) @This() {
            return .{ .root = null, .allocator = allocator };
        }

        pub fn deinit(self: *const @This()) void {
            self._deinit_tree(self.root);
        }

        fn _deinit_tree(self: *const @This(), _node: ?*Node) void {
            if (_node) |node| {
                self._deinit_tree(node.left);
                self._deinit_tree(node.right);
                self.allocator.destroy(node);
            }
        }

        pub fn insert(self: *@This(), x: U) !void {
            if (self.member(x))
                return;

            var node = try self.allocator.create(Node);
            errdefer self.allocator.destroy(node);
            node.* = .{ .val = x, .parent = null, .left = null, .right = null, .descendants = 0 };

            if (self.root) |root| {
                var parent = root;
                while (true) {
                    parent.descendants += 1;
                    var next: *?*Node = if (parent.val < x) &parent.right else &parent.left;
                    if (next.*) |node_ptr| {
                        parent = node_ptr;
                    } else {
                        node.parent = parent;
                        next.* = node;
                        return;
                    }
                }
            } else {
                self.root = node;
            }
        }

        fn delete_node(self: *@This(), node: *Node) void {
            defer self.allocator.destroy(node);

            var successor = blk: {
                var right = node.right orelse {
                    if (self.root == node) {
                        self.root = node.left;
                        if (node.left) |left|
                            left.parent = null;
                    } else {
                        node.parent.?.right = node.left;
                        if (node.left) |left|
                            left.parent = node.parent;
                    }
                    return;
                };
                var cur = right;
                while (true) {
                    if (cur.left) |left| {
                        cur = left;
                    } else {
                        break :blk cur;
                    }
                }
            };

            if (self.root == node) {
                if (node.right == successor) {
                    self.root = successor;
                    successor.parent = null;
                    successor.left = node.left;
                    if (node.left) |left|
                        left.parent = successor;
                } else {
                    successor.parent.?.left = successor.right;
                    if (successor.right) |sr|
                        sr.parent = successor.parent;
                    successor.right = node.right;
                    node.right.?.parent = successor;
                    successor.parent = null;
                    successor.left = node.left;
                    if (node.left) |left|
                        left.parent = successor;
                }
            } else {
                if (node.right == successor) {
                    successor.parent = node.parent;
                    var branch = if (node.parent.?.right == node) &node.parent.?.right else &node.parent.?.left;
                    branch.* = successor;
                    successor.left = node.left;
                    if (node.left) |left|
                        left.parent = successor;
                } else {
                    successor.parent.?.left = successor.right;
                    if (successor.right) |sr|
                        sr.parent = successor.parent;
                    successor.parent = node.parent;
                    var branch = if (node.parent.?.right == node) &node.parent.?.right else &node.parent.?.left;
                    branch.* = successor;
                    successor.left = node.left;
                    if (node.left) |left|
                        left.parent = successor;
                    successor.right = node.right;
                    node.right.?.parent = successor;
                }
            }
        }

        pub fn delete_at(self: *@This(), _k: usize) !void {
            var k = _k;
            if (k < 1)
                return error.Invalid;
            var parent = self.root orelse return;
            while (true) {
                if (parent.left) |left| {
                    const left_count = 1 + left.descendants;
                    if (left_count >= k) {
                        parent = left;
                    } else if (left_count + 1 == k) {
                        self.delete_node(parent);
                        return;
                    } else {
                        k -= left_count + 1;
                        parent = parent.right orelse return;
                    }
                } else if (k == 1) {
                    self.delete_node(parent);
                    return;
                } else if (parent.right) |right| {
                    k -= 1;
                    parent = right;
                } else {
                    return;
                }
            }
        }

        pub fn member(self: *const @This(), x: U) bool {
            if (self.root) |root| {
                var parent = root;
                while (true) {
                    if (parent.val == x)
                        return true;
                    var next: *?*Node = if (parent.val < x) &parent.right else &parent.left;
                    if (next.*) |node_ptr| {
                        parent = node_ptr;
                    } else {
                        return false;
                    }
                }
            } else {
                return false;
            }
        }
    };
}

test {
    var set = Set(u8).init(std.testing.allocator);
    defer set.deinit();

    try set.insert(2);
    try std.testing.expect(set.member(2));

    try set.insert(3);
    try std.testing.expect(set.member(2));
    try std.testing.expect(set.member(3));

    try set.delete_at(1);
    try std.testing.expect(set.member(3));
    try std.testing.expect(!set.member(2));

    try set.insert(1);
    try std.testing.expect(set.member(3));
    try std.testing.expect(!set.member(2));
    try std.testing.expect(set.member(1));

    try set.delete_at(2);
    try std.testing.expect(!set.member(3));
    try std.testing.expect(!set.member(2));
    try std.testing.expect(set.member(1));
}
