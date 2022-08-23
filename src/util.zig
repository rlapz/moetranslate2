const std = @import("std");

pub fn skipHtmlTags(dest: []u8, src: []const u8) []const u8 {
    const tables = [_][2][]const u8{
        .{ "<b>", "</b>" },
        // Add other tags below
    };

    var _src = src;
    var ret = dest;
    for (tables) |*tag| {
        const op = std.mem.replace(u8, _src, tag[0], "", dest);
        ret = dest[0 .. _src.len - (op * tag[0].len)];

        const cl = std.mem.replace(u8, ret, tag[1], "", ret);
        ret = dest[0 .. ret.len - (cl * tag[1].len)];
        _src = ret;
    }

    return ret;
}
