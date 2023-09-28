const std = @import("std");

const Node = struct {
    key: usize,
    left: ?*@This(),
    right: ?*@This(),
    parent: ?*@This(),
};

pub fn merge(_left: ?*Node, _right: ?*Node) ?*Node {
    var left = _left orelse return _right;
    var right = _right orelse return _left;

    if (left.right) |x| {
        var max = x;
        while (max.right != null)
            max = max.right.?;
        max.parent.?.right = null;
        max.parent = null;
        max.left = left;
        left.parent = max;
        max.right = right;
        right.parent = max;
        return max;
    } else {
        left.right = right;
        return left;
    }
}

test {
    var a: Node = .{ .key = 3, .left = null, .right = null, .parent = null };
    var b: Node = .{ .key = 5, .left = null, .right = null, .parent = null };
    var c: Node = .{ .key = 7, .left = null, .right = null, .parent = null };
    var d: Node = .{ .key = 9, .left = null, .right = null, .parent = null };
    var e: Node = .{ .key = 14, .left = null, .right = null, .parent = null };

    var left = b;
    left.left = &a;
    left.right = &c;
    a.parent = &left;
    c.parent = &left;

    var right = d;
    right.right = &e;
    e.parent = &d;

    var full = merge(&left, &right).?;
    try std.testing.expectEqual(@as(usize, 7), full.key);
    try std.testing.expectEqual(@as(usize, 5), full.left.?.key);
    try std.testing.expectEqual(@as(usize, 3), full.left.?.left.?.key);
    try std.testing.expectEqual(@as(usize, 9), full.right.?.key);
    try std.testing.expectEqual(@as(usize, 14), full.right.?.right.?.key);
}
