// MIT License
//
// Copyright (c) 2022 Arthur Lapz (rLapz)
//
// See LICENSE file for license details

const builtin = @import("builtin");

pub const Color = enum {
    blue,
    green,
    white,
    yellow,

    const Self = @This();

    pub fn regular(self: Self, comptime str: []const u8) []const u8 {
        switch (builtin.os.tag) {
            .windows => return switch (self) {
                .blue => str,
                .green => str,
                .white => str,
                .yellow => str,
            },
            else => return switch (self) {
                .blue => "\x1b[00;34m" ++ str ++ "\x1b[0m",
                .green => "\x1b[00;32m" ++ str ++ "\x1b[0m",
                .white => "\x1b[00;39m" ++ str ++ "\x1b[0m",
                .yellow => "\x1b[00;33m" ++ str ++ "\x1b[0m",
            },
        }
    }

    pub fn bold(self: Self, comptime str: []const u8) []const u8 {
        switch (builtin.os.tag) {
            .windows => return switch (self) {
                .blue => str,
                .green => str,
                .white => str,
                .yellow => str,
            },
            else => return switch (self) {
                .blue => "\x1b[01;34m" ++ str ++ "\x1b[0m",
                .green => "\x1b[01;32m" ++ str ++ "\x1b[0m",
                .white => "\x1b[01;39m" ++ str ++ "\x1b[0m",
                .yellow => "\x1b[01;33m" ++ str ++ "\x1b[0m",
            },
        }
    }
};
