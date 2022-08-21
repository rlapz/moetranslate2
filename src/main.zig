// MIT License
//
// Copyright (c) 2022 Arthur Lapz (rLapz)
//
// See LICENSE file for license details

const std = @import("std");
const dprint = std.debug.print;

const config = @import("config.zig");
const Moetranslate = @import("Moetranslate.zig");
const Error = @import("Error.zig").Error;
const Lang = @import("Lang.zig");
const Url = @import("Url.zig");
const Color = @import("Color.zig").Color;

const getopt = @import("lib/getopt.zig");

const c = @cImport({
    @cInclude("locale.h");
    @cInclude("editline/readline.h");
});

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();
var g_fba: *std.heap.FixedBufferAllocator = undefined;

// zig fmt: off
fn printHelp() void {
    stdout.writeAll(
        \\moetranslate2 - A beautiful and simple language translator
        \\
        \\Usage: moetranslate2 [OPT] [SOURCE:TARGET] [TEXT]
        \\       -b    Brief output
        \\       -f    Full/detail output
        \\       -r    Raw output (json)
        \\       -d    Detect language
        \\       -i    Interactive input mode
        \\       -h    Show this help
        \\
        \\Examples:
        \\   Brief Mode      : moetranslate2 -b en:id \"Hello\"
        \\   Full/detail Mode: moetranslate2 -f id:en \"Halo\"
        \\   Auto Lang       : moetranslate2 -f auto:en \"こんにちは\"
        \\   Detect Lang     : moetranslate2 -d \"你好\"
        \\   Interactive     : moetranslate2 -i
        \\                     moetranslate2 -i -f auto:en
        \\
    ) catch {};
}

fn printHelpIntr() void {
    stdout.print(
        Color.white.bold("Show Info:") ++ "\n" ++
        " /\n\n" ++
        Color.white.bold("Change Languages:") ++ "\n" ++
        " /c [SOURCE]:[TARGET]\n\n" ++
        Color.white.bold("Change Result Type:") ++ "\n" ++
        " /r [TYPE]\n" ++
        "     TYPE:\n" ++
        "      1 = Brief\n" ++
        "      2 = Detail\n" ++
        "      3 = Detect Language\n\n" ++
        Color.white.bold("Change Output Mode:") ++ "\n" ++
        " /o [OUTPUT]\n" ++
        "     OUTPUT:\n" ++
        "      1 = Parse\n" ++
        "      2 = Raw\n\n" ++
        Color.white.bold("Swap Languages:") ++ "\n" ++
        " /s\n\n" ++
        Color.white.bold("Quit:") ++ "\n" ++
        " /q\n" , .{}
    ) catch {};
}

fn printInfoIntr(moe: *Moetranslate) void {
    stdout.print(
        Color.white.bold("----[ Moetranslate2 ]----") ++ "\n\n" ++
        Color.white.bold("Languages   :") ++ " {s} - {s}\n" ++
        Color.white.bold("Result type :") ++ " {s}\n" ++
        Color.white.bold("Output mode :") ++ " {s}\n" ++
        Color.white.bold("Show help   :") ++ " /h\n\n", .{
            moe.src_lang.value,    moe.trg_lang.value,
            moe.result_type.str(), moe.output_mode.str(),
        }
    ) catch {};
}
// zig fmt: on

inline fn parseEnum(arg: []const u8) !u32 {
    return std.fmt.parseUnsigned(
        u32,
        std.mem.trim(u8, arg, " "),
        10,
    ) catch {
        return Error.InvalidArgument;
    };
}

