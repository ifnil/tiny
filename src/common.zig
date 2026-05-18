const std = @import("std");
const tga = @import("tgaimage.zig");

// exports
// pub const Vector3 = [3]f32;
pub const Vector2 = [2]f32;
pub const Vector3 = V3(f32);

pub const WIDTH = 800;
pub const HEIGHT = 800;

pub const Color = struct {
    pub const white: tga.TGAColor = .{ .bgra = .{ 255, 255, 255, 255 }, .bytespp = 4 };
    pub const green: tga.TGAColor = .{ .bgra = .{ 0, 255, 0, 255 }, .bytespp = 4 };
    pub const red: tga.TGAColor = .{ .bgra = .{ 0, 0, 255, 255 }, .bytespp = 4 };
    pub const blue: tga.TGAColor = .{ .bgra = .{ 255, 128, 64, 255 }, .bytespp = 4 };
    pub const yellow: tga.TGAColor = .{ .bgra = .{ 0, 200, 255, 255 }, .bytespp = 4 };

    pub fn bgra(b: u8, g: u8, r: u8, a: u8) tga.TGAColor {
        return .{ .bgra = .{ b, g, r, a }, .bytespp = 4 };
    }

    pub fn rgba(r: u8, g: u8, b: u8, a: u8) tga.TGAColor {
        return .{ .bgra = .{ b, g, r, a }, .bytespp = 4 };
    }

    pub fn rgb(r: u8, g: u8, b: u8) tga.TGAColor {
        return .{
            .bgra = .{ b, g, r, std.math.maxInt(u8) },
            .bytespp = 4,
        };
    }
};

// TODO: downward comptime casting to new type?
fn V3(comptime T: type) type {
    return extern struct {
        const Self = @This();

        x: T,
        y: T,
        z: T,

        pub inline fn new(x: T, y: T, z: T) @This() {
            return .{ .x = x, .y = y, .z = z };
        }

        pub inline fn toVec(self: Self) @Vector(3, T) {
            return .{ self.x, self.y, self.z };
        }

        pub inline fn as(self: Self, comptime P: type) V3(P) {
            std.debug.print("typeof P: {}\n", .{@TypeOf(P)});
            if (P == comptime_int) {
                const x = @as(P, @intCast(self.x));
                const y = @as(P, @intCast(self.y));
                const z = @as(P, @intCast(self.z));

                return V3(P).new(x, y, z);
            }

            if (P == comptime_float) {
                const x = @as(P, @intCast(self.x));
                const y = @as(P, @intCast(self.y));
                const z = @as(P, @intCast(self.z));

                return V3(P).new(x, y, z);
            }
            return V3(P).new(0, 0, 0);
        }

        pub inline fn from(vec: @Vector(3, f32)) Self {
            return .{
                .x = vec[0],
                .y = vec[1],
                .z = vec[2],
            };
        }

        pub inline fn mult(self: Self, a: comptime_int) Self {
            return .{
                .x = self.x * a,
                .y = self.y * a,
                .z = self.x * a,
            };
        }

        pub inline fn mutMult(self: *Self, a: comptime_int) void {
            self.x *= a;
            self.y *= a;
            self.z *= a;
        }

        pub inline fn add(self: Self, a: comptime_int) Self {
            return .{
                .x = self.x + a,
                .y = self.y + a,
                .z = self.x + a,
            };
        }

        pub inline fn mutAdd(self: *Self, a: comptime_int) void {
            self.x += a;
            self.y += a;
            self.z += a;
        }

        pub inline fn sub(self: Self, a: comptime_int) Self {
            return .{
                .x = self.x - a,
                .y = self.y - a,
                .z = self.z - a,
            };
        }

        pub inline fn mutSub(self: *Self, a: comptime_int) void {
            self.x -= a;
            self.y -= a;
            self.z -= a;
        }
    };
}

test "vec3" {
    var tv = V3(i32).new(1, 1, 1);

    const x = tv.toVec();
    std.debug.print("x: {}\n", .{x});
    std.debug.print("x: {}\n", .{x[1]});

    const c = tv.mult(2);
    std.debug.print("c: {}\n", .{c});

    tv.mutMult(3);
    std.debug.print("tv: {}\n", .{tv});

    const b = c.as(f32);
    std.debug.print("b: {}\n", .{b});
}
