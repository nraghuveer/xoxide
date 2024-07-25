const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{ .name = "xoxide", .target = target, .optimize = optimize, .root_source_file = b.path("x.zig") });
    b.installArtifact(exe);
}
