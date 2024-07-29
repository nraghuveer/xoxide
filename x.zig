// DB -> InMemory first and then sqlite
const std = @import("std");
const Allocator = std.mem.Allocator;
const dbLib = @import("db.zig");

// TODO: cli args
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const exe_path = try std.fs.selfExePathAlloc(allocator);
    defer allocator.free(exe_path);
    try start(allocator, exe_path);
}

fn start(allocator: Allocator, curWorkingDir: []const u8) !void {
    std.debug.print("starting at cur working director: {s}\n", .{curWorkingDir});
    const db = try newDB(allocator);
    defer db.deinit();
}

fn newDB(allocator: Allocator) !dbLib.DB {
    var inmem_db = try dbLib.InMemDB.init(allocator);
    return inmem_db.db();
}

test "dummy x.zig test" {
    try std.testing.expectEqual(1, 1);
}
