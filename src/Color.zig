// MIT License
//
// Copyright (c) 2022 Arthur Lapz (rLapz)
//
// See LICENSE file for license details

const std = @import("std");
const builtin = @import("builtin");

const config = @import("config.zig");

pub const Color = enum(u32) {
    green = 32,
    yellow = 33,
    blue = 34,
    white = 39,

    const Self = @This();

    pub fn regular(self: Self, comptime _str: []const u8) []const u8 {
        if (builtin.os.tag != .windows) {
            if (config.color) {
                return std.fmt.comptimePrint("\x1b[00;{}m{s}\x1b[0m", .{
                    @enumToInt(self),
                    _str,
                });
            }
        }

        return _str;
    }

    pub fn bold(self: Self, comptime _str: []const u8) []const u8 {
        if (builtin.os.tag != .windows) {
            if (config.color) {
                return std.fmt.comptimePrint("\x1b[01;{}m{s}\x1b[0m", .{
                    @enumToInt(self),
                    _str,
                });
            }
        }

        return _str;
    }
};
