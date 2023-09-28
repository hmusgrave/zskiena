const std = @import("std");
const Allocator = std.mem.Allocator;

const sentinel = "the quick brown fox jumps over the lazy dog";

fn same_pattern(a: []const u8) bool {
    const b: []const u8 = sentinel;
    var i: usize = 0;
    if (a.len != b.len)
        return false;
    var raw_buf: [sentinel.len]usize = undefined;
    var buf: []usize = &raw_buf;
    blk: for (0..a.len) |j| {
        for (buf[0..j]) |k| {
            if ((a[k] == a[j]) != (b[k] == b[j]))
                return false;
            if (a[k] == a[j]) {
                buf[j] = buf[k];
                continue :blk;
            }
        }
        buf[j] = i;
        i += 1;
    }
    return true;
}

fn lookup_table_unsafe(phrase: []const u8) [26]u8 {
    var rtn: [26]u8 = undefined;
    for (phrase, sentinel[0..]) |in_c, out_c| {
        if ('a' <= in_c and in_c <= 'z')
            rtn[in_c - 'a'] = out_c;
    }
    return rtn;
}

pub fn crypt_kicker(messages: []const []const u8, out: [][]u8) !void {
    const table = blk: {
        for (messages) |msg| {
            if (same_pattern(msg))
                break :blk lookup_table_unsafe(msg);
        }
        return error.NoPlainText;
    };
    for (messages, out) |in_msg, out_msg| {
        for (in_msg, out_msg) |in_c, *out_c|
            out_c.* = if ('a' <= in_c and in_c <= 'z') table[in_c - 'a'] else in_c;
    }
}

test {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const lines = [_][]const u8{
        "vtz ud xnm xugm itr pyy jttk gmv xt otgm xt xnm puk ti xnm fprxq",
        "xnm ceuob lrtzv ita hegfd tsmr xnm ypwq ktj",
        "frtjrpgguvj otvxmdxd prm iev prmvx xnmq",
    };

    const expected = [_][]const u8{
        "now is the time for all good men to come to the aid of the party",
        "the quick brown fox jumps over the lazy dog",
        "programming contests are fun arent they",
    };

    var out = try arena.allocator().alloc([]u8, lines.len);
    for (out, lines) |*p, line|
        p.* = try arena.allocator().alloc(u8, line.len);

    try crypt_kicker(&lines, out);
    for (expected, out) |ex_line, act_line|
        try std.testing.expect(std.mem.eql(u8, ex_line, act_line));
}
