// MIT License
//
// Copyright (c) 2022 Arthur Lapz (rLapz)
//
// See LICENSE file for license details

const std = @import("std");
const dprint = std.debug.print;
const Error = @import("Error.zig").Error;

const Self = @This();

// zig fmt: off
allocator : std.mem.Allocator,
stream    : ?std.net.Stream = null,
buffer    : ?[]u8           = null,
has_resp  : bool            = false,
// zig fmt: on

pub inline fn init(
    allocator: std.mem.Allocator,
    host: []const u8,
    port: u16,
) !Self {
    return Self{
        .allocator = allocator,
        .stream = try std.net.tcpConnectToHost(allocator, host, port),
        .buffer = try allocator.alloc(u8, 4096),
    };
}

pub inline fn deinit(self: *Self) void {
    if (self.stream != null)
        self.stream.?.close();

    if (self.buffer != null)
        self.allocator.free(self.buffer.?);
}

pub fn sendRequest(self: *Self, req: []const u8) !void {
    var b_total: usize = 0;
    var sent: usize = 0;

    while (b_total < req.len) : (b_total += sent) {
        sent = try self.stream.?.writer().write(req);

        if (sent == 0)
            break;
    }
}

pub fn getResponse(self: *Self) ![]u8 {
    var _buffer = self.buffer.?;
    var buffer_len = _buffer.len;
    var b_total: usize = 0;
    var recvd: usize = 0;

    while (b_total < buffer_len) {
        recvd = try self.stream.?.read(_buffer[b_total..buffer_len]);

        if (recvd == 0)
            break;

        b_total += recvd;

        if (b_total == buffer_len) {
            buffer_len += (buffer_len >> 1);
            _buffer = try self.allocator.realloc(_buffer, buffer_len);
        }
    }

    if (std.mem.indexOf(u8, _buffer, "200 OK") == null)
        return Error.InvalidResponse;

    self.has_resp = true;
    self.buffer = _buffer[0..b_total];

    return self.buffer.?;
}

pub fn getJson(self: *Self) ![]u8 {
    if (!self.has_resp)
        _ = try self.getResponse();

    var src = self.buffer.?;
    const src_len = src.len;

    // Skipping http header...
    const end_h = std.mem.indexOf(u8, src, "\r\n\r\n") orelse {
        return Error.InvalidJSON;
    };

    var i: u8 = 0;
    var istart = end_h + 4;
    var iend = src_len;

    // Removing "stray" bytes
    while (i < 2) : (i += 1) {
        const st = std.mem.indexOfPos(u8, src, istart, "\r\n") orelse {
            return Error.InvalidJSON;
        };

        const ed = std.mem.lastIndexOf(u8, src[0..iend], "\r\n") orelse {
            return Error.InvalidJSON;
        };

        iend -= (src_len - ed);
        istart += (st - istart);
    }

    return src[istart + 2 .. iend];
}
