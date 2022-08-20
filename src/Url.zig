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
const req_format = "{s} {s} {s}\r\n" ++
                   "Host: {s}\r\n" ++
                   "User-Agent: {s}\r\n" ++
                   "Connection: {s}\r\n\r\n";

// 0: source lang
// 1: target lang
// 2: text
const brief = std.fmt.comptimePrint(
    req_format,
    .{
        method, query ++ "&dt=t&sl={s}&tl={s}&q={s}", protocol,
        host, user_agent, connection
    }
);

// 0: source lang
// 1: target lang
// 2: hint lang
// 3: text
const detail = std.fmt.comptimePrint(
    req_format,
    .{
        method,
        query ++ "&dt=bd&dt=ex&dt=ld&dt=md&dt=rw&dt=rm&dt=ss&dt=" ++
                 "t&dt=at&dt=gt&dt=qca&sl={s}&tl={s}&hl={s}&q={s}",
        protocol,
        host, user_agent, connection
    }
);

// 0: text
const det_lang = std.fmt.comptimePrint(
    req_format,
    .{
        method, query ++ "&sl=auto&q={s}", protocol,
        host, user_agent, connection
    }
);


pub const UrlBuildType = enum(u32) {
    brief = 1,
    detail,
    detect_lang,

    pub fn str(self: @This()) []const u8 {
        return switch(self) {
            .brief       => "Brief",
            .detail      => "Detail",
            .detect_lang => "Detect Language",

        };
    }
};


pub fn build(
    url_type: UrlBuildType,
    buffer  : []u8,
    src_lang: []const u8,
    trg_lang: []const u8,
    text    : []const u8,
) Error![]const u8 {
    // At least the buffer length should be three times larger than
    // the text length,
    // it's needed for encoding. CMIIW
    if (buffer.len <= (text.len * 3))
        return Error.NoSpaceLeft;

    const text_enc = encode(buffer, text);

    return switch (url_type) {
        .brief => std.fmt.bufPrint(
            buffer[text_enc.len..], brief,
            .{
                src_lang, trg_lang, text_enc
            }
        ),
        .detail => std.fmt.bufPrint(
            buffer[text_enc.len..], detail,
            .{
                src_lang, trg_lang, trg_lang, text_enc
            }
        ),
        .detect_lang => std.fmt.bufPrint(
            buffer[text_enc.len..], det_lang,
            .{
                text_enc
            }
        ),
    };
}
// zig fmt: on

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
