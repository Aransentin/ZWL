const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const softlogo = b.addExecutable("softlogo", "examples/softlogo.zig");
    softlogo.addPackagePath("zwl", "src/zwl.zig");
    softlogo.single_threaded = true;
    softlogo.subsystem = .Windows;
    softlogo.setTarget(target);
    softlogo.setBuildMode(mode);
    softlogo.install();

    const softlogo_run_cmd = softlogo.run();
    const softlogo_run_step = b.step("run-softlogo", "Run the softlogo example");
    softlogo_run_step.dependOn(&softlogo_run_cmd.step);
}
