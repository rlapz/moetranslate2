const std = @import("std");
const mem = std.mem;
const net = std.net;

pub fn sendRequest(
    allocator: mem.Allocator,
    req: []const u8,
    host: []const u8,
    port: u16,
) !net.Stream {
    var ret = try net.tcpConnectToHost(allocator, host, port);
    try ret.writer().writeAll(req);

    return ret;
}

// Caller owns returned memory
pub fn getResponse(
    allocator: mem.Allocator,
    stream: *net.Stream,
    buffer_size: usize,
) ![]u8 {
    return stream.reader().readAllAlloc(allocator, buffer_size);
}

pub fn getJson(raw: []const u8) ![]const u8 {
    const res = mem.indexOf(u8, raw, "200 OK") orelse brk: {
        break :brk mem.indexOf(u8, raw, "200 ok") orelse {
            return error.InvalidResponse;
        };
    };

    // Skipping http header...
    const end_h = mem.indexOf(u8, raw[res..], "\r\n\r\n") orelse {
        return error.InvalidJSON;
    };

    const _raw = raw[end_h + 4 ..];
    const st = mem.indexOf(u8, _raw, "[") orelse {
        return error.InvalidJSON;
    };
    const ed = mem.lastIndexOf(u8, _raw, "]") orelse {
        return error.InvalidJSON;
    };

    return _raw[st .. ed + 1];
}
