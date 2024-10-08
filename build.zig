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

    buildExample("ping", b, target, optimize);
    buildExample("embed", b, target, optimize);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/dysnomia.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

fn buildExample(
    comptime name: []const u8,
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const example = b.addExecutable(.{
        .name = name,
        .root_source_file = b.path("examples/" ++ name ++ ".zig"),
        .target = target,
        .optimize = optimize,
    });
    example.root_module.addImport("dysnomia", b.modules.get("dysnomia").?);
    const example_install = b.addInstallArtifact(example, .{});
    const example_step = b.step(name, "build the " ++ name ++ " example");
    example_step.dependOn(&example_install.step);
}
