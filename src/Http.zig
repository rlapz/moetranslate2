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
// zig fmt: on

pub inline fn init(
    allocator: std.mem.Allocator,
    host: []const u8,
    port: u16,
) !Self {
    return Self{
        .allocator = allocator,
        .stream = try std.net.tcpConnectToHost(
            allocator,
            host,
            port,
        ),
    };
}

pub inline fn deinit(self: *Self) void {
    self.stream.close();
}

pub inline fn sendRequest(self: *Self, req: []const u8) !void {
    return self.stream.writer().writeAll(req);
}

pub fn getJson(self: *Self, buffer: []u8) ![]u8 {
    var b_total = try self.stream.reader().readAll(buffer);
    var bf = buffer[0..b_total];

    if (std.mem.indexOf(u8, bf, "200 OK") == null)
        return Error.InvalidResponse;

    // Skipping http header...
    const end_h = std.mem.indexOf(u8, bf, "\r\n\r\n") orelse {
        return Error.InvalidJSON;
    };

    bf = bf[end_h + 4 ..];
    const st = std.mem.indexOf(u8, bf, "[") orelse {
        return Error.InvalidJSON;
    };
    const ed = std.mem.lastIndexOf(u8, bf, "]") orelse {
        return Error.InvalidJSON;
    };

    return bf[st .. ed + 1];
}
