const std = @import("std");

const examples = .{
    .{
        .name = "iterator",
        .path = "examples/iterator.zig",
        .args = &.{ "hello", "world" },
    },
    .{
        .name = "player",
        .path = "examples/player.zig",
    },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const install = b.getInstallStep();
    const test_lib = b.step("test", "Run unit tests");
    const run = b.step("ex", "Run examples");

    const target_example = b.option([]const u8, "example", "Select a specific example to run, leave empty to run all");

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

    inline for (examples) |ex| {
        if (target_example == null or std.mem.eql(u8, target_example.?, ex.name)) {
            const run_ex = compileExample(b, ex, module, target, optimize);
            run.dependOn(&run_ex.step);
        }
    }
}

fn compileExample(
    b: *std.Build,
    config: anytype,
    module: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Run {
    const example = b.addExecutable(.{
        .name = config.name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(config.path),
            .target = target,
            .optimize = optimize,
        }),
    });
    example.root_module.addImport("interfaceCast", module);
    const run_example = b.addRunArtifact(example);
    if (@hasField(@TypeOf(config), "args")) {
        run_example.addArgs(config.args);
    }
    return run_example;
}
