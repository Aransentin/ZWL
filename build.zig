const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const tests_step = b.step("tests", "Run all tests");
    const tests = b.addTest("src/zwl.zig");
    tests.setTarget(target);
    tests.setBuildMode(mode);
    tests_step.dependOn(&tests.step);

    const example_build_step = b.step("example", "Build the example");
    const example_exe = b.addExecutable("example", "example.zig");
    example_exe.addPackagePath("zwl", "src/zwl.zig");
    example_exe.single_threaded = true;
    example_exe.setTarget(target);
    example_exe.setBuildMode(mode);
    example_exe.linkLibC();

    example_exe.setOutputDir("zig-cache/bin");
    example_build_step.dependOn(&example_exe.step);

    const example_run_step = b.step("run", "Run the example");
    example_run_step.dependOn(&example_exe.run().step);
}
