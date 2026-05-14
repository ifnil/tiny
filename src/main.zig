const std = @import("std");
const tga = @import("tgaimage.zig");
const model = @import("model.zig");
const common = @import("common.zig");

const Vec2 = common.Vector2;
const Vec3 = common.Vector3;
const Model = model.Model;
const Vertex = model.Vertex;
const Face = model.Face;

const WIDTH = 800;
const HEIGHT = 800;

const Color = struct {
    const white: tga.TGAColor = .{ .bgra = .{ 255, 255, 255, 255 }, .bytespp = 4 };
    const green: tga.TGAColor = .{ .bgra = .{ 0, 255, 0, 255 }, .bytespp = 4 };
    const red: tga.TGAColor = .{ .bgra = .{ 0, 0, 255, 255 }, .bytespp = 4 };
    const blue: tga.TGAColor = .{ .bgra = .{ 255, 128, 64, 255 }, .bytespp = 4 };
    const yellow: tga.TGAColor = .{ .bgra = .{ 0, 200, 255, 255 }, .bytespp = 4 };

    pub fn bGRA(b: u8, g: u8, r: u8, a: u8) tga.TGAColor {
        return .{ .bgra = .{ b, g, r, a }, .bytespp = 4 };
    }
};

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
            std.debug.print("fz: {d}  \t", .{fz});
            const iz: i16 = @intFromFloat(@min(fz, 255));
            const z: u8 = if (iz < 0) 0 else @intCast(iz);

            if (alpha < 0 or beta < 0 or gamma < 0)
                continue;
            if (z <= zbuffer.get(x, y).get(2))
                continue;

            std.debug.print("z: {d}\n", .{z});
            zbuffer.set(x, y, Color.bGRA(z, z, z, z));
            framebuffer.set(x, y, color);
        }
    }
}

pub fn project(v: Vec3) Vec3 {
    return .{
        (v[0] + 1.0) * WIDTH / 2.0,
        (v[1] + 1.0) * HEIGHT / 2.0,
        (v[2] + 1.0) * 255.0 / 2.0,
    };
}

pub fn newFramebuffer(alloc: std.mem.Allocator, width: i32, height: i32) !tga.TGAImage {
    return tga.TGAImage.init(alloc, width, height, @intFromEnum(tga.Format.rgb));
}

pub fn Rng() std.Random {
    var tio = std.Io.Threaded.init_single_threaded;
    const io = tio.io();
    const seed: u64 = @intCast(std.Io.Clock.real.now(io).toNanoseconds());
    const seed2: u64 = @intCast(std.Io.Clock.real.now(io).toNanoseconds());
    var prng = std.Random.DefaultPrng.init(seed + seed2);
    const rng = prng.random();

    return rng;
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;

    var framebuffer = try newFramebuffer(arena, WIDTH, HEIGHT);
    defer framebuffer.deinit();

    var zbuffer = try newFramebuffer(arena, WIDTH, HEIGHT);
    defer zbuffer.deinit();

    var start = std.Io.Clock.now(.awake, io);
    const obj = try Model.load(arena, io, "./diablo3_pose.obj");

    var end = std.Io.Clock.now(.awake, io);
    var duration = start.durationTo(end).toMilliseconds();

    std.debug.print("# vertex: {d}\n", .{obj.verts.items.len});
    std.debug.print("# face:   {d}\n", .{obj.faces.items.len});
    std.debug.print("\x1b[33mtook\x1b[0m........\x1b[31m{d}ms\x1b[0m\n", .{duration});

    start = std.Io.Clock.now(.awake, io);

    var i: usize = 0;
    while (i < (obj.faces.items.len / 3)) : (i += 1) {
        const pa = project(obj.vert(i, 0));
        const pb = project(obj.vert(i, 1));
        const pc = project(obj.vert(i, 2));

        const ax: i32 = @intFromFloat(@floor(pa[0]));
        const ay: i32 = @intFromFloat(@floor(pa[1]));
        const az: i32 = @intFromFloat(@floor(pa[2]));

        const bx: i32 = @intFromFloat(@floor(pb[0]));
        const by: i32 = @intFromFloat(@floor(pb[1]));
        const bz: i32 = @intFromFloat(@floor(pb[2]));

        const cx: i32 = @intFromFloat(@floor(pc[0]));
        const cy: i32 = @intFromFloat(@floor(pc[1]));
        const cz: i32 = @intFromFloat(@floor(pc[2]));

        var rng = Rng();
        const c = Color.bGRA(
            rng.intRangeAtMost(u8, 0, 255),
            rng.intRangeAtMost(u8, 0, 255),
            rng.intRangeAtMost(u8, 0, 255),
            255,
        );

        // std.debug.print("color: {d} {d} {d} {d}\n", .{ c.bgra[0], c.bgra[1], c.bgra[2], c.bgra[3] });
        triangle(
            ax,
            ay,
            az,
            bx,
            by,
            bz,
            cx,
            cy,
            cz,
            &zbuffer,
            &framebuffer,
            c,
        );
    }

    for (0..obj.verts.items.len) |v| {
        const p = project(obj.verts.items[v]);
        const x: i32 = @intFromFloat(@floor(p[0]));
        const y: i32 = @intFromFloat(@floor(p[1]));

        framebuffer.set(x, y, Color.white);
        // const filename = try std.fmt.allocPrint(arena, "fb_{d}.tga", .{v});
        // std.debug.print("frame: {s}\n", .{filename});
        // try framebuffer.writeTgaFile(io, filename, true, true);
    }

    end = std.Io.Clock.now(.awake, io);
    duration = start.durationTo(end).toMilliseconds();
    std.debug.print("\x1b[33mframe took\x1b[0m..\x1b[31m{d}ms\x1b[0m\n", .{duration});

    try framebuffer.writeTgaFile(io, "framebuffer.tga", true, true);
    try zbuffer.writeTgaFile(io, "zbuffer.tga", true, true);
}
