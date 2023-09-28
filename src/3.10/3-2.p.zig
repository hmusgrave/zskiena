const std = @import("std");
const Allocator = std.mem.Allocator;

const Pattern = struct {
    word: []const u8,
    pattern: []const u8,

    pub fn init(allocator: Allocator, word: []const u8) !@This() {
        var pattern = try allocator.alloc(u8, word.len);
        var next_pattern: usize = 0;
        blk: for (0..pattern.len) |i| {
            // vulnerable to malicious inputs (slow), but real words
            // are short, so this will be faster than dedicated set
            // structures.
            for (0..i) |j| {
                if (word[j] == word[i]) {
                    pattern[i] = pattern[j];
                    continue :blk;
                }
            }
            pattern[i] = @intCast(next_pattern);
            next_pattern += 1;
        }
        return @This(){ .word = word, .pattern = pattern };
    }

    pub fn deinit(self: *const @This(), allocator: Allocator) void {
        allocator.free(self.pattern);
    }
};

test "pattern" {
    const allocator = std.testing.allocator;

    var pat = try Pattern.init(allocator, "hello, world");
    defer pat.deinit(allocator);

    try std.testing.expectEqualDeep([_]u8{ 0, 1, 2, 2, 3, 4, 5, 6, 3, 7, 2, 8 }, pat.pattern[0..12].*);
}

