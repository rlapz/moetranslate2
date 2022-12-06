const std = @import("std");
const dprint = std.debug.print;

const Self = @This();

// zig fmt: off
allocator: std.mem.Allocator,
stream   : std.net.Stream,
buffer   : []u8,
// zig fmt: on

pub fn init(
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
        .buffer = undefined,
    };
}

pub fn deinit(self: *Self) void {
    self.stream.close();
    self.allocator.free(self.buffer);
}

pub inline fn sendRequest(self: *Self, req: []const u8) !void {
    return self.stream.writer().writeAll(req);
}

pub fn getJson(self: *Self) ![]u8 {
    var bf = try self.stream.reader().readAllAlloc(self.allocator, 1024 * 64);
    self.buffer = bf;

    if (std.mem.indexOf(u8, bf, "200 OK") == null)
        return error.InvalidResponse;

    // Skipping http header...
    const end_h = std.mem.indexOf(u8, bf, "\r\n\r\n") orelse {
        return error.InvalidJSON;
    };

    bf = bf[end_h + 4 ..];
    const st = std.mem.indexOf(u8, bf, "[") orelse {
        return error.InvalidJSON;
    };
    const ed = std.mem.lastIndexOf(u8, bf, "]") orelse {
        return error.InvalidJSON;
    };

    return bf[st .. ed + 1];
}
