const std = @import("std");
const tga = @import("../tgaimage.zig");
const common = @import("../common.zig");
const model = @import("../model.zig");
const draw = @import("draw.zig");

const WIDTH = common.WIDTH;
const HEIGHT = common.HEIGHT;

const Vec3 = common.Vec3;
const Mat4 = common.Mat4;
const Color = common.Color;
const Model = model.Model;
const ObjectData = model.ObjectData;

pub const RenderContext = extern struct {
    obj: *const ObjectData,
    rng: *const std.Random,
    framebuffer: *tga.TGAImage,
    zbuffer: *tga.TGAImage,
};

fn project(v: Vec3) Vec3 {
    return .{
        (v[0] + 1.0) * WIDTH / 2.0,
        (v[1] + 1.0) * HEIGHT / 2.0,
        (v[2] + 1.0) * 255.0 / 2.0,
        1.0,
    };
}

fn persp(v: Vec3) Vec3 {
    const c: f32 = 3.0;

    const vx = v[0] / (1.0 - v[2] / c);
    const vy = v[1] / (1.0 - v[2] / c);
    const vz = v[2] / (1.0 - v[2] / c);

    return .{ vx, vy, vz, 1 };
}

fn perspective(f: f32) Mat4 {
    const p = -1 / f;
    return .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, p, 1 },
    };
}

fn rotate(v: Vec3) Vec3 {
    const a = std.math.pi / 6.0; // 30deg
    const c = @cos(a);
    const s = @sin(a);

    const rot: [3]@Vector(3, f32) = .{
        .{ c, 0, s },
        .{ 0, 1, 0 },
        .{ -s, 0, c },
    };

    const mx = v[0] * rot[0][0] + v[1] * rot[0][1] + v[2] * rot[0][2];
    const my = v[0] * rot[1][0] + v[1] * rot[1][1] + v[2] * rot[1][2];
    const mz = v[0] * rot[2][0] + v[1] * rot[2][1] + v[2] * rot[2][2];

    return .{ mx, my, mz, 1 };
}

fn apply(ctx: RenderContext, f: usize, n: usize) Vec3 {
    const fv = ctx.obj.vert(f, n);
    return project(persp(rotate(fv)));
}

pub fn new(alloc: std.mem.Allocator, width: i32, height: i32) !tga.TGAImage {
    return tga.TGAImage.init(alloc, width, height, @intFromEnum(tga.Format.rgb));
}

pub fn renderFrame(ctx: RenderContext) !void {
    @memset(ctx.framebuffer.data, 0);
    @memset(ctx.zbuffer.data, 0);

    var i: usize = 0;
    while (i < ctx.obj.nfaces()) : (i += 1) {
        const c = Color.bgra(
            ctx.rng.intRangeAtMost(u8, 0, 255),
            ctx.rng.intRangeAtMost(u8, 0, 255),
            ctx.rng.intRangeAtMost(u8, 0, 255),
            255,
        );

        const pa = apply(ctx, i, 0);
        const pb = apply(ctx, i, 1);
        const pc = apply(ctx, i, 2);

        draw.triangle(pa, pb, pc, ctx.zbuffer, ctx.framebuffer, c);
    }
}
