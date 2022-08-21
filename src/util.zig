// MIT License
//
// Copyright (c) 2022 Arthur Lapz (rLapz)
//
// See LICENSE file for license details

const std = @import("std");

pub fn skipHtmlTags(dest: []u8, src: []const u8) []const u8 {
    const Table = struct { tags: [2][]const u8 };

    const tables = [_]Table{
        .{ .tags = .{ "<b>", "</b>" } },
        // Add other tags below
    };

    var ret = dest;
    for (tables) |*v| {
        const tag0 = v.tags[0];
        const tag1 = v.tags[1];

        const op = std.mem.replace(u8, src, tag0, "", dest);
        ret = dest[0 .. src.len - (op * tag0.len)];

        const cl = std.mem.replace(u8, ret, tag1, "", ret);
        ret = dest[0 .. ret.len - (cl * tag1.len)];
    }

    return ret;
}
