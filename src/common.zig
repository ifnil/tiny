const std = @import("std");

pub const tga = @import("tgaimage.zig");

// pub const Vector3 = [3]f32;
pub const Vector2 = [2]f32;
pub const Vector3 = V3;

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

pub const V3 = extern struct {
    x: f32,
    y: f32,
    z: f32,

    pub inline fn new(x: f32, y: f32, z: f32) V3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub inline fn v(self: V3) @Vector(3, f32) {
        return .{ self.x, self.y, self.z };
    }

    pub inline fn from(vec: @Vector(3, f32)) V3 {
        return .{
            .x = vec[0],
            .y = vec[1],
            .z = vec[2],
        };
    }
};
