const std = @import("std");
const tga = @import("../tgaimage.zig");

const Vec3 = @import("../common.zig").Vec3;
const Color = @import("../common.zig").Color;

pub fn line(ax: i32, ay: i32, bx: i32, by: i32, framebuffer: *tga.TGAImage, color: tga.TGAColor) void {
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

// total area of triangle
fn signedTriangleArea(a: Vec3, b: Vec3, c: Vec3) f32 {
    return (((b[1] - a[1]) * (b[0] + a[0])) + ((c[1] - b[1]) * (c[0] + b[0])) + ((a[1] - c[1]) * (a[0] + c[0])));
}

pub fn triangle(
    a: Vec3,
    b: Vec3,
    c: Vec3,
    zbuffer: *tga.TGAImage,
    framebuffer: *tga.TGAImage,
    color: tga.TGAColor,
) void {
    // bounding box
    const bbminx: i32 = @intFromFloat(@floor(@min(@min(a[0], b[0]), c[0])));
    const bbminy: i32 = @intFromFloat(@floor(@min(@min(a[1], b[1]), c[1])));
    const bbmaxx: i32 = @intFromFloat(@ceil(@max(@max(a[0], b[0]), c[0])));
    const bbmaxy: i32 = @intFromFloat(@ceil(@max(@max(a[1], b[1]), c[1])));

    // calculate the total area of the triangle
    const total_area = signedTriangleArea(a, b, c);

    // discard triangles that are too small
    if (total_area < 1)
        return;

    // depth interpolation:
    //
    // for each triangle t
    //  for each pixel p that t covers
    //      compute it's depth z
    //      if depth buffer at p < z
    //          update the depth buffer
    //          paint the pixel
    var x = bbminx;
    while (x <= bbmaxx) : (x += 1) {
        var y = bbminy;
        while (y <= bbmaxy) : (y += 1) {

            // for convenience
            const v: Vec3 = .{
                @as(f32, @floatFromInt(x)) + 0.5,
                @as(f32, @floatFromInt(y)) + 0.5,
                0.0,
                1.0,
            };

            const alpha = signedTriangleArea(v, b, c) / total_area;
            const beta = signedTriangleArea(v, c, a) / total_area;
            const gamma = signedTriangleArea(v, a, b) / total_area;

            if (alpha < 0 or beta < 0 or gamma < 0)
                continue; // negative bayercentric coordinate; the pixel is outside; discard

            const fz: f32 = alpha * a[2] + beta * b[2] + gamma * c[2];
            const iz: i32 = @intFromFloat(@min((fz), 255));
            const z: u8 = if (iz < 0) 0 else @intCast(iz);

            if (z <= zbuffer.get(x, y).get(0))
                continue;

            zbuffer.set(x, y, Color.bgra(z, z, z, z));
            framebuffer.set(x, y, color);
        }
    }
}

fn signedTriangleAreaSI(ax: i32, ay: i32, bx: i32, by: i32, cx: i32, cy: i32) f32 {
    const a: i32 = (((by - ay) * (bx + ax)) + ((cy - by) * (cx + bx)) + ((ay - cy) * (ax + cx)));
    const b: f32 = @floatFromInt(a);
    return b;
}

pub fn triangleSI(
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
    const total_area = signedTriangleAreaSI(ax, ay, bx, by, cx, cy);

    // backface culling
    if (total_area < 1)
        return;

    var x = bbminx;
    while (x <= bbmaxx) : (x += 1) {
        var y = bbminy;
        while (y <= bbmaxy) : (y += 1) {
            const alpha = signedTriangleAreaSI(x, y, bx, by, cx, cy) / total_area;
            const beta = signedTriangleAreaSI(x, y, cx, cy, ax, ay) / total_area;
            const gamma = signedTriangleAreaSI(x, y, ax, ay, bx, by) / total_area;

            const faz: f32 = @floatFromInt(az);
            const fbz: f32 = @floatFromInt(bz);
            const fcz: f32 = @floatFromInt(cz);

            const fz: f32 = alpha * faz + beta * fbz + gamma * fcz;
            const iz: i16 = @intFromFloat(@min(fz, 255));
            const z: u8 = if (iz < 0) 0 else @intCast(iz);

            if (alpha < 0 or beta < 0 or gamma < 0)
                continue;
            if (z <= zbuffer.get(x, y).get(2))
                continue;

            zbuffer.set(x, y, Color.bgra(z, z, z, z));
            framebuffer.set(x, y, color);
        }
    }
}
