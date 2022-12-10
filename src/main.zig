const std = @import("std");
const fmt = std.fmt;
const io = std.io;
const mem = std.mem;
const dprint = std.debug.print;
const getopt = @import("getopt");
const Linenoise = @import("linenoize").Linenoise;

const Moetranslate = @import("Moetranslate.zig");
const lang = @import("lang.zig");
const Color = @import("color.zig").Color;
const Langs = Moetranslate.Langs;
const OutputMode = Moetranslate.OutputMode;
const UrlBuildType = url.UrlBuildType;

const config = @import("config.zig");
const url = @import("url.zig");

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

fn printErr(comptime _fmt: []const u8, args: anytype) void {
    stderr.print(Color.red.regular(_fmt) ++ "\n", args) catch {};
}

fn printOut(comptime c: Color, comptime _fmt: []const u8, args: anytype) void {
    stdout.print(c.regular(_fmt) ++ "\n", args) catch {};
}

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
        "      0 = Brief\n" ++
        "      1 = Detail\n" ++
        "      2 = Detect Language\n\n" ++
        Color.white.bold("Change Output Mode:") ++ "\n" ++
        " /o [OUTPUT]\n" ++
        "     OUTPUT:\n" ++
        "      0 = Parse\n" ++
        "      1 = Raw\n\n" ++
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
            moe.langs.src,    moe.langs.trg,
            moe.result_type.str(), moe.output_mode.str(),
        }
    ) catch {};
}
// zig fmt: on

fn parseEnum(comptime T: type, arg: []const u8) !T {
    const _arg = mem.trim(u8, arg, " ");
    const num = fmt.parseUnsigned(u32, _arg, 10) catch {
        return error.InvalidArgument;
    };

    return switch (T) {
        OutputMode => return switch (num) {
            0 => .parse,
            1 => .raw,
            else => error.InvalidArgument,
        },
        UrlBuildType => return switch (num) {
            0 => .brief,
            1 => .detail,
            2 => .detect_lang,
            else => error.InvalidArgument,
        },
        else => error.InvalidArgument,
    };
}

fn parseLang(langs: *Langs, str: []const u8) !void {
    const sep = mem.indexOfScalar(u8, str, ':') orelse {
        return error.InvalidArgument;
    };

    const src = mem.trim(u8, str[0..sep], " ");
    if (src.len > 0) {
        langs.src = lang.getKeySlice(src) orelse {
            printErr("Unknown \"{s}\" language code", .{src});
            return;
        };
    }

    const trg = mem.trim(u8, str[sep + 1 ..], " ");
    if (trg.len > 0) {
        langs.trg = lang.getKeySlice(trg) orelse {
            printErr("Unknown \"{s}\" language code", .{trg});
            return;
        };
    }
}

fn getIntrResult(
    moe: *Moetranslate,
    is_running: *bool,
    update_prompt: *bool,
) !void {
    var cmd = moe.text;
    if (cmd[0] != '/') {
        stdout.writeAll(config.separator ++ "\n") catch {};

        // Let's GO!
        return moe.run();
    }

    cmd = mem.trim(u8, cmd, " ");

    if (cmd.len == 1)
        return printInfoIntr(moe);

    switch (cmd[1]) {
        'q' => {
            is_running.* = false;
        },
        'h' => {
            if (cmd.len != 2)
                return error.InvalidArgument;

            return printHelpIntr();
        },
        'c' => {
            update_prompt.* = true;
            return parseLang(&moe.langs, cmd[2..]);
        },
        's' => {
            if (cmd.len != 2)
                return error.InvalidArgument;

            mem.swap([]const u8, &moe.langs.src, &moe.langs.trg);
            update_prompt.* = true;
        },
        'o' => {
            moe.output_mode = try parseEnum(OutputMode, cmd[2..]);
            printOut(.green, "Output mode: {s}", .{moe.output_mode.str()});
        },
        'r' => {
            moe.result_type = try parseEnum(UrlBuildType, cmd[2..]);
            printOut(.green, "Result type: {s}", .{moe.result_type.str()});
        },
        else => return error.InvalidArgument,
    }
}

fn inputIntr(allocator: mem.Allocator, moe: *Moetranslate) !void {
    var is_running: bool = true;
    var buffer = try allocator.alloc(u8, 16 + config.prompt.len);
    defer allocator.free(buffer);

    var prompt: []const u8 = undefined;
    var update_prompt: bool = true;
    var line = Linenoise.init(allocator);
    defer line.deinit();

    while (is_running) {
        if (update_prompt) {
            prompt = fmt.bufPrint(buffer, "[ {s}:{s} ]{s} ", .{
                moe.langs.src,
                moe.langs.trg,
                config.prompt,
            }) catch brk: {
                break :brk "-> ";
            };

            update_prompt = false;
        }

        var prepare_input = line.linenoise(prompt) catch return;
        var input = prepare_input orelse {
            try stdout.writeByte('\n');
            return;
        };

        defer allocator.free(input);

        // If `input` is empty
        if (input.len == 0)
            continue;

        try line.history.add(input);

        moe.text = input;
        getIntrResult(moe, &is_running, &update_prompt) catch |err| {
            printErr("Error: {s}", .{@errorName(err)});
        };

        stdout.writeAll(config.separator ++ "\n") catch {};
    }
}

pub fn main() !void {
    var is_intrc = false;
    var argv: [][*:0]const u8 = undefined;
    var gopts = getopt.getopt("b:f:d:rih");

    if (gopts.argv.len == 1) {
        printHelp();
        return error.InvalidArgument;
    }

    var real_buffer: [config.buffer_max_length]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&real_buffer);
    const allocator = fba.allocator();
    var moe = try Moetranslate.init(allocator);

    while (true) {
        argv = gopts.argv;

        const opts = (try gopts.next()) orelse break;
        switch (opts.opt) {
            'b' => {
                moe.result_type = .brief;
                try parseLang(&moe.langs, mem.span(argv[gopts.optind - 1]));
            },
            'f' => {
                moe.result_type = .detail;
                try parseLang(&moe.langs, mem.span(argv[gopts.optind - 1]));
            },
            'd' => moe.result_type = .detect_lang,
            'r' => moe.output_mode = .raw,
            'i' => is_intrc = true,
            'h' => return printHelp(),
            else => return error.InvalidArgument,
        }
    }

    switch (moe.result_type) {
        .detect_lang => {
            moe.text = mem.span(argv[gopts.optind - 1]);
        },
        else => {
            if (gopts.optind < argv.len)
                moe.text = mem.span(argv[gopts.optind]);
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

        stdout.writeAll(config.separator ++ "\n") catch {};
        return inputIntr(allocator, &moe);
    }
}
