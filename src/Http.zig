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
allocator: std.mem.Allocator,
stream   : std.net.Stream,
buffer   : []u8,
has_resp : bool,
// zig fmt: on

pub inline fn init(
    allocator: std.mem.Allocator,
    host: []const u8,
    port: u16,
) !Self {
    var stream = try std.net.tcpConnectToHost(allocator, host, port);
    errdefer stream.close();

    return Self{
        .allocator = allocator,
        .stream = stream,
        .buffer = try allocator.alloc(u8, 4096),
        .has_resp = false,
    };
}

pub inline fn deinit(self: *Self) void {
    self.stream.close();
    self.allocator.free(self.buffer);
}

pub fn sendRequest(self: *Self, req: []const u8) !void {
    return self.stream.writer().writeAll(req);
}

pub fn getResponse(self: *Self) ![]u8 {
    var b_total = try self.stream.reader().readAll(self.buffer);

    if (std.mem.indexOf(u8, self.buffer, "200 OK") == null)
        return Error.InvalidResponse;

    self.has_resp = true;

    return self.buffer[0..b_total];
}

pub fn getJson(self: *Self) ![]u8 {
    if (!self.has_resp)
        _ = try self.getResponse();

    // Skipping http header...
    const end_h = std.mem.indexOf(u8, self.buffer, "\r\n\r\n") orelse {
        return Error.InvalidJSON;
    };

    var ret = self.buffer[end_h + 4 ..];
    const st = std.mem.indexOf(u8, ret, "[") orelse {
        return Error.InvalidJSON;
    };
    const ed = std.mem.lastIndexOf(u8, ret, "]") orelse {
        return Error.InvalidJSON;
    };

    return ret[st .. ed + 1];
}