const Decrypt = struct {
    dictionary: []const Pattern,
    phrase: []const Pattern,
    is_original: bool,
    charmap: []?u8, // charmap[c-'a'] = decoded(c)
    parent_allocator: Allocator,
    arena: *std.heap.ArenaAllocator,
    candidates: std.StringHashMap([]Pattern),

    pub fn init(allocator: Allocator, dictionary: []const []const u8, phrase: []const []const u8) !@This() {
        var arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);

        arena.* = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        var pattern_dictionary = try arena.allocator().alloc(Pattern, dictionary.len);
        for (dictionary, pattern_dictionary) |w, *p|
            p.* = try Pattern.init(arena.allocator(), w);

        var pattern_phrase = try arena.allocator().alloc(Pattern, phrase.len);
        for (phrase, pattern_phrase) |w, *p|
            p.* = try Pattern.init(arena.allocator(), w);

        var dict = std.StringHashMap([]Pattern).init(arena.allocator());
        for (pattern_phrase) |pat| {
            // dictionary key
            const pattern = pat.pattern;
            if (dict.contains(pattern))
                continue;
            var cnt: usize = 0;
            for (pattern_dictionary) |pd|
                cnt += @intFromBool(std.mem.eql(u8, pd.pattern, pattern));
            var result_buffer = try arena.allocator().alloc(Pattern, cnt);
            var i: usize = 0;
            for (pattern_dictionary) |pd| {
                if (!std.mem.eql(u8, pd.pattern, pattern))
                    continue;
                result_buffer[i] = pd;
                i += 1;
            }
            try dict.put(pattern, result_buffer);
        }

        var charmap = try arena.allocator().alloc(?u8, 26);
        for (charmap) |*c|
            c.* = null;

        return @This(){
            .dictionary = pattern_dictionary,
            .phrase = pattern_phrase,
            .is_original = true,
            .charmap = charmap,
            .parent_allocator = allocator,
            .arena = arena,
            .candidates = dict,
        };
    }

    pub fn deinit(self: *const @This()) void {
        self.arena.allocator().free(self.charmap);
        if (self.is_original) {
            self.arena.deinit();
            self.parent_allocator.destroy(self.arena);
        }
    }

    fn clone(self: *const @This()) !@This() {
        var charmap = try self.arena.allocator().alloc(?u8, self.charmap.len);
        for (self.charmap, charmap) |a, *c|
            c.* = a;
        return @This(){
            .dictionary = self.dictionary,
            .phrase = self.phrase,
            .is_original = false,
            .charmap = charmap,
            .parent_allocator = self.parent_allocator,
            .arena = self.arena,
            .candidates = self.candidates,
        };
    }

    const Sln = @This();
    const Iter = struct {
        orig: Sln,
        cur: ?Sln,
        candidates: []Pattern,
        word: Pattern,
        next_i: usize,

        pub fn next(self: *@This()) !?Sln {
            while (true) {
                if (self.next_i >= self.candidates.len)
                    return null;
                defer self.next_i += 1;
                const cand = self.candidates[self.next_i];
                for (cand.word, self.word.word) |a, b| {
                    if (a != (self.orig.decode(b) orelse a))
                        break;
                }
                var sln = try self.orig.clone();
                for (cand.word, self.word.word) |a, b|
                    sln.charmap[b - 'a'] = a;
                if (self.cur) |*sc|
                    sc.deinit();
                self.cur = sln;
                return sln;
            }
        }

        pub inline fn split(self: *const @This()) ?@This() {
            var sln = self.cur orelse return null;
            return sln.split();
        }

        pub inline fn is_done(self: *const @This()) bool {
            var sln = self.cur orelse return false;
            return sln.is_done();
        }

        pub inline fn deinit(self: *const @This()) void {
            if (self.cur) |*sc|
                sc.deinit();
        }
    };

    fn decode_unsafe(self: *const @This()) ![]u8 {
        var size: usize = @max(1, self.phrase.len) - 1;
        for (self.phrase) |phr|
            size += phr.word.len;
        var rtn = try self.parent_allocator.alloc(u8, size);
        if (size == 0)
            return rtn;
        for (self.phrase[0].word, 0..) |c, i|
            rtn[i] = self.decode(c).?;
        size = self.phrase[0].word.len;
        for (self.phrase[1..]) |phr| {
            rtn[size] = ' ';
            size += 1;
            for (phr.word, 0..) |c, i|
                rtn[size + i] = self.decode(c).?;
            size += phr.word.len;
        }
        return rtn;
    }

    pub fn solve(self: *const @This()) ![]const u8 {
        if (self.is_done())
            return try self.decode_unsafe();

        var stack = std.ArrayList(Iter).init(self.parent_allocator);
        defer stack.deinit();

        // if it's not done and we can't progress the problem, there is
        // no solution
        try stack.append(self.split() orelse return error.NoSolution);

        defer {
            for (stack.items) |*si|
                si.deinit();
        }

        while (true) {
            if (stack.items.len == 0)
                return error.NoSolution;

            var last = &stack.items[stack.items.len - 1];

            if (last.is_done())
                return try last.cur.?.decode_unsafe();

            if (last.split()) |iter| {
                // depth-first
                try stack.append(iter);
            } else if (try last.next()) |_| {
                // next loop iteration will check if this is finished
                continue;
            } else {
                // current attempt isn't done and can't proceed
                // forward, so abandon it
                _ = stack.pop();
            }
        }
    }

    fn split(self: *const @This()) ?Iter {
        var min_match: usize = self.dictionary.len + 1;
        var match_i: usize = 0;
        for (self.phrase, 0..) |phr, i| {
            var cnt = self.match_count_for_split(phr) orelse return null;
            if (0 < cnt and cnt < min_match) {
                min_match = cnt;
                match_i = i;
            }
        }

        if (min_match > self.dictionary.len)
            return null;

        const match_phrase = self.phrase[match_i];

        return Iter{
            .orig = self.*,
            .cur = null,
            .candidates = self.candidates.get(match_phrase.pattern).?,
            .word = match_phrase,
            .next_i = 0,
        };
    }

    inline fn decode(self: *const @This(), c: u8) ?u8 {
        return self.charmap[c - 'a'];
    }

    // return null if the word is broken in the current decode table
    fn match_count_for_split(self: *const @This(), phrase_word: Pattern) ?usize {
        var options = self.candidates.get(phrase_word.pattern).?;
        var rtn: usize = 0;
        var any_matches: usize = 0;
        blk: for (options) |pat| {
            for (pat.word, phrase_word.word) |a, b| {
                if (a != (self.decode(b) orelse a))
                    // all possible decodings will not be in the
                    // dictionary, so try another option
                    continue :blk;
            }
            any_matches += 1;
            // found at least one match, check to see if
            // it was previously fully resolved
            for (phrase_word.word) |c| {
                if (self.decode(c) == null) {
                    // still work to do, time to check other
                    // possible matches
                    rtn += 1;
                    continue :blk;
                }
            }
        }
        return if (any_matches > 0) rtn else null;
    }

    fn is_done(self: *const @This()) bool {
        // assumes the current decode table is valid
        for (self.phrase) |phr| {
            for (phr.word) |c|
                _ = self.decode(c) orelse return false;
        }
        return true;
    }
};

test "solution" {
    var dict_raw = "and dick jane puff spot yertle";
    var dict: [6][]const u8 = undefined;
    {
        var iter = std.mem.tokenizeAny(u8, dict_raw, " ");
        var i: usize = 0;
        while (iter.next()) |word| : (i += 1)
            dict[i] = word;
    }

    var phrase_raw = "bjvg xsb hxsn xsb qymm xsb rqat xsb pnetfn";
    var phrase: [9][]const u8 = undefined;
    {
        var iter = std.mem.tokenizeAny(u8, phrase_raw, " ");
        var i: usize = 0;
        while (iter.next()) |word| : (i += 1)
            phrase[i] = word;
    }

    var dec = try Decrypt.init(std.testing.allocator, &dict, &phrase);
    defer dec.deinit();

    var sln = try dec.solve();
    defer std.testing.allocator.free(sln);
    try std.testing.expect(std.mem.eql(u8, sln, "dick and jane and puff and spot and yertle"));
}
