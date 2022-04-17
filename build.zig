const std = @import("std");
const builtin = @import("builtin");

// zig fmt: off
pub fn build(b: *std.build.Builder) void {
    const exe = b.addExecutable("moetranslate2", "src/main.zig");

    exe.target     = b.standardTargetOptions(.{});
    exe.build_mode = b.standardReleaseOptions();

    if (builtin.os.tag != .windows) {
        exe.linkSystemLibraryName("edit");
        exe.linkLibC();
    }

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
