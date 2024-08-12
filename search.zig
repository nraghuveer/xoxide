const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const DB = @import("db.zig").DB;
const utils = @import("utils.zig");

pub const Search = struct {
    ptr: *anyopaque,
    findFn: *const fn (ptr: *anyopaque, s: []const u8) anyerror!?[]const u8,

    pub fn find(self: Search, s: []const u8) !?[]const u8 {
        return self.findFn(self.ptr, s);
    }
};

pub const SimpleSearch = struct {
    db: DB,
    allocator: Allocator,

    pub fn init(allocator: Allocator, db: DB) !SimpleSearch {
        return .{
            .allocator = allocator,
            .db = db,
        };
    }

    pub fn search(self: *SimpleSearch) !Search {
        return .{
            .ptr = self,
            .findFn = find,
        };
    }

    pub fn find(ptr: *anyopaque, s: []const u8) !?[]const u8 {
        const self = utils.castToSelf(*SimpleSearch, ptr);
        var entries = try self.db.getAll();
        var winner_rank: ?f64 = null;
        var winner: ?[]const u8 = null;
        while (entries.next()) |entry| {
            const db_entry = entry.value_ptr.*;
            if (std.mem.indexOf(u8, db_entry.path, s) != null) {
                const ts: f64 = @floatFromInt(db_entry.latestTS);
                const f: f64 = @floatFromInt(db_entry.frequency);
                const cur_rank: f64 = (0.75 * ts) + (0.25 * f);
                if (winner_rank) |w| {
                    if (cur_rank > w) {
                        winner = db_entry.path;
                    }
                } else {
                    winner = db_entry.path;
                    winner_rank = cur_rank;
                }
            }
        }
        if (winner) |w| {
            return try self.allocator.dupe(u8, w);
        } else {
            return null;
        }
    }
};
