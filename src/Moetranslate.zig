const std = @import("std");
const dprint = std.debug.print;

const Color = @import("color.zig").Color;
const config = @import("config.zig");
const Error = @import("error.zig").Error;
const Http = @import("Http.zig");
const Lang = @import("Lang.zig");
const url = @import("url.zig");
const util = @import("util.zig");

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();
var stdout_buffered = std.io.bufferedWriter(stdout);
const bstdout = stdout_buffered.writer();
const Self = @This();

pub const Langs = struct {
    src: *const Lang,
    trg: *const Lang,
};

pub const OutputMode = enum {
    parse,
    raw,

    pub fn str(self: @This()) []const u8 {
        return switch (self) {
            .parse => "Parse",
            .raw => "Raw",
        };
    }
};

// zig fmt: off
allocator  : std.mem.Allocator,
json_tree  : std.json.ValueTree,
output_mode: OutputMode,
result_type: url.UrlBuildType,
langs      : Langs,
text       : []const u8,

pub inline fn init(allocator: std.mem.Allocator) !Self {
    const _langs = config.default_langs;
    comptime var langs: Langs = .{
        .src = Lang.getByKey(_langs.src) catch |err| {
            @compileError("config.zig: Unknown \"" ++ _langs.src  ++
                          "\" language code: "     ++ @errorName(err) ++ "\n");
        },
        .trg = Lang.getByKey(_langs.trg) catch |err| {
            @compileError("config.zig: Unknown \"" ++ _langs.trg  ++
                          "\" language code: "     ++ @errorName(err) ++ "\n");
        },
    };


    return Self{
        .allocator   = allocator,
        .json_tree   = undefined,
        .output_mode = config.default_output_mode,
        .result_type = config.default_result_type,
        .langs       = langs,
        .text        = "",
    };
}
// zig fmt: on

pub fn run(self: *Self) !void {
    self.text = std.mem.trim(u8, self.text, " ");

    if (self.text.len == 0) {
        try stderr.writeAll("The text is empty!\n");
        return Error.InvalidArgument;
    }

    if (self.text.len >= config.text_max_length) {
        try stderr.print("The text is too long!: {}\n", .{self.text.len});
        return Error.NoSpaceLeft;
    }

    var http = try Http.init(self.allocator, url.host, url.port);
    defer http.deinit();

    var buffer = try self.allocator.alloc(u8, (config.text_max_length * 3) + 128);
    try http.sendRequest(
        url.buildRequest(
            buffer,
            self.result_type,
            self.langs.src.key,
            self.langs.trg.key,
            self.text,
        ) catch |err| switch (err) {
            Error.NoSpaceLeft => {
                try stderr.writeAll("The text is too long!\n");
                return err;
            },
            else => return err,
        },
    );

    self.allocator.free(buffer);

    try self.print(try http.getJson());
}

fn print(self: *Self, json_str: []const u8) !void {
    return switch (self.output_mode) {
        .raw => stdout.print("{s}\n", .{json_str}),
        .parse => brk: {
            var jsp = std.json.Parser.init(self.allocator, false);
            defer jsp.deinit();

            self.json_tree = try jsp.parse(json_str);
            defer self.json_tree.deinit();

            break :brk switch (self.result_type) {
                .brief => self.printBrief(),
                .detail => self.printDetail(),
                .detect_lang => self.printDetectLang(),
            };
        },
    };
}

fn printBrief(self: *Self) !void {
    const jsn = self.json_tree.root.Array.items[0];

    if (jsn == .Array) {
        for (jsn.Array.items) |*v| {
            if (v.* == .Array and v.Array.items[0] == .String) {
                try stdout.print("{s}", .{v.Array.items[0].String});
            }
        }

        try stdout.writeByte('\n');
    }
}

