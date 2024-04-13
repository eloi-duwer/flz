const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const flz = b.addExecutable(.{
        .name = "flz",
        .root_source_file = .{ .path = "src/flz.zig" },
        .target = target,
        .optimize = optimize,
    });
    link_system_libs(flz);
    const install_flz_step = b.addInstallArtifact(flz, .{});
    b.getInstallStep().dependOn(&install_flz_step.step);
    const run_cmd = b.addRunArtifact(flz);
    run_cmd.step.dependOn(&install_flz_step.step);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("flz", "Run flz");
    run_step.dependOn(&run_cmd.step);

    const flz_config = b.addExecutable(.{ .name = "flz-config", .root_source_file = .{ .path = "src/flz-config.zig" }, .target = target, .optimize = optimize });
    link_system_libs(flz_config);
    const install_flz_config_step = b.addInstallArtifact(flz_config, .{});
    b.getInstallStep().dependOn(&install_flz_config_step.step);
    const run_flz_cmd = b.addRunArtifact(flz_config);
    run_flz_cmd.step.dependOn(&install_flz_config_step.step);
    if (b.args) |args| {
        run_flz_cmd.addArgs(args);
    }
    const run_flz_step = b.step("flz-config", "Run the configurator");
    run_flz_step.dependOn(&run_flz_cmd.step);
}

fn link_system_libs(compile_step: *std.Build.Step.Compile) void {
    compile_step.linkSystemLibrary("X11");
    compile_step.linkSystemLibrary("Xfixes");
    compile_step.linkSystemLibrary("Xi");
    compile_step.linkSystemLibrary("Xft");
    compile_step.linkLibC();
}
