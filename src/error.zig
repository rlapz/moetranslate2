// MIT License
//
// Copyright (c) 2022 Arthur Lapz (rLapz)
//
// See LICENSE file for license details

const std = @import("std");

pub const Error = error{
    InvalidArgument,
    InvalidJSON,
    InvalidResponse,
    LangNotFound,
} || std.fmt.BufPrintError;
