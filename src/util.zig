// MIT License
//
// Copyright (c) 2022 Arthur Lapz (rLapz)
//
// See LICENSE file for license details

const std = @import("std");
const dprint = std.debug.print;

const Error = @import("Error.zig").Error;
const Lang = @import("Lang.zig");

pub fn urlEncode(dest: []u8, src: []const u8) []const u8 {
    const hex = "0123456789abcdef";
    var count: usize = 0;

    for (src) |v| {
        if (!std.ascii.isAlNum(v)) {
            dest[count] = '%';
            dest[count + 1] = hex[(v >> 4) & 15];
            dest[count + 2] = hex[v & 15];

            count += 3;

            continue;
        }
        dest[count] = v;
        count += 1;
    }

    return dest[0..count];
}

pub fn skipHtmlTags(str: []u8) []const u8 {
    const Table = struct { tags: [2][]const u8 };

    const tables = [_]Table{
        .{ .tags = .{ "<b>", "</b>" } },
        // Add other tags below
    };

    var len = str.len;
    var i: usize = 0;

    while (i < tables.len) : (i += 1) {
        var tclose: usize = 0;
        var ii: usize = 0;

        const tag0 = tables[i].tags[0];
        const tag1 = tables[i].tags[1];

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
