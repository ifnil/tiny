const std = @import("std");
const tga = @import("../tgaimage.zig");
const Color = @import("../common.zig").Color;

pub const Triangle = struct {
    face: [3][3]@Vector(3, f32),
};

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

fn signedTriangleArea(ax: i32, ay: i32, bx: i32, by: i32, cx: i32, cy: i32) f32 {
    const a = (((by - ay) * (bx + ax)) + ((cy - by) * (cx + bx)) + ((ay - cy) * (ax + cx)));
    const b: f32 = @floatFromInt(a);
    return b;
}

fn signedTriangleAreaF(
    a: @Vector(3, f32),
    b: @Vector(3, f32),
    c: @Vector(3, f32),
) f32 {
    return (((b[1] - a[1]) * (b[0] + a[0])) + ((c[1] - b[1]) * (c[0] + b[0])) + ((a[1] - c[1]) * (a[0] + c[0])));
}

pub fn trianglev(
    a: @Vector(3, f32),
    b: @Vector(3, f32),
    c: @Vector(3, f32),
    zbuffer: *tga.TGAImage,
    framebuffer: *tga.TGAImage,
    color: tga.TGAColor,
) void {
    const bbminx: i32 = @intFromFloat(@floor(@min(@min(a[0], b[0]), c[0])));
    const bbminy: i32 = @intFromFloat(@floor(@min(@min(a[1], b[1]), c[1])));

    const bbmaxx: i32 = @intFromFloat(@ceil(@max(@max(a[0], b[0]), c[0])));
    const bbmaxy: i32 = @intFromFloat(@ceil(@max(@max(a[1], b[1]), c[1])));

    const total_area = signedTriangleAreaF(a, b, c);

    if (total_area < 1)
        return;

    var x = bbminx;
    while (x <= bbmaxx) : (x += 1) {
        var y = bbminy;
        while (y <= bbmaxy) : (y += 1) {
            const v: @Vector(3, f32) = .{
                @as(f32, @floatFromInt(x)) + 0.5,
                @as(f32, @floatFromInt(y)) + 0.5,
                0.0,
            };

            const alpha = signedTriangleAreaF(v, b, c) / total_area;
            const beta = signedTriangleAreaF(v, c, a) / total_area;
            const gamma = signedTriangleAreaF(v, a, b) / total_area;

            const fz: f32 = alpha * a[2] + beta * b[2] + gamma * c[2];
            const iz: i32 = @intFromFloat(@min((fz), 255));
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

            std.debug.print("\n", .{});
            std.debug.print("x: {}\n", .{x});
            std.debug.print("y: {}\n", .{y});

            std.debug.print("alpha: {}\n", .{alpha});
            std.debug.print("beta: {}\n", .{beta});
            std.debug.print("gamma: {}\n", .{gamma});

            const faz: f32 = @floatFromInt(az);
            const fbz: f32 = @floatFromInt(bz);
            const fcz: f32 = @floatFromInt(cz);

            const fz: f32 = alpha * faz + beta * fbz + gamma * fcz;
            const iz: i16 = @intFromFloat(@min(fz, 255));
            const z: u8 = if (iz < 0) 0 else @intCast(iz);

            std.debug.print("fz: {}\n", .{fz});
            std.debug.print("iz: {}\n", .{iz});
            std.debug.print("z: {}\n", .{z});

            if (alpha < 0 or beta < 0 or gamma < 0)
                continue;
            if (z <= zbuffer.get(x, y).get(2))
                continue;

            zbuffer.set(x, y, Color.bgra(z, z, z, z));
            framebuffer.set(x, y, color);
        }
    }
}
