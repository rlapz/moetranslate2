const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.build.Builder) void {
    const exe = b.addExecutable("moetranslate2", "src/main.zig");

    exe.target = b.standardTargetOptions(.{});
    exe.build_mode = b.standardReleaseOptions();
    exe.addPackage(.{
        .name = "getopt",
        .source = .{ .path = "./lib/zig-getopt/getopt.zig" },
    });
    exe.addPackage(.{
        .name = "linenoize",
        .source = .{ .path = "./lib/linenoize/src/main.zig" },
    });
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
