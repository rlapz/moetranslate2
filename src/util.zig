// MIT License
//
// Copyright (c) 2022 Arthur Lapz (rLapz)
//
// See LICENSE file for license details

const std = @import("std");
const Error = @import("Error.zig").Error;
const Lang = @import("Lang.zig");

var stdout_buffer = std.io.bufferedWriter(std.io.getStdOut().writer());
//var stderr_buffer = std.io.bufferedWriter(std.io.getStdErr().writer());

pub inline fn writeOutIgn(comptime wbuf: bool, comptime msg: []const u8) void {
    switch (wbuf) {
        true => {
            _ = stdout_buffer.writer().write(msg) catch {};
        },
        false => {
            _ = std.io.getStdOut().writer().write(msg) catch {};
        },
    }
}

pub inline fn printOutIgn(
    comptime wbuf: bool,
    comptime msg: []const u8,
    args: anytype,
) void {
    switch (wbuf) {
        true => stdout_buffer.writer().print(msg, args) catch {},
        false => std.io.getStdOut().writer().print(msg, args) catch {},
    }
}

pub inline fn outFlush() void {
    stdout_buffer.flush() catch {};
}

pub inline fn writeErrIgn(comptime wbuf: bool, comptime msg: []const u8) void {
    _ = wbuf;
    _ = std.io.getStdErr().writer().write(msg) catch {};
}

pub inline fn printErrIgn(
    comptime wbuf: bool,
    comptime msg: []const u8,
    args: anytype,
) void {
    _ = wbuf;
    _ = std.io.getStdErr().writer().print(msg, args) catch {};
}

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

const dprint = std.debug.print;
const expect = std.testing.expect;

test "util" {
    dprint("\n", .{});

    var html1 = "<b>wwww</b>".*;
    var html2 = "hello <b>World</b> wwww <b>aaa</b>".*;
    var html3 = "<b>x</b> hello <b>World</b> wwww".*;
    var html4 = "<b>bold</b><b></b>".*;
    //var html5 = "<i>bold</i><b></b>".*;

    try expect(std.mem.eql(u8, skipHtmlTags(&html1), "wwww"));
    try expect(std.mem.eql(u8, skipHtmlTags(&html2), "hello World wwww aaa"));
    try expect(std.mem.eql(u8, skipHtmlTags(&html3), "x hello World wwww"));
    try expect(std.mem.eql(u8, skipHtmlTags(&html4), "bold"));
    //try expect(mem.eql(u8, skipHtmlTags(&html5), "bold"));
}
