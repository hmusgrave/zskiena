const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Dictionary(comptime V: type) type {
    return struct {
        present: []bool,
        data: []V,
        allocator: Allocator,

        pub fn init(allocator: Allocator, n: usize) !@This() {
            var data = try allocator.alloc(V, n);
            errdefer allocator.free(data);

            var present = try allocator.alloc(bool, n);
            errdefer allocator.free(present);

            for (present) |*p|
                p.* = false;

            return @This(){
                .present = present,
                .data = data,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *const @This()) void {
            defer self.allocator.free(self.data);
            defer self.allocator.free(self.present);
        }

        pub fn search(self: *const @This(), key: usize) ?*V {
            if (self.present[key - 1])
                return &self.data[key - 1];
            return null;
        }

        pub fn insert(self: *const @This(), key: usize, val: V) void {
            self.present[key - 1] = true;
            self.data[key - 1] = val;
        }

        pub fn delete(self: *const @This(), key: usize) void {
            self.present[key - 1] = false;
        }
    };
}

test {
    var dict = try Dictionary(f32).init(std.testing.allocator, 42);
    defer dict.deinit();

    dict.insert(1, 4.5);
    try std.testing.expectEqual(@as(f32, 4.5), dict.search(1).?.*);

    dict.insert(2, 3.14);
    try std.testing.expectEqual(@as(f32, 3.14), dict.search(2).?.*);

    dict.insert(5, 89);
    try std.testing.expectEqual(@as(f32, 89), dict.search(5).?.*);

    dict.insert(1, 3);
    try std.testing.expectEqual(@as(f32, 3), dict.search(1).?.*);

    dict.delete(5);
    try std.testing.expectEqual(@as(?*f32, null), dict.search(5));
}
