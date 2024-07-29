const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "xoxide",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("x.zig"),
    });
    b.installArtifact(exe);

    // basic arg-less run
    const run_cmd = b.addRunArtifact(exe);
    // tie run command to run command
    run_cmd.step.dependOn(b.getInstallStep());

    // tie run step to run command
    const run_step = b.step("run", "start the program");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "run the tests");
    const test_files: [2][]const u8 = [_][]const u8{ "db.zig", "x.zig" }; // Added "x.zig" to the array
    for (test_files) |test_file| { // Use pointer to iterate over the array
        const test_obj = b.addTest(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path(test_file),
        });
        const test_cmd = b.addRunArtifact(test_obj);
        test_cmd.step.dependOn(b.getInstallStep());
        test_step.dependOn(&test_cmd.step);
        // test_step.dependOn(&test_obj.step);
    }
}