// zig fmt: off
fn printDetail(self: *Self) !void {
    // source text
    //     |
    // correction
    //     |
    // source spelling
    //     |
    // source lang
    //     |
    // target text
    //     |
    // target speling
    //     |
    // target lang
    //     |
    // synonyms
    //     |
    // definitions
    //     |
    // examples


    defer stdout_buffered.flush() catch {};

    const jsn     = self.json_tree.root.Array;
    const trg_txt = jsn.items[0];
    const splls   = trg_txt.Array.items[trg_txt.Array.items.len - 1];

    // Source text
    try bstdout.print("\"{s}\"\n", .{self.text});

    // Correction
    const src_corr = jsn.items[7];
    if (src_corr == .Array and src_corr.Array.capacity > 0) {
        try bstdout.print(
             Color.yellow.regular("{s} \"") ++ "{s}" ++
             Color.yellow.regular("\" ?")   ++ "\n",
            .{"> Did you mean:", src_corr.Array.items[1].String},
        );
    }

    // Source spelling
    if (splls.Array.items.len > 3) {
        const src_spll = splls.Array.items[splls.Array.items.len - 1];
        if (src_spll == .String) {
            try bstdout.print(
                "( " ++ Color.yellow.regular("{s}") ++ " )\n",
                .{src_spll.String},
            );
        }
    }

    // Source lang
    const src_lang = jsn.items[2];
    try bstdout.print(
         Color.green.regular("[ {s} ]") ++ ": {s}\n\n",
        .{ src_lang.String, Lang.getLangStr(src_lang.String) },
    );

    // Target text
    const trg = jsn.items[0];
    for (trg.Array.items) |*v| {
        if (v.* == .Array and v.Array.items[0] == .String) {
            try bstdout.print("{s}", .{v.Array.items[0].String});
        }
    }

    try bstdout.writeByte('\n');

    // Target spelling
    if (splls.Array.items.len > 2) {
        const trg_spll = splls.Array.items[2];
        if (trg_spll == .String) {
            try bstdout.print(
                "( " ++ Color.yellow.regular("{s}") ++ " )\n",
                .{trg_spll.String},
            );
        }
    }

    // Target lang
    try bstdout.print(
         Color.green.regular("[ {s} ]") ++ ": {s}\n",
        .{ self.langs.trg.key, Lang.getLangStr(self.langs.trg.key) },
    );

    // Synonyms
    const synms = jsn.items[1];
    if (synms == .Array) {
        try bstdout.writeAll("\n\n" ++ config.separator);

        for (synms.Array.items) |*v| {
            // Verb, Nouns, etc
            if (v.Array.items[0].String.len == 0) {
                // No label
                // In some cases, there's no label at all.
                // I think for the sake of beauty we should give a label,
                // instead of printing an empty string.
                try bstdout.writeAll(
                    "\n" ++ Color.blue.bold("[ + ]"),
                );
            } else {
                const va = v.Array.items[0].String;
                try bstdout.print(
                     "\n" ++ Color.blue.bold("[ {c}{s} ]"),
                    .{ std.ascii.toUpper(va[0]), va[1..] },
                );
            }

            // Target Alt
            for (v.Array.items[2].Array.items) |*vi, ii| {
                if (ii == config.synonym_max_lines) {
                    break;
                }

                const vaa = vi.Array.items[0].String;
                try bstdout.print(
                    "\n" ++ Color.white.bold("{}. {c}{s}") ++
                    "\n   " ++ Color.yellow.regular("-> "),
                    .{ ii + 1, std.ascii.toUpper(vaa[0]), vaa[1..] },
                );

                // Source Alt
                var src_synn_alt = vi.Array.items[1].Array.items.len - 1;
                for (vi.Array.items[1].Array.items) |*vii| {
                    try bstdout.print("{s}", .{vii.String});

                    if (src_synn_alt > 0) {
                        try bstdout.writeAll( ", ");
                        src_synn_alt -= 1;
                    }
                }
            }
            try bstdout.writeByte('\n');
        }
    } else {
            try bstdout.writeByte('\n');
    }

    // Definitions
    const defs = jsn.items[12];
    if (defs == .Array) {
        try bstdout.writeAll("\n" ++ config.separator);

        for (defs.Array.items) |*v| {
            if (v.Array.items[0].String.len == 0) {
                // No label
                try bstdout.writeAll(
                    "\n" ++ Color.yellow.bold("[ + ]"),
                );
            } else {
                const va = v.Array.items[0].String;
                try bstdout.print(
                    "\n" ++ Color.yellow.bold("[ {c}{s} ]"),
                    .{ std.ascii.toUpper(va[0]), va[1..] },
                );
            }

            for (v.Array.items[1].Array.items) |*vi, ii| {
                if (ii == config.definition_max_lines) {
                    break;
                }

                const vaa = vi.Array.items[0].String;
                try bstdout.print(
                    "\n" ++ Color.white.bold("{}. {c}{s}"),
                    .{ ii + 1, std.ascii.toUpper(vaa[0]), vaa[1..] },
                );

                if (vi.Array.items.len > 3) {
                    const def_cre = vi.Array.items[vi.Array.items.len - 1];
                    if (def_cre == .Array) {
                        const ss = def_cre.Array.items[0];

                        if (ss == .Array and ss.Array.items[0] == .String) {
                            try bstdout.print(
                                Color.green.regular(" [ {s} ] ") ++ "",
                                .{ss.Array.items[0].String}
                            );
                        }
                    }
                }

                if (vi.Array.items.len > 2) {
                    const def_v = vi.Array.items[vi.Array.items.len - 1];
                    if (def_v == .String) {
                        try bstdout.print(
                            "\n" ++ Color.yellow.regular("   ->") ++ " {c}{s}",
                            .{
                                std.ascii.toUpper(def_v.String[0]),
                                def_v.String[1..]
                            }
                        );
                    }
                }
            }
            try bstdout.writeByte('\n');
        }
    } else {
            try bstdout.writeByte('\n');
    }

    // Examples
    const exmpls = jsn.items[13];
    if (exmpls == .Array) {
        try bstdout.writeAll("\n" ++ config.separator ++ "\n");

        var tmp: [256]u8 = undefined;

        for (exmpls.Array.items) |*v| {
            for (v.Array.items) |*vi, ii| {
                if (ii == config.example_max_lines)
                    break;

                const vex = util.skipHtmlTags(&tmp, vi.Array.items[0].String);
                try bstdout.print(
                    "{}. " ++ Color.yellow.regular("{c}{s}") ++ "\n",
                    .{ ii + 1, std.ascii.toUpper(vex[0]), vex[1..] },
                );
            }
            try bstdout.writeByte('\n');
        }
    } else {
            try bstdout.writeByte('\n');
    }
}

fn printDetectLang(self: *Self) !void {
    const jsn = self.json_tree.root.Array.items[2];

    if (jsn != .String)
        return;

    try stdout.print(
        "{s} ({s})\n",
        .{ jsn.String, Lang.getLangStr(jsn.String) },
    );
}
// zig fmt: on

test "run" {
    var moe = try init(std.testing.allocator);
    defer moe.allocator.free(moe.buffer);

    //moe.result_type = .brief;
    moe.text = "hello";

    try moe.run();
}
