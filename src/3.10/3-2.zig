const std = @import("std");

pub fn Node(comptime T: type) type {
    return struct {
        val: T,
        next: ?*@This(),
    };
}

pub fn LinkedList(comptime T: type) type {
    return struct {
        root: ?*Node(T),

        pub const Iter = struct {
            node: ?*const Node(T),

            pub fn next(self: *@This()) ?T {
                var node = self.node orelse return null;
                defer self.node = node.next;
                return node.val;
            }
        };

        pub fn reverse(self: *@This()) void {
            var parent = self.root orelse return;
            var child = parent.next;
            while (child != null) {
                var next_child = child.?.next;
                child.?.next = parent;
                parent = child.?;
                child = next_child;
            }
            self.root.?.next = null;
            self.root = parent;
        }

        pub fn iter(self: *const @This()) Iter {
            return .{ .node = self.root };
        }
    };
}

test {
    const N = Node(usize);
    var c = N{ .val = 2, .next = null };
    var b = N{ .val = 1, .next = &c };
    var a = N{ .val = 0, .next = &b };
    var list = LinkedList(usize){ .root = &a };

    var i: usize = 0;
    var iter = list.iter();
    while (iter.next()) |val| : (i += 1)
        try std.testing.expectEqual(i, val);

    list.reverse();
    i = 2;
    iter = list.iter();
    while (iter.next()) |val| : (i -%= 1)
        try std.testing.expectEqual(i, val);
}
