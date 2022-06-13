const std = @import("std");
const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;
const Mode = std.builtin.Mode;
const FileSource = std.build.FileSource;
const Pkg = std.build.Pkg;


fn buildSoftlogo(b: *Builder, target: CrossTarget, mode: Mode) void {
    const softlogo = b.addExecutable("softlogo", "examples/softlogo.zig");
    const win32 = Pkg{ .name = "win32", .source = FileSource.relative("libs/zigwin32/win32.zig") };
    const zwl = Pkg{ .name = "zwl", .source = FileSource.relative("src/zwl.zig"), .dependencies = &.{win32} };
    softlogo.addPackage(win32);
    softlogo.addPackage(zwl);
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

    if (target.isWindows()) {
        buildSoftlogo(b, target, mode);
    } else if (target.isLinux()) {
        buildWayland(b, target, mode);
    }
}
