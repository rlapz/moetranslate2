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
const field_name = "Host: {s}\r\nUser-Agent: {s}\r\nConnection: {s}\r\n\r\n";

const brief      = "{s} {s}&dt=t&sl={s}&tl={s}&q={s} {s}\r\n";
const detail     = "{s} {s}&dt=bd&dt=ex&dt=ld&dt=md&dt=rw&dt=rm&dt=ss&dt=" ++
                   "t&dt=at&dt=gt&dt=qca&sl={s}&tl={s}&hl={s}&q={s} {s}\r\n";
const det_lang   = "{s} {s}&sl=auto&q={s} {s}\r\n";

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
    // At least the buffer length should be three times larger than the text length,
    // it's needed for encoding. CMIIW
    if (buffer.len <= (text.len * 3))
        return Error.NoSpaceLeft;

    const text_enc = util.urlEncode(buffer, text);

    return switch (url_type) {
        .brief => std.fmt.bufPrint(
            buffer[text_enc.len..], brief ++ field_name,
            .{
                method, query, src_lang, trg_lang, text_enc, protocol, host,
                user_agent, connection,
            },
        ),
        .detail => std.fmt.bufPrint(
            buffer[text_enc.len..], detail ++ field_name,
            .{
                method, query, src_lang, trg_lang, trg_lang, text_enc, protocol,
                host, user_agent, connection,
            },
        ),
        .detect_lang => std.fmt.bufPrint(
            buffer[text_enc.len..], det_lang ++ field_name,
            .{
                method, query, text_enc, protocol, host, user_agent,
                connection,
            },
        ),
    };
}
// zig fmt: on
