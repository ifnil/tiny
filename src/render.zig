const std = @import("std");
const tga = @import("tgaimage.zig");
const Model = @import("model.zig").Model;
const common = @import("common.zig");

const WIDTH = common.WIDTH;
const HEIGHT = common.HEIGHT;

const Color = common.Color;
const Vec2 = common.Vector2;
const Vec3 = common.Vector3;

pub const Frame = struct {
    alloc: std.mem.Allocator,
    io: std.Io,
    frame: tga.TGAImage,
    width: usize,
    height: usize,

    pub fn new(alloc: std.mem.Allocator, io: std.Io, width: usize, height: usize) Frame {
        return .{
            .alloc = alloc,
            .io = io,
            .width = width,
            .height = height,
            .frame = tga.TGAImage.init(alloc, width, height, @intFromEnum(tga.Format.rgb)),
        };
    }

    pub fn set(self: *Frame, x: i32, y: i32, color: Color) void {
        self.frame.set(x, y, color);
    }

    pub fn commit(self: Frame, path: []const u8) !void {
        try self.frame.writeTgaFile(self.io, path, true, true);
    }
};

pub fn new(alloc: std.mem.Allocator, width: i32, height: i32) !tga.TGAImage {
    return tga.TGAImage.init(alloc, width, height, @intFromEnum(tga.Format.rgb));
}

pub fn project(v: Vec3) Vec3 {
    return Vec3.from(.{
        (v.x + 1.0) * WIDTH / 2.0,
        (v.y + 1.0) * HEIGHT / 2.0,
        (v.z + 1.0) * 255.0 / 2.0,
    });
}

pub fn line(
    ax: i32,
    ay: i32,
    bx: i32,
    by: i32,
    framebuffer: *tga.TGAImage,
    color: tga.TGAColor,
) void {
    var x0 = ax;
    var y0 = ay;
    var x1 = bx;
    var y1 = by;

    const steep = @abs(x0 - x1) < @abs(y0 - y1);
    if (steep) {
        std.mem.swap(i32, &x0, &y0);
        std.mem.swap(i32, &x1, &y1);
    }

    if (x0 > x1) {
        std.mem.swap(i32, &x0, &x1);
        std.mem.swap(i32, &y0, &y1);
    }

    var y: i32 = y0;
    var ierror: i32 = 0;

    var x: i32 = x0;
    while (x < x1) : (x += 1) {
        if (steep) {
            framebuffer.set(y, x, color);
        } else {
            framebuffer.set(x, y, color);
        }

        ierror += 2 * @as(i32, @intCast(@abs(y1 - y0)));
        y += (if (y1 > y0) @as(i32, 1) else @as(i32, -1)) * @as(i32, @intFromBool(ierror > x1 - x0));
        ierror -= 2 * (x1 - x0) * @as(i32, @intFromBool(ierror > x1 - x0));
    }
}

pub fn signedTriangleArea(
    ax: i32,
    ay: i32,
    bx: i32,
    by: i32,
    cx: i32,
    cy: i32,
) f32 {
    const a = (((by - ay) * (bx + ax)) + ((cy - by) * (cx + bx)) + ((ay - cy) * (ax + cx)));
    const b: f32 = @floatFromInt(a);

    return b;
}

pub fn triangle(
    ax: i32,
    ay: i32,
    az: i32,
    bx: i32,
    by: i32,
    bz: i32,
    cx: i32,
    cy: i32,
    cz: i32,
    zbuffer: *tga.TGAImage,
    framebuffer: *tga.TGAImage,
    color: tga.TGAColor,
) void {
    const bbminx: i32 = @min(@min(ax, bx), cx);
    const bbminy: i32 = @min(@min(ay, by), cy);
    const bbmaxx: i32 = @max(@max(ax, bx), cx);
    const bbmaxy: i32 = @max(@max(ay, by), cy);
    const total_area = signedTriangleArea(ax, ay, bx, by, cx, cy);

    // backface culling
    if (total_area < 1)
        return;

    var x = bbminx;
    while (x <= bbmaxx) : (x += 1) {
        var y = bbminy;
        while (y <= bbmaxy) : (y += 1) {
            const alpha = signedTriangleArea(x, y, bx, by, cx, cy) / total_area;
            const beta = signedTriangleArea(x, y, cx, cy, ax, ay) / total_area;
            const gamma = signedTriangleArea(x, y, ax, ay, bx, by) / total_area;

            const faz: f32 = @floatFromInt(az);
            const fbz: f32 = @floatFromInt(bz);
            const fcz: f32 = @floatFromInt(cz);

            const fz: f32 = alpha * faz + beta * fbz + gamma * fcz;
            // std.debug.print("fz: {d}  \t", .{fz});
            const iz: i16 = @intFromFloat(@min(fz, 255));
            const z: u8 = if (iz < 0) 0 else @intCast(iz);

            if (alpha < 0 or beta < 0 or gamma < 0)
                continue;
            if (z <= zbuffer.get(x, y).get(2))
                continue;

            // std.debug.print("z: {d}\n", .{z});
            zbuffer.set(x, y, Color.bgra(z, z, z, z));
            framebuffer.set(x, y, color);
        }
    }
}
