// MIT License
//
// Copyright (c) 2022 Arthur Lapz (rLapz)
//
// See LICENSE file for license details

const std = @import("std");
const util = @import("util.zig");
const Error = @import("Error.zig").Error;

// zig fmt: off
pub const host   = "translate.googleapis.com";
pub const port   = @as(u16, 80);

const method     = "GET";
const protocol   = "HTTP/1.1";
const query      = "/translate_a/single?client=gtx&ie=UTF-8&oe=UTF-8";
const user_agent = "Mozilla/5.0";
const connection = "Close";

const brief      = "&dt=t";
const detail     = "&dt=bd&dt=ex&dt=ld&dt=md&dt=rw&dt=rm&dt=ss&dt=" ++
                   "t&dt=at&dt=gt&dt=qca";
const det_lang   = "";
// zig fmt: on

pub const UrlBuildType = enum(u32) {
    brief = 1,
    detail,
    detect_lang,

    pub fn str(self: @This()) []const u8 {
        return switch (self) {
            .brief => "Brief",
            .detail => "Detail",
            .detect_lang => "Detect Language",
        };
    }
};

pub fn buildRequest(
    buffer: []u8,
    url_type: UrlBuildType,
    src_lang: []const u8,
    trg_lang: []const u8,
    text: []const u8,
) Error![]const u8 {
    // At least the buffer length should be three times larger than
    // the text length,
    // it's needed for encoding. CMIIW
    if (buffer.len <= (text.len * 3))
        return Error.NoSpaceLeft;

    // zig fmt: on
    var ret = switch (url_type) {
        .brief => try std.fmt.bufPrint(
            buffer,
            "{s} {s}" ++ brief ++ "&sl={s}&tl={s}&q=",
            .{ method, query, src_lang, trg_lang },
        ),
        .detail => try std.fmt.bufPrint(
            buffer,
            "{s} {s}" ++ detail ++ "&sl={s}&tl={s}&hl={s}&q=",
            .{ method, query, src_lang, trg_lang, trg_lang },
        ),
        .detect_lang => try std.fmt.bufPrint(
            buffer,
            "{s} {s}" ++ det_lang ++ "&sl={s}&q=",
            .{ method, query, "auto" },
        ),
    };

    const text_enc = encode(buffer[ret.len..], text);
    var len = ret.len + text_enc.len;

    ret = try std.fmt.bufPrint(
        buffer[len..],
        " {s}\r\nHost: {s}\r\nUser-Agent: {s}\r\nConnection: {s}\r\n\r\n",
        .{ protocol, host, user_agent, connection },
    );

    return buffer[0 .. len + ret.len];
}

fn encode(dest: []u8, src: []const u8) []const u8 {
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
