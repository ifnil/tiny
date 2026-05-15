const std = @import("std");

pub const TimeCollector = struct {
    m: std.ArrayList(f64) = .empty,

    pub fn init() TimeCollector {
        return .{};
    }

    pub fn deinit(self: *TimeCollector, alloc: std.mem.Allocator) void {
        self.m.deinit(alloc);
    }
};
