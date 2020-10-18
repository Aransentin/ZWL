const std = @import("std");
const builtin = @import("builtin");
const zwl = @import("zwl.zig");
const Allocator = std.mem.Allocator;

pub fn Platform(comptime Parent: anytype) type {
    return struct {
        const Self = @This();
        allocator: *Allocator,

        pub fn init(allocator: *Allocator, options: zwl.PlatformOptions) !*Self {
            var self = try allocator.create(Self);
            errdefer allocator.destroy(self);
            self.* = Self{
                .allocator = allocator,
            };
            return self;
        }
        pub fn deinit(self: *Self) void {
            self.allocator.destroy(self);
        }
    };
}
