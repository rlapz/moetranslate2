const std = @import("std");

pub const Error = error{
    InvalidArgument,
    InvalidJSON,
    InvalidResponse,
    LangNotFound,
} || std.fmt.BufPrintError;
