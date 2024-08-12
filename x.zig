// DB -> InMemory first and then sqlite
const std = @import("std");
const Allocator = std.mem.Allocator;
const dbLib = @import("db.zig");
const searchLib = @import("search.zig");

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
    var db = try newDB(allocator);
    defer db.deinit();

    const PATH = "/home/rnaraharisetti/Code";
    try db.put(PATH);

    var search = try newSearch(allocator, db);
    if (try search.find("setti")) |r| {
        std.debug.print("result is {s}", .{r});
    } else {
        std.debug.print("not found", .{});
    }
}

fn newDB(allocator: Allocator) !dbLib.DB {
    var inmem_db = try dbLib.InMemDB.init(allocator);
    return inmem_db.db();
}

fn newSearch(allocator: Allocator, db: dbLib.DB) !searchLib.Search {
    var simple_search = try searchLib.SimpleSearch.init(allocator, db);
    return try simple_search.search();
}

test "dummy x.zig test" {
    try std.testing.expectEqual(1, 1);
}
