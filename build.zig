const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "dysnomia",
        .root_source_file = b.path("src/dysnomia.zig"),
        .target = target,
        .optimize = optimize,
    });
    const websocket = b.dependency("websocket", .{ .optimize = optimize, .target = target }).module("websocket");
    lib.root_module.addImport("websocket", websocket);
    b.installArtifact(lib);

    var dysnomia = b.addModule("dysnomia", .{
        .root_source_file = b.path("src/dysnomia.zig"),
        .optimize = optimize,
        .target = target,
    });
    dysnomia.addImport("websocket", websocket);

    buildExamples(b, target, optimize);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/dysnomia.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

fn buildExamples(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const ping = b.addExecutable(.{
        .name = "ping",
        .root_source_file = b.path("examples/ping.zig"),
        .target = target,
        .optimize = optimize,
    });
    ping.root_module.addImport("dysnomia", b.modules.get("dysnomia").?);
    const ping_step = b.step("ping", "build the ping example");
    ping_step.dependOn(&ping.step);
}
