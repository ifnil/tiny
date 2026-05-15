const std = @import("std");

pub const Vector3 = V3(f32);

fn V2(comptime T: type) type {
    return extern struct {
        x: T,
        y: T,

        pub inline fn new(x: T, y: T) @This() {
            return .{ .x = x, .y = y };
        }

        pub inline fn v(self: V3) @Vector(2, T) {
            return .{ self.x, self.y };
        }

        pub inline fn from(vec: @Vector(2, f32)) @This() {
            return .{
                .x = vec[0],
                .y = vec[1],
            };
        }
    };
}

fn V3(comptime T: type) type {
    return extern struct {
        x: T,
        y: T,
        z: T,

        const Self = @This();
        pub inline fn new(x: T, y: T, z: T) Self {
            return .{ .x = x, .y = y, .z = z };
        }

        pub inline fn v(self: Self) @Vector(3, T) {
            return .{ self.x, self.y, self.z };
        }

        pub inline fn from(vec: @Vector(3, f32)) Self {
            return .{
                .x = vec[0],
                .y = vec[1],
                .z = vec[2],
            };
        }
    };
}
