const std = @import("std");

fn partition(comptime T: type, lt: anytype, data: []T, p: usize) usize {
    const pivot = data[p];
    if (p != data.len - 1)
        std.mem.swap(T, &data[p], &data[data.len - 1]);
    var store_idx: usize = 0;
    for (0..data.len) |i| {
        if (lt(data[i], pivot)) {
            std.mem.swap(T, &data[i], &data[store_idx]);
            store_idx += 1;
        }
    }
    std.mem.swap(T, &data[data.len - 1], &data[store_idx]);
    return store_idx;
}

test "partition" {
    for (0..5) |i| {
        var data = [_]usize{ 5, 6, 8, 1, 2 };
        const el = data[i];
        var small: usize = 0;
        for (data) |x|
            small += @intFromBool(x < el);
        const z = partition(usize, prim_lt, &data, i);
        try std.testing.expectEqual(small, z);
        try std.testing.expectEqual(el, data[small]);
    }
}

fn select(comptime T: type, lt: anytype, data: []T, k: usize) T {
    if (data.len == 1)
        return data[0];
    var pivot_idx = data.len >> 1; // TODO
    pivot_idx = partition(T, lt, data, pivot_idx);
    if (k == pivot_idx) {
        return data[k];
    } else if (k < pivot_idx) {
        return select(T, lt, data[0..pivot_idx], k);
    } else {
        return select(T, lt, data[pivot_idx + 1 ..], k - (pivot_idx + 1));
    }
}

fn prim_lt(a: anytype, b: anytype) bool {
    return a < b;
}

test "quick select" {
    var data = [_]usize{ 5, 6, 8, 1, 2 };
    const sorted = [_]usize{ 1, 2, 5, 6, 8 };
    for (0..5) |i| {
        const z = select(usize, prim_lt, &data, i);
        try std.testing.expectEqual(sorted[i], z);
    }
}

fn any_median(comptime T: type, lt: anytype, data: []T) ?T {
    if (data.len < 1)
        return null;
    return select(T, lt, data, data.len >> 1);
}

test "any_median" {
    {
        var data = [_]usize{ 3, 1, 2 };
        const z = any_median(usize, prim_lt, &data);
        try std.testing.expectEqual(@as(?usize, 2), z);
    }
    {
        var data = [_]usize{ 6, 0, 4, 7 };
        const z = any_median(usize, prim_lt, &data);
        try std.testing.expect(z == 4 or z == 6); // z==4 as an implementation detail
    }
    {
        var data = [_]usize{1};
        const z = any_median(usize, prim_lt, &data);
        try std.testing.expectEqual(@as(?usize, 1), z);
    }
}

fn least_house_dist(street_numbers: []usize) usize {
    const middle = any_median(usize, prim_lt, street_numbers) orelse return 0;
    var dist: usize = 0;
    for (street_numbers) |n|
        dist += if (n > middle) n - middle else middle - n;
    return dist;
}

test "houses" {
    {
        var data = [_]usize{ 2, 4 };
        try std.testing.expectEqual(@as(usize, 2), least_house_dist(&data));
    }
    {
        var data = [_]usize{ 2, 4, 6 };
        try std.testing.expectEqual(@as(usize, 4), least_house_dist(&data));
    }
}
