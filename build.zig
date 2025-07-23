const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const install = b.getInstallStep();
    const test_lib = b.step("test", "Run unit tests");

    const module = b.addModule("interfaceCast", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "interfaceCast",
        .root_module = module,
    });
    install.dependOn(&lib.step);

    const tests = b.addTest(.{
        .root_module = module,
    });
    test_lib.dependOn(&tests.step);
}
