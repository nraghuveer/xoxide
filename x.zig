// DB -> InMemory first and then sqlite

const std = @import("std");
const Allocator = std.mem.Allocator;
const dbLib = @import("db.zig");

// TODO: cli args
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    start(allocator, ".");
}

fn start(allocator: Allocator, curWorkingDir: []const u8) !void {
    std.debug.print("starting at cur working director: {s}\n", .{curWorkingDir});
    const db = newDB(allocator);
    defer db.deinit();
}

fn newDB(allocator: Allocator) !dbLib.DB {
    const db = dbLib.InMemDB.init(allocator);
    return db.Db();
}
