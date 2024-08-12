const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const utils = @import("utils.zig");

// TODO: not memory safe
pub const AccessEntry = struct {
    path: []const u8,
    latestTS: i64,
    frequency: i32,

    fn new(path: []const u8) AccessEntry {
        return .{ .path = path, .latestTS = std.time.timestamp(), .frequency = 1 };
    }

    fn dupe(entry: *const AccessEntry, allocator: Allocator) !AccessEntry {
        return .{
            .path = try allocator.dupe(u8, entry.path),
            .frequency = entry.frequency,
            .latestTS = entry.latestTS,
        };
    }
};

pub const DB = struct {
    ptr: *anyopaque,
    putFn: *const fn (ptr: *anyopaque, path: []const u8) anyerror!void,
    getAllFn: *const fn (ptr: *anyopaque) anyerror!std.hash_map.StringHashMap(AccessEntry).Iterator,
    deinitFn: *const fn (ptr: *anyopaque) void,

    pub fn deinit(self: DB) void {
        return self.deinitFn(self.ptr);
    }

    pub fn put(self: DB, path: []const u8) !void {
        return self.putFn(self.ptr, path);
    }

    pub fn getAll(self: DB) !std.hash_map.StringHashMap(AccessEntry).Iterator {
        return self.getAllFn(self.ptr);
    }
};

pub const InMemDB = struct {
    hashmap: std.hash_map.StringHashMap(AccessEntry),
    allocator: Allocator,

    pub fn init(allocator: Allocator) !InMemDB {
        return .{
            .hashmap = std.hash_map.StringHashMap(AccessEntry).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(ptr: *anyopaque) void {
        const self = utils.castToSelf(*InMemDB, ptr);
        defer self.hashmap.deinit();
        var it = self.hashmap.keyIterator();
        while (it.next()) |kv| {
            self.allocator.free(kv.*);
        }
    }

    fn put(ptr: *anyopaque, path: []const u8) anyerror!void {
        const self = utils.castToSelf(*InMemDB, ptr);
        // if there is already entry, just update the frequency
        if (self.hashmap.contains(path)) {
            if (self.hashmap.getPtr(path)) |e| {
                e.*.frequency += 1;
                e.*.latestTS = std.time.timestamp();
            } else {
                unreachable;
            }
        } else {
            // allocate memory for key and also for path
            const k = try self.allocator.dupe(u8, path);
            const x = AccessEntry.new(k);
            try self.hashmap.put(k, x);
        }
    }

    fn getAll(ptr: *anyopaque) !std.hash_map.StringHashMap(AccessEntry).Iterator {
        const self = utils.castToSelf(*InMemDB, ptr);
        return self.hashmap.iterator();
    }

    pub fn db(self: *InMemDB) DB {
        return .{
            .ptr = self,
            .putFn = put,
            .getAllFn = getAll,
            .deinitFn = deinit,
        };
    }
};

test "InMemDB simple put and get same" {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = gpa.allocator();
    const allocator = std.testing.allocator;
    var mem_db = try InMemDB.init(allocator);
    var db: DB = mem_db.db();
    defer db.deinit();

    // put and then get
    const PATH = "/home/rnaraharisetti/Code";
    try db.put(PATH);
    var entries = try db.getAll();
    var count: i32 = 0;
    while (entries.next()) |entry| {
        const db_entry = entry.value_ptr.*;
        try testing.expectEqual(1, db_entry.frequency);
        try testing.expect(db_entry.latestTS <= std.time.timestamp());
        count += 1;
    }
    try testing.expectEqual(1, count);
}

test "InMemDB put on existing" {
    const allocator = std.testing.allocator;
    var mem_db = try InMemDB.init(allocator);
    var db: DB = mem_db.db();
    defer db.deinit();

    const PATH = "/home/rnaraharisetti/Code";
    try db.put(PATH);
    try db.put(PATH);
    var entries = try db.getAll();
    var count: i32 = 0;
    while (entries.next()) |entry| {
        const db_entry = entry.value_ptr.*;
        try testing.expectEqual(2, db_entry.frequency);
        try testing.expect(db_entry.latestTS <= std.time.timestamp());
        count += 1;
    }
    try testing.expectEqual(1, count);
}
