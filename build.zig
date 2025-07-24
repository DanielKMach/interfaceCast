const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const install = b.getInstallStep();
    const test_lib = b.step("test", "Run unit tests");
    const run = b.step("run", "Run example");

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
    const install_lib = b.addInstallArtifact(lib, .{});
    install.dependOn(&install_lib.step);

    const tests = b.addTest(.{
        .root_module = module,
    });
    test_lib.dependOn(&tests.step);

    const example = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/example.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    example.root_module.addImport("interfaceCast", module);
    const run_example = b.addRunArtifact(example);
    run.dependOn(&run_example.step);
}
