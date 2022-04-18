// MIT License
//
// Copyright (c) 2022 Arthur Lapz (rLapz)
//
// See LICENSE file for license details

const builtin = @import("builtin");
const UrlBuildType = @import("Url.zig").UrlBuildType;
const OutputMode = @import("Moetranslate.zig").OutputMode;
const maxInt = @import("std").math.maxInt(u8);

// see: `Lang.zig`
pub const default_src_lang = "auto";
pub const default_trg_lang = "en";

// Opts: .parse, .raw
pub const default_output_mode: OutputMode = .parse;
// Opts: .detail, .brief, .detect_lang
pub const default_result_type: UrlBuildType = .detail;

// use color?
pub const color = true;

pub const prompt = "->"; // Interactive
pub const synonym_max_lines: usize = maxInt;
pub const definition_max_lines: usize = maxInt;
pub const example_max_lines: usize = maxInt;
pub const text_max_length: usize = 4096;
pub const buffer_max_length: usize = 1024 * 512; // 512k
