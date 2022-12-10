const std = @import("std");
const io = std.io;
const json = std.json;
const mem = std.mem;
const dprint = std.debug.print;

const http = @import("http.zig");
const Color = @import("color.zig").Color;

const config = @import("config.zig");
const lang = @import("lang.zig");
const url = @import("url.zig");
const util = @import("util.zig");

const stdout = io.getStdOut().writer();
const stderr = io.getStdErr().writer();

const Self = @This();

pub const Langs = struct {
    src: []const u8,
    trg: []const u8,
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

allocator: mem.Allocator,
json_tree: json.ValueTree,
output_mode: OutputMode,
result_type: url.UrlBuildType,
langs: Langs,
text: []const u8,

pub fn init(allocator: mem.Allocator) !Self {
    const langs = config.default_langs;
    comptime {
        if (!lang.has(langs.src))
            @compileError("config.zig: Unknown \"" ++ langs.src ++
                "\" language code\n");
        if (!lang.has(langs.trg))
            @compileError("config.zig: Unknown \"" ++ langs.trg ++
                "\" language code\n");
    }

    return Self{
        .allocator = allocator,
        .json_tree = undefined,
        .output_mode = config.default_output_mode,
        .result_type = config.default_result_type,
        .langs = langs,
        .text = "",
    };
}

pub fn run(self: *Self) !void {
    self.text = mem.trim(u8, self.text, " ");

    if (self.text.len == 0) {
        try stderr.writeAll("The text is empty!\n");
        return error.InvalidArgument;
    }

    if (self.text.len >= config.text_max_length) {
        try stderr.print("The text is too long!: {}\n", .{self.text.len});
        return error.NoSpaceLeft;
    }

    var response = brk: {
        var request = try url.buildRequest(
            self.allocator,
            self.result_type,
            self.langs.src,
            self.langs.trg,
            self.text,
        );
        defer self.allocator.free(request);

        var stream = try http.sendRequest(
            self.allocator,
            request,
            url.host,
            url.port,
        );
        defer stream.close();

        const buffer_size = (config.text_max_length * 3) + 128;
        break :brk try http.getResponse(self.allocator, &stream, buffer_size);
    };
    defer self.allocator.free(response);

    try self.print(try http.getJson(response));
}

fn print(self: *Self, json_str: []const u8) !void {
    return switch (self.output_mode) {
        .raw => stdout.print("{s}\n", .{json_str}),
        .parse => brk: {
            var jsp = json.Parser.init(self.allocator, false);
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
    // target spelling
    //     |
    // target lang
    //     |
    // synonyms
    //     |
    // definitions
    //     |
    // examples

    var result = try std.ArrayList(u8).initCapacity(self.allocator, 4096);
    defer result.deinit();
    defer stdout.writeAll(result.items) catch {};

    const rw = result.writer();
    const jsn = &self.json_tree.root.Array;
    const trg_txt = &jsn.items[0];
    const splls = &trg_txt.Array.items[trg_txt.Array.items.len - 1];

    // Source text
    try rw.print("\"{s}\"\n", .{self.text});

    // Correction
    const src_corr = jsn.items[7];
    if (src_corr == .Array and src_corr.Array.capacity > 0) {
        try rw.print(
            Color.yellow.regular("{s} \"") ++ "{s}" ++
                Color.yellow.regular("\" ?") ++ "\n",
            .{ "> Did you mean:", src_corr.Array.items[1].String },
        );
    }

    // Source spelling
    if (splls.Array.items.len > 3) {
        const src_spll = splls.Array.items[splls.Array.items.len - 1];
        if (src_spll == .String) {
            try rw.print(
                "( " ++ Color.yellow.regular("{s}") ++ " )\n",
                .{src_spll.String},
            );
        }
    }

    // Source lang
    const src_lang = jsn.items[2];
    try rw.print(
        Color.green.regular("[ {s} ]") ++ ": {s}\n\n",
        .{ src_lang.String, lang.getByKey(src_lang.String) },
    );

    // Target text
    const trg = jsn.items[0];
    for (trg.Array.items) |*v| {
        if (v.* == .Array and v.Array.items[0] == .String) {
            try rw.print("{s}", .{v.Array.items[0].String});
        }
    }

    try rw.writeByte('\n');

    // Target spelling
    if (splls.Array.items.len > 2) {
        const trg_spll = splls.Array.items[2];
        if (trg_spll == .String) {
            try rw.print(
                "( " ++ Color.yellow.regular("{s}") ++ " )\n",
                .{trg_spll.String},
            );
        }
    }

    // Target lang
    try rw.print(
        Color.green.regular("[ {s} ]") ++ ": {s}\n",
        .{ self.langs.trg, lang.getByKey(self.langs.trg) },
    );

    // Synonyms
    const synms = jsn.items[1];
    if (synms == .Array) {
        try rw.writeAll("\n" ++ config.separator);

        for (synms.Array.items) |*v| {
            // Verb, Nouns, etc
            if (v.Array.items[0].String.len == 0) {
                // No label
                // In some cases, there's no label at all.
                // I think for the sake of beauty we should give a label,
                // instead of printing an empty string.
                try rw.writeAll(
                    comptime "\n" ++ Color.blue.bold("[ + ]"),
                );
            } else {
                const va = v.Array.items[0].String;
                try rw.print(
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
                try rw.print(
                    "\n" ++ Color.white.bold("{}. {c}{s}") ++
                        "\n   " ++ Color.yellow.regular("-> "),
                    .{ ii + 1, std.ascii.toUpper(vaa[0]), vaa[1..] },
                );

                // Source Alt
                var src_synn_alt = vi.Array.items[1].Array.items.len - 1;
                for (vi.Array.items[1].Array.items) |*vii| {
                    try rw.print("{s}", .{vii.String});

                    if (src_synn_alt > 0) {
                        try rw.writeAll(", ");
                        src_synn_alt -= 1;
                    }
                }
            }
            try rw.writeByte('\n');
        }
    }

    // Definitions
    const defs = jsn.items[12];
    if (defs == .Array) {
        try rw.writeAll("\n" ++ config.separator);

        for (defs.Array.items) |*v| {
            if (v.Array.items[0].String.len == 0) {
                // No label
                try rw.writeAll(
                    comptime "\n" ++ Color.yellow.bold("[ + ]"),
                );
            } else {
                const va = v.Array.items[0].String;
                try rw.print(
                    "\n" ++ Color.yellow.bold("[ {c}{s} ]"),
                    .{ std.ascii.toUpper(va[0]), va[1..] },
                );
            }

            for (v.Array.items[1].Array.items) |*vi, ii| {
                if (ii == config.definition_max_lines) {
                    break;
                }

                const vaa = vi.Array.items[0].String;
                try rw.print(
                    "\n" ++ Color.white.bold("{}. {c}{s}"),
                    .{ ii + 1, std.ascii.toUpper(vaa[0]), vaa[1..] },
                );

                if (vi.Array.items.len > 3) {
                    const def_cre = vi.Array.items[vi.Array.items.len - 1];
                    if (def_cre == .Array) {
                        const ss = def_cre.Array.items[0];

                        if (ss == .Array and ss.Array.items[0] == .String) {
                            try rw.print(
                                Color.green.regular(" [ {s} ] ") ++ "",
                                .{ss.Array.items[0].String},
                            );
                        }
                    }
                }

                if (vi.Array.items.len > 2) {
                    const def_v = vi.Array.items[vi.Array.items.len - 1];
                    if (def_v == .String) {
                        try rw.print(
                            "\n" ++ Color.yellow.regular("   ->") ++ " {c}{s}",
                            .{
                                std.ascii.toUpper(def_v.String[0]),
                                def_v.String[1..],
                            },
                        );
                    }
                }
            }
            try rw.writeByte('\n');
        }
    }

    // Examples
    const exmpls = jsn.items[13];
    if (exmpls == .Array) {
        try rw.writeAll("\n" ++ config.separator ++ "\n");

        var tmp: [256]u8 = undefined;
        for (exmpls.Array.items) |*v| {
            for (v.Array.items) |*vi, ii| {
                if (ii == config.example_max_lines)
                    break;

                const vex = util.skipHtmlTags(&tmp, vi.Array.items[0].String);
                try rw.print(
                    "{}. " ++ Color.yellow.regular("{c}{s}") ++ "\n",
                    .{ ii + 1, std.ascii.toUpper(vex[0]), vex[1..] },
                );
            }
        }
    }
}

fn printDetectLang(self: *Self) !void {
    const jsn = self.json_tree.root.Array.items[2];

    if (jsn != .String)
        return;

    try stdout.print(
        "{s} ({s})\n",
        .{ jsn.String, lang.getByKey(jsn.String) },
    );
}
