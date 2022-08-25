const builtin = @import("builtin");
const UrlBuildType = @import("url.zig").UrlBuildType;
const OutputMode = @import("Moetranslate.zig").OutputMode;
const maxInt = @import("std").math.maxInt(u8);

// see: `Lang.zig`
pub const default_langs = .{
    .src = "auto",
    .trg = "en",
};

// Opts: .parse, .raw
pub const default_output_mode: OutputMode = .parse;
// Opts: .detail, .brief, .detect_lang
pub const default_result_type: UrlBuildType = .detail;

// use color?
pub const color = true;

pub const separator = "-------------------------";
pub const prompt = "->"; // Interactive
//
pub const synonym_max_lines = maxInt;
pub const definition_max_lines = maxInt;
pub const example_max_lines = maxInt;
pub const text_max_length = 4096;
pub const buffer_max_length = 1024 * 512; // 512k
