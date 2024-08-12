const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

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

    pub const Error = error{
        InvalidDBValue,
    };

    pub fn deinit(self: DB) void {
        return self.deinitFn(self.ptr);
    }

    fn put(self: DB, path: []const u8) !void {
        return self.putFn(self.ptr, path);
    }

    fn getAll(self: DB) !std.hash_map.StringHashMap(AccessEntry).Iterator {
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

    fn castToSelf(ptr: *anyopaque) *InMemDB {
        return @ptrCast(@alignCast(ptr));
    }

    pub fn deinit(ptr: *anyopaque) void {
        std.debug.print(">> executing deinit\n", .{});
        const self = castToSelf(ptr);
        defer self.hashmap.deinit();
        var it = self.hashmap.keyIterator();
        while (it.next()) |kv| {
            self.allocator.free(kv.*);
        }
    }

    fn put(ptr: *anyopaque, path: []const u8) anyerror!void {
        const self = castToSelf(ptr);
        // if there is already entry, just update the frequency
        if (self.hashmap.contains(path)) {
            if (self.hashmap.fetchRemove(path)) |kv| {
                // this is const copy, make a new one
                const dbEntry = kv.value;
                // question: where does the accessentry item is stored in memory?
                defer self.allocator.free(kv.key);

                var entry = try dbEntry.dupe(self.allocator);
                entry.frequency += 1;
                entry.latestTS = std.time.timestamp();
                try self.hashmap.put(entry.path, entry);
            } else {
                return DB.Error.InvalidDBValue;
            }
        } else {
            // allocate memory for key and also for path
            const k = try self.allocator.dupe(u8, path);
            const x = AccessEntry.new(k);
            try self.hashmap.put(k, x);
        }
    }

    fn getAll(ptr: *anyopaque) !std.hash_map.StringHashMap(AccessEntry).Iterator {
        const self = castToSelf(ptr);
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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var mem_db = try InMemDB.init(allocator);
    var db: DB = mem_db.db();
    defer db.deinit();

    // put and then get
    const PATH = "/home/rnaraharisetti/Code";
    try db.put(PATH);
    var entries = try db.getAll();
    var count: i32 = 0;
    while (entries.next()) |entry| {
        std.debug.print("{s}\n", .{entry.key_ptr.*});
        std.debug.print("{s}\n", .{entry.value_ptr.*.path});
        count += 1;
    }
    try testing.expectEqual(1, count);
}
