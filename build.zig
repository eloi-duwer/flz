const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const flz = b.addExecutable(.{
        .name = "flz",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/flz.zig" },
        .target = target,
        .optimize = optimize,
    });
    flz.linkSystemLibrary("X11");
    flz.linkSystemLibrary("Xfixes");
    flz.linkSystemLibrary("Xi");
    flz.linkLibC();
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
    flz_config.linkSystemLibrary("X11");
    flz_config.linkSystemLibrary("Xfixes");
    flz_config.linkSystemLibrary("Xi");
    flz_config.linkLibC();
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
