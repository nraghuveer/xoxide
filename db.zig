const std = @import("std");
const Allocator = std.mem.Allocator;

// TODO: not memory safe
pub const AccessEntry = struct {
    path: []const u8,
    latest: std.time.Time,
    frequency: i32,

    fn new(path: []const u8) AccessEntry {
        return .{ .path = path, .latest = std.time.Time.now(), .frequency = 1 };
    }
};

pub const DB = struct {
    ptr: *anyopaque,
    putFn: *const fn (ptr: *anyopaque, path: []const u8) anyerror!DB.Error!void,
    getAllFn: *const fn (ptr: *anyopaque) anyerror!DB.Error!std.hash_map.StringHashMap(*const AccessEntry).ValueIterator,
    deinit: *const fn (ptr: *anyopaque) void,

    pub const Error = error{
        InvalidDBValue,
    };

    fn put(self: DB, path: []const u8) !DB.Error!void {
        return self.putFn(self.ptr, path);
    }

    fn getAll(self: DB) !DB.Error!std.hash_map.StringHashMap(*const AccessEntry).ValueIterator {
        return self.getAllFn(self.ptr);
    }
};

pub const InMemDB = struct {
    hashmap: std.hash_map.StringHashMap(*const AccessEntry),
    allocator: Allocator,

    pub fn init(allocator: Allocator) !InMemDB {
        return .{
            .hash_map = std.hash_map.StringHashMap(*const AccessEntry).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InMemDB) void {
        defer self.hashmap.deinit();
        var it = self.hashmap.keyIterator();
        while (it.next()) |kv| {
            self.allocator.free(kv.*);
        }
    }

    fn put(self: *InMemDB, path: []const u8) !DB.Error!void {
        // if there is already entry, just update the frequency
        if (self.hashmap.contains(path)) {
            if (self.hashmap.get(path)) |dbEntry| {
                dbEntry.*.frequency += 1;
                dbEntry.latest = std.time.Time.now();
            } else {
                return DB.Error.InvalidDBValue;
            }
        } else {
            // allocate memory for key and also for path
            const k = self.allocator.dupe(u8, path);
            self.hashmap.put(k, AccessEntry.new(k));
        }
    }

    fn getAll(self: *InMemDB) !DB.Error!std.hash_map.StringHashMap(*const AccessEntry).ValueIterator {
        return self.hashmap.valueIterator();
    }

    pub fn Db(self: *InMemDB) DB {
        return .{
            .ptr = self,
            .putFn = put,
            .getAllFn = getAll,
            .deinit = deinit,
        };
    }
};
