// MIT License
//
// Copyright (c) 2022 Arthur Lapz (rLapz)
//
// See LICENSE file for license details

const std = @import("std");
const builtin = @import("builtin");
const dprint = std.debug.print;

const config = @import("config.zig");
const Moetranslate = @import("Moetranslate.zig");
const Error = @import("Error.zig").Error;
const Lang = @import("Lang.zig");
const Url = @import("Url.zig");
const util = @import("util.zig");
const Color = @import("Color.zig").Color;

const getopt = @import("lib/getopt.zig");

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cInclude("locale.h");
    @cInclude("editline/readline.h");
});

const Cmd = enum(u8) {
    quit,
    info,
    help,
    ch_lang,
    sw_lang,
    ch_output,
    ch_result,
    nop,
};

var g_fba: *std.heap.FixedBufferAllocator = undefined;

fn printHelp() void {
    util.writeErrIgn(false, "" ++
        "moetranslate2 - A beautiful and simple language translator\n\n" ++
        "Usage: moetranslate2 [OPT] [SOURCE:TARGET] [TEXT]\n" ++
        "       -b    Brief output\n" ++
        "       -f    Full/detail output\n" ++
        "       -r    Raw output (json)\n" ++
        "       -d    Detect language\n" ++
        "       -i    Interactive input mode\n" ++
        "       -h    Show this help\n\n" ++
        "Examples:\n" ++
        "   Brief Mode      : moetranslate2 -b en:id \"Hello\"\n" ++
        "   Full/detail Mode: moetranslate2 -f id:en \"Halo\"\n" ++
        "   Auto Lang       : moetranslate2 -f auto:en \"こんにちは\"\n" ++
        "   Detect Lang     : moetranslate2 -d \"你好\"\n" ++
        "   Interactive     : moetranslate2 -i\n" ++
        "                     moetranslate2 -i -f auto:en\n");
}

fn printHelpIntrc(moe: *Moetranslate) void {
    util.printErrIgn(false, "" ++
        "------------------------\n" ++
        Color.white.bold("Change the Languages:") ++
        " -> [{s}:{s}]\n" ++
        " /c [SOURCE]:[TARGET]\n\n" ++
        Color.white.bold("Swap Language:") ++ "\n" ++
        " /s\n\n" ++
        Color.white.bold("Result Type:         ") ++
        " -> [{s}]\n" ++
        " /r [TYPE]\n" ++
        "     TYPE:\n" ++
        "      1 = Brief\n" ++
        "      2 = Detail\n" ++
        "      3 = Detect Language\n\n" ++
        Color.white.bold("Change Output Mode:  ") ++
        " -> [{s}]\n" ++
        " /o [OUTPUT]\n" ++
        "     OUTPUT:\n" ++
        "      1 = Parse\n" ++
        "      2 = Raw\n\n" ++
        Color.white.bold("Show Help:") ++ "\n" ++
        " /h\n\n" ++
        Color.white.bold("Quit:") ++ "\n" ++
        " /q\n" ++
        "------------------------\n", .{
        moe.src_lang.key,      moe.trg_lang.key,
        moe.result_type.str(), moe.output_mode.str(),
    });
}

fn printInfoIntrc(moe: *Moetranslate) void {
    util.printOutIgn(false, "" ++
        Color.white.bold("----[ Moetranslate2 ]----") ++ "\n" ++
        Color.yellow.bold("Interactive input mode") ++ "\n\n" ++
        Color.white.bold("Languages   :") ++
        " {s} ({s})\n" ++
        "              {s} ({s})\n" ++
        Color.white.bold("Result type :") ++ " {s}\n" ++
        Color.white.bold("Output mode :") ++ " {s}\n" ++
        Color.white.bold("Show help   :") ++ " Type /h\n\n" ++
        "------------------------\n", .{
        moe.src_lang.value,    moe.src_lang.key,
        moe.trg_lang.value,    moe.trg_lang.key,
        moe.result_type.str(), moe.output_mode.str(),
    });
}

fn parseLang(str: []const u8, src: **const Lang, trg: **const Lang) !void {
    const sep = std.mem.indexOfScalar(u8, str, ':') orelse {
        return Error.InvalidArgument;
    };

    const _src = std.mem.trim(u8, str[0..sep], " ");
    const _trg = std.mem.trim(u8, str[sep + 1 ..], " ");

    // If src/trg lang is empty, use default value from `config.zig` file
    if (_src.len > 0) {
        src.* = Lang.getByKey(_src) catch |err| {
            util.printErrIgn(
                false,
                Color.yellow.regular("Unknown \"{s}\" language code") ++ "\n",
                .{_src},
            );
            return err;
        };
    }

    if (_trg.len > 0) {
        trg.* = Lang.getByKey(_trg) catch |err| {
            util.printErrIgn(
                false,
                Color.yellow.regular("Unknown \"{s}\" language code") ++ "\n",
                .{_trg},
            );
            return err;
        };
    }
}

inline fn showPrompt(
    buffer: []u8,
    src: []const u8,
    trg: []const u8,
) Error![:0]const u8 {
    return std.fmt.bufPrintZ(
        buffer,
        "[ {s}:{s} ]{s} ",
        .{ src, trg, config.prompt },
    );
}

