const std = @import("std");

const util = @import("util.zig");

// zig fmt: off
pub const host   = "translate.googleapis.com";
pub const port   = 80;

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

pub const UrlBuildType = enum {
    brief,
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

// Caller owns returned memory
pub fn buildRequest(
    allocator: std.mem.Allocator,
    url_type: UrlBuildType,
    src_lang: []const u8,
    trg_lang: []const u8,
    text: []const u8,
) ![]u8 {
    var buffer = try std.ArrayList(u8).initCapacity(allocator, 4096);
    defer buffer.deinit();

    const wr = buffer.writer();
    switch (url_type) {
        .brief => try wr.print(
            "{s} {s}" ++ brief ++ "&sl={s}&tl={s}&q=",
            .{ method, query, src_lang, trg_lang },
        ),
        .detail => try wr.print(
            "{s} {s}" ++ detail ++ "&sl={s}&tl={s}&hl={s}&q=",
            .{ method, query, src_lang, trg_lang, trg_lang },
        ),
        .detect_lang => try wr.print(
            "{s} {s}" ++ det_lang ++ "&sl=auto&q=",
            .{ method, query },
        ),
    }

    // encode
    const hex = "0123456789abcdef";
    for (text) |v| {
        if (!std.ascii.isAlNum(v))
            try wr.print("%{c}{c}", .{ hex[(v >> 4) & 15], hex[v & 15] })
        else
            try wr.writeByte(v);
    }

    try wr.print(
        " {s}\r\nHost: {s}\r\nUser-Agent: {s}\r\nConnection: {s}\r\n\r\n",
        .{ protocol, host, user_agent, connection },
    );

    return buffer.toOwnedSlice();
}
