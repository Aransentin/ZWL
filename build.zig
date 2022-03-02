const std = @import("std");
const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;
const Mode = std.builtin.Mode;
// const deps = @import("./deps.zig");

fn buildSoftlogo(b: *Builder, target: CrossTarget, mode: Mode) void {
    const softlogo = b.addExecutable("softlogo", "examples/softlogo.zig");
    // deps.addAllTo(softlogo);
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

fn buildWayland(b: *Builder, target: CrossTarget, mode: Mode) void {
    const wayland = b.addExecutable("wayland", "examples/wayland.zig");
    wayland.setTarget(target);
    wayland.setBuildMode(mode);
    wayland.addPackagePath("zwl", "src/zwl.zig");
    wayland.install();

    const wayland_run_cmd = wayland.run();
    const wayland_run_step = b.step("run-wayland", "Run the wayland example");
    wayland_run_step.dependOn(&wayland_run_cmd.step);
}

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    buildWayland(b, target, mode);
    buildSoftlogo(b, target, mode);
}
