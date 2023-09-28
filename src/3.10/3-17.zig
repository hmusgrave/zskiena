const std = @import("std");
const Allocator = std.mem.Allocator;

const sample_text = @embedFile("3-17.txt");
const stats = blk: {
    @setEvalBranchQuota(1000000);
    comptime var counts = [_]usize{0} ** 26;
    comptime var t: usize = 0;
    for (sample_text[0..10000]) |c| {
        if (c >= 'a' and c <= 'z') {
            counts[c - 'a'] += 1;
            t += 1;
        }
    }

    comptime var _stats: [26]f32 = undefined;
    for (0..26) |i| {
        const numerator: f32 = @floatFromInt(counts[i]);
        const denominator: f32 = @floatFromInt(t);
        _stats[i] = numerator / denominator;
    }
    break :blk _stats;
};

// result is smallest when shifting letters c->c+shift
// best aligns with english frequency
fn cmp(freqs: [26]f32, shift: usize) f32 {
    var rtn: f32 = 0;
    for (0..26) |i| {
        var diff = freqs[(i + shift) % 26] - stats[i];
        rtn += diff * diff;
    }
    return rtn;
}

fn best_shift(freqs: [26]f32) u8 {
    var min: f32 = cmp(freqs, 0);
    var min_i: usize = 0;
    for (1..26) |i| {
        const z = cmp(freqs, i);
        if (z < min) {
            min = z;
            min_i = i;
        }
    }
    return @intCast(26 - min_i);
}

fn signature(text: []const u8) [26]f32 {
    var counts = [_]usize{0} ** 26;
    var t: usize = 0;
    for (text) |c| {
        if (c >= 'a' and c <= 'z') {
            counts[c - 'a'] += 1;
            t += 1;
        }
    }

    var rtn: [26]f32 = undefined;
    for (rtn[0..], counts) |*r, c| {
        const num: f32 = @floatFromInt(c);
        const den: f32 = @floatFromInt(t);
        r.* = if (den > 0) num / den else 0;
    }
    return rtn;
}

pub fn caesar_decode(allocator: Allocator, text: []const u8) ![]u8 {
    const sig = signature(text);
    const shift = best_shift(sig);
    return try caesar_scramble(allocator, text, shift);
}

pub fn caesar_scramble(allocator: Allocator, text: []const u8, _shift: i16) ![]u8 {
    var shift: u8 = @intCast(if (_shift < 0) 26 + _shift else _shift);
    var rtn = try allocator.alloc(u8, text.len);
    errdefer allocator.free(rtn);
    if (text.len == 0)
        return rtn;
    for (text, rtn) |c, *t| {
        if (c >= 'a' and c <= 'z') {
            t.* = 'a' + (((c + shift) - 'a') % 26);
        } else if (c >= 'A' and c <= 'Z') {
            t.* = 'A' + (((c + shift) - 'A') % 26);
        } else {
            t.* = c;
        }
    }
    return rtn;
}

test {
    const allocator = std.testing.allocator;

    const message = "Hello, World!";
    var scrambled = try caesar_scramble(allocator, message, 8);
    defer allocator.free(scrambled);

    var decoded = try caesar_decode(allocator, scrambled);
    defer allocator.free(decoded);

    try std.testing.expect(std.mem.eql(u8, message, decoded));
}
