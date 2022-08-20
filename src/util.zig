// MIT License
//
// Copyright (c) 2022 Arthur Lapz (rLapz)
//
// See LICENSE file for license details

const std = @import("std");

pub fn skipHtmlTags(str: []u8) []const u8 {
    const Table = struct { tags: [2][]const u8 };

    const tables = [_]Table{
        .{ .tags = .{ "<b>", "</b>" } },
        // Add other tags below
    };

    var len = str.len;

    for (tables) |*v| {
        var tclose: usize = 0;
        var ii: usize = 0;

        const tag0 = v.tags[0];
        const tag1 = v.tags[1];

        while (ii < len) : (ii = tclose - 1) {
            const op = std.mem.indexOfPos(u8, str, ii, tag0) orelse break;
            const cl = std.mem.indexOfPos(u8, str, op, tag1) orelse break;

            std.mem.copy(
                u8,
                str[op..len],
                str[op + tag0.len .. len],
            );

            tclose = cl - tag0.len;
            std.mem.copy(
                u8,
                str[tclose .. len - tag0.len],
                str[tclose + tag1.len .. len - tag0.len],
            );

            len -= (tag0.len + tag1.len);
        }
    }

    return str[0..len];
}