fn parseCmdIntr(moe: *Moetranslate, cmd: []const u8) Error!Cmd {
    if (cmd.len < 1 or cmd[0] != '/')
        return .nop;

    if (cmd.len == 1) {
        printInfoIntrc(moe);
        return .info;
    }

    switch (cmd[1]) {
        'q' => return .quit,
        'h' => {
            if (cmd.len == 2) {
                printHelpIntrc(moe);
                return .help;
            }
        },
        'c' => {
            parseLang(cmd[2..], &moe.src_lang, &moe.trg_lang) catch |err| {
                util.printErrIgn(
                    false,
                    Color.yellow.regular("Error: {s}") ++ "\n",
                    .{@errorName(err)},
                );
            };

            return .ch_lang;
        },
        's' => {
            const l = moe.src_lang;

            moe.src_lang = moe.trg_lang;
            moe.trg_lang = l;

            return .sw_lang;
        },
        'o' => {
            const _cmd = std.mem.trim(u8, cmd[2..], " ");

            if (std.fmt.parseInt(u32, _cmd, 10)) |opt| switch (opt) {
                1...2 => {
                    moe.output_mode = @intToEnum(Moetranslate.OutputMode, opt);
                    util.printErrIgn(
                        false,
                        Color.green.regular("Output mode: {s}") ++ "\n",
                        .{moe.output_mode.str()},
                    );
                    return .ch_output;
                },
                else => {},
            } else |_| {}
        },
        'r' => {
            const _cmd = std.mem.trim(u8, cmd[2..], " ");

            if (std.fmt.parseInt(u32, _cmd, 10)) |opt| switch (opt) {
                1...3 => {
                    moe.result_type = @intToEnum(Url.UrlBuildType, opt);
                    util.printErrIgn(
                        false,
                        Color.green.regular("Result type: {s}") ++ "\n",
                        .{moe.result_type.str()},
                    );
                    return .ch_result;
                },
                else => {},
            } else |_| {}
        },
        else => {},
    }

    return Error.InvalidArgument;
}

fn intrInput(moe: *Moetranslate) !void {
    printInfoIntrc(moe);

    var input_buffer: [16 + config.prompt.len]u8 = undefined;
    var input_p: [:0]const u8 = undefined;

    input_p = try showPrompt(&input_buffer, moe.src_lang.key, moe.trg_lang.key);

    // Show the results immediately if the text is not null
    if (moe.text.len > 0) {
        moe.run() catch |_err| {
            util.printErrIgn(
                false,
                Color.yellow.regular("Error: {s}") ++ "\n",
                .{@errorName(_err)},
            );
        };
        g_fba.reset();
        util.writeOutIgn(false, "------------------------\n\n");
    }

    var err: anyerror = Error.Success;
    while (true) {
        if (err != Error.Success) {
            util.printErrIgn(
                false,
                Color.yellow.regular("Error: {s}") ++ "\n",
                .{@errorName(err)},
            );
            err = Error.Success;
        }

        var input = c.readline(@as([*c]const u8, input_p)) orelse continue;
        _ = c.add_history(input);
        moe.text = std.mem.trim(u8, std.mem.span(input), " ");

        if (parseCmdIntr(moe, moe.text)) |_v| {
            switch (_v) {
                .quit => {
                    c.free(input);
                    break;
                },
                .nop => {},
                else => {
                    input_p = showPrompt(
                        &input_buffer,
                        moe.src_lang.key,
                        moe.trg_lang.key,
                    ) catch brk: {
                        break :brk "[]-> ";
                    };

                    continue;
                },
            }
        } else |_err| {
            err = _err;
            c.free(input);
            continue;
        }

        if (moe.text.len > 0) {
            util.writeOutIgn(false, "------------------------\n");

            moe.run() catch |_err| {
                err = _err;
            };

            util.writeOutIgn(false, "------------------------\n\n");
            g_fba.reset();
        }

        c.free(input);
    }
}

pub fn main() !void {
    var is_intrc = false;
    var argv: [][*:0]const u8 = undefined;
    var gopts = getopt.getopt("b:f:d:rih");

    if (gopts.argv.len == 1) {
        printHelp();
        return Error.InvalidArgument;
    }

    var real_buffer: [config.buffer_max_length]u8 align(@alignOf(u64)) = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&real_buffer);
    g_fba = &fba;

    var moe = try Moetranslate.init(fba.allocator());

    while (true) {
        argv = gopts.argv;

        const opts = (try gopts.next()) orelse break;
        switch (opts.opt) {
            'b' => {
                moe.result_type = .brief;
                try parseLang(
                    std.mem.span(argv[gopts.optind - 1]),
                    &moe.src_lang,
                    &moe.trg_lang,
                );
            },
            'f' => {
                moe.result_type = .detail;
                try parseLang(
                    std.mem.span(argv[gopts.optind - 1]),
                    &moe.src_lang,
                    &moe.trg_lang,
                );
            },
            'd' => moe.result_type = .detect_lang,
            'r' => moe.output_mode = .raw,
            'i' => is_intrc = true,
            'h' => return printHelp(),
            else => return Error.InvalidArgument,
        }
    }

    switch (moe.result_type) {
        .detect_lang => {
            moe.text = std.mem.span(argv[gopts.optind - 1]);
        },
        else => {
            if (gopts.optind < argv.len)
                moe.text = std.mem.span(argv[gopts.optind]);
        },
    }

    if (is_intrc) {
        switch (builtin.os.tag) {
            .windows => {
                util.writeErrIgn("Interactive input mode: Not supported!\n");
                return Error.InvalidArgument;
            },
            else => {
                _ = c.setlocale(c.LC_CTYPE, "");
                try intrInput(&moe);
            },
        }
    } else {
        try moe.run();
    }
}
