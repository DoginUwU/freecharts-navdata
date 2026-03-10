const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "freecharts_navdata",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });

    exe.linkLibC();

    exe.addIncludePath(b.path("./lib/sqlite"));
    exe.addCSourceFile(.{
        .file = b.path("./lib/sqlite/sqlite3.c"),
        .flags = &[_][]const u8{},
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .name = "freecharts_navdata_test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("./src/tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const install_tests = b.addInstallArtifact(exe_tests, .{});
    const build_test_step = b.step("build-test", "Build tests without running");
    build_test_step.dependOn(&install_tests.step);

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
