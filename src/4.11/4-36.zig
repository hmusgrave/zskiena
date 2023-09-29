const std = @import("std");

fn isqrt(n: usize) usize {
    var x = n;
    var y = (x + 1) >> 1;
    while (y < x) {
        x = y;
        y = (x + (n / x)) >> 1;
    }
    return x;
}

pub fn Box(comptime T: type) type {
    return struct {
        // raw data (n x n matrix, n>0)
        mat: []T,
        n: usize,

        // upper-left corner (inclusive)
        i: usize,
        j: usize,

        // size
        h: usize,
        w: usize,

        const B = @This();

        const BoxPoint = struct {
            i: usize,
            j: usize,
            pub inline fn to_mat(self: @This(), box: *const B) MatPoint {
                return .{
                    .i = box.i + self.i,
                    .j = box.j + self.j,
                };
            }
        };

        const MatPoint = struct {
            i: usize,
            j: usize,
            pub inline fn flatten(self: @This(), box: *const B) usize {
                return self.i * box.n + self.j;
            }
        };

        const Diag = struct {
            key: usize,

            pub inline fn box_coords(self: @This(), box: *const B) BoxPoint {
                return .{
                    .i = box.h -| (self.key + 1),
                    .j = self.key,
                };
            }
        };

        pub fn count_zeros(mat: []T) !usize {
            const n = isqrt(mat.len);
            if (n < 1)
                return 0;
            if (n * n != mat.len)
                return error.NotSquare;
            var box = @This(){ .mat = mat, .n = n, .i = 0, .j = 0, .h = n, .w = n };
            return box.search();
        }

        fn search(self: *const @This()) usize {
            if (self.h == 0 or self.w == 0)
                return 0;
            var a = Diag{ .key = 0 };
            var b = Diag{ .key = @min(self.h, self.w) - 1 };

            var count: usize = 0;
            while (a.key != b.key) {
                const mid = Diag{ .key = (a.key >> 1) + (b.key >> 1) + (a.key & b.key & 1) };
                const p: MatPoint = mid.box_coords(self).to_mat(self);
                const x = self.mat[p.flatten(self)];

                if (x == 0) {
                    a = mid;
                    b = mid;
                } else if (x < 0) {
                    a = Diag{ .key = @min(mid.key + 1, b.key) };
                } else {
                    b = Diag{ .key = @max(mid.key -| 1, a.key) };
                }
            }

            {
                const p: MatPoint = a.box_coords(self).to_mat(self);
                const x = self.mat[p.flatten(self)];

                count += @intFromBool(x == 0);

                var desc: @This() = self.*;
                desc.delete_above(p.i + @intFromBool(x >= 0));
                desc.delete_left(p.j + @intFromBool(x <= 0));
                count += desc.search();

                desc = self.*;
                desc.delete_below_inclusive(p.i + @intFromBool(x > 0));
                desc.delete_right_inclusive(p.j + @intFromBool(x < 0));
                count += desc.search();

                return count;
            }
        }

        fn fix_bounds(self: *@This()) void {
            const ip = intersect_intervals(self.n, self.i, self.h);
            const jp = intersect_intervals(self.n, self.j, self.w);

            if (ip[1] == 0 or jp[1] == 0) {
                self.i = 0;
                self.j = 0;
                self.h = 0;
                self.w = 0;
            } else {
                self.i = ip[0];
                self.h = ip[1];
                self.j = jp[0];
                self.w = jp[1];
            }
        }

        inline fn intersect_intervals(n: usize, i: usize, d: usize) [2]usize {
            // The matrix spans the interval [0,n)
            //   = [0,n-1] since n>0
            // The row spans the interval [i,i+d)
            if (i >= n)
                return .{ 0, 0 };
            return .{ i, @min(n, i + d) -| i };
        }

        fn delete_above(self: *@This(), i: usize) void {
            if (i <= self.i)
                return;
            self.h -|= i - self.i;
            self.i = i;
            self.fix_bounds();
        }

        fn delete_below_inclusive(self: *@This(), i: usize) void {
            const ui = @min(self.i + self.h -| 1, i);
            self.h = ui -| self.i;
            self.fix_bounds();
        }

        fn delete_left(self: *@This(), j: usize) void {
            if (j <= self.j)
                return;
            self.w -|= j - self.j;
            self.j = j;
            self.fix_bounds();
        }

        fn delete_right_inclusive(self: *@This(), j: usize) void {
            const uj = @min(self.j + self.w -| 1, j);
            self.w = uj -| self.j;
            self.fix_bounds();
        }
    };
}

test {
    var mat = [_]i32{ 1, 2, 3, 4, -5, 0, 1, 2, -12, -8, 0, 1, -500, -50, -15, -9 };
    try std.testing.expectEqual(@as(usize, 2), try Box(i32).count_zeros(&mat));
}