fn parseLang(moe: *Moetranslate, str: []const u8) !void {
    const sep = std.mem.indexOfScalar(u8, str, ':') orelse {
        return Error.InvalidArgument;
    };
    var lang_err: []const u8 = undefined;

    errdefer {
        stderr.print(
            Color.yellow.regular("Unknown \"{s}\" language code") ++ "\n",
            .{lang_err},
        ) catch {};
    }

    const _src = std.mem.trim(u8, str[0..sep], " ");
    if (_src.len > 0) {
        moe.src_lang = Lang.getByKey(_src) catch |_err| {
            lang_err = _src;
            return _err;
        };
    }

    const _trg = std.mem.trim(u8, str[sep + 1 ..], " ");
    if (_trg.len > 0) {
        moe.trg_lang = Lang.getByKey(_trg) catch |_err| {
            lang_err = _trg;
            return _err;
        };
    }
}

fn getIntrResult(
    moe: *Moetranslate,
    is_running: *bool,
    update_prompt: *bool,
) !void {
    const cmd = moe.text;
    if (cmd[0] != '/') {
        g_fba.reset();
        stdout.writeAll(config.separator ++ "\n") catch {};

        // Let's GO!
        return moe.run();
    }

    if (cmd.len == 1)
        return printInfoIntr(moe);

    switch (cmd[1]) {
        'q' => {
            is_running.* = false;
        },
        'h' => {
            if (cmd.len != 2)
                return Error.InvalidArgument;

            return printHelpIntr();
        },
        'c' => {
            update_prompt.* = true;
            return parseLang(moe, cmd[2..]);
        },
        's' => {
            if (cmd.len != 2)
                return Error.InvalidArgument;

            std.mem.swap(*const Lang, &moe.src_lang, &moe.trg_lang);
            update_prompt.* = true;
        },
        'o' => {
            const opt = try parseEnum(cmd[2..]);
            if (opt > 1)
                return Error.InvalidArgument;

            moe.output_mode = @intToEnum(Moetranslate.OutputMode, opt);

            try stdout.print(
                Color.green.regular("Output mode: {s}") ++ "\n",
                .{moe.output_mode.str()},
            );
        },
        'r' => {
            const opt = try parseEnum(cmd[2..]);
            if (opt > 2)
                return Error.InvalidArgument;

            moe.result_type = @intToEnum(Url.UrlBuildType, opt);

            try stderr.print(
                Color.green.regular("Result type: {s}") ++ "\n",
                .{moe.result_type.str()},
            );
        },
        else => return Error.InvalidArgument,
    }
}

fn inputIntr(moe: *Moetranslate) !void {
    var is_running: bool = true;
    var buffer: [16 + config.prompt.len]u8 = undefined;
    var prompt: [:0]const u8 = undefined;
    var update_prompt: bool = true;
    var input_c: [*c]u8 = null;

    _ = c.setlocale(c.LC_CTYPE, "");
    while (is_running) {
        if (update_prompt) {
            prompt = std.fmt.bufPrintZ(&buffer, "[ {s}:{s} ]{s} ", .{
                moe.src_lang.key,
                moe.trg_lang.key,
                config.prompt,
            }) catch brk: {
                break :brk "-> ";
            };

            update_prompt = false;
        }

        stdout.writeAll(config.separator ++ "\n") catch {};
        input_c = c.readline(prompt) orelse {
            return stdout.writeByte('\n');
        };

        defer std.c.free(input_c);

        // If `input` is empty
        if (input_c[0] == 0)
            continue;

        _ = c.add_history(input_c);
        moe.text = std.mem.span(input_c);

        getIntrResult(moe, &is_running, &update_prompt) catch |err| {
            stderr.print(
                Color.yellow.regular("Error: {s}") ++ "\n",
                .{@errorName(err)},
            ) catch {};
        };
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
                try parseLang(&moe, std.mem.span(argv[gopts.optind - 1]));
            },
            'f' => {
                moe.result_type = .detail;
                try parseLang(&moe, std.mem.span(argv[gopts.optind - 1]));
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

    if (moe.text.len > 0) {
        if (is_intrc) {
            printInfoIntr(&moe);
            stdout.writeAll(config.separator ++ "\n") catch {};
        }

        try moe.run();
    }

    if (is_intrc) {
        if (moe.text.len == 0)
            printInfoIntr(&moe);

        return inputIntr(&moe);
    }
}
