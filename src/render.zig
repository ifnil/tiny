const std = @import("std");
const tga = @import("tgaimage.zig");
const common = @import("common.zig");
const Model = @import("model.zig").Model;
const ObjectData = @import("model.zig").ObjectData;

const draw = @import("render/draw.zig");

const WIDTH = common.WIDTH;
const HEIGHT = common.HEIGHT;

const Color = common.Color;
const Vec2 = common.Vector2;
const Vec3 = common.Vector3;

pub const RenderContext = struct {
    obj: *const ObjectData,
    rng: *const std.Random,
    framebuffer: *tga.TGAImage,
    zbuffer: *tga.TGAImage,
};

pub fn renderFrame(ctx: RenderContext) !void {
    @memset(ctx.framebuffer.data, 0);
    @memset(ctx.zbuffer.data, 0);

    var i: usize = 0;
    while (i < ctx.obj.nfaces()) : (i += 1) {
        const pa = project(ctx.obj.vert(@intCast(i), 0));
        const pb = project(ctx.obj.vert(@intCast(i), 1));
        const pc = project(ctx.obj.vert(@intCast(i), 2));

        const ax: i32 = @intFromFloat(@floor(pa.x));
        const ay: i32 = @intFromFloat(@floor(pa.y));
        const az: i32 = @intFromFloat(@floor(pa.z));

        const bx: i32 = @intFromFloat(@floor(pb.x));
        const by: i32 = @intFromFloat(@floor(pb.y));
        const bz: i32 = @intFromFloat(@floor(pb.z));

        const cx: i32 = @intFromFloat(@floor(pc.x));
        const cy: i32 = @intFromFloat(@floor(pc.y));
        const cz: i32 = @intFromFloat(@floor(pc.z));

        const c = Color.bgra(
            ctx.rng.intRangeAtMost(u8, 0, 255),
            ctx.rng.intRangeAtMost(u8, 0, 255),
            ctx.rng.intRangeAtMost(u8, 0, 255),
            255,
        );

        draw.triangle(
            ax,
            ay,
            az,
            bx,
            by,
            bz,
            cx,
            cy,
            cz,
            ctx.zbuffer,
            ctx.framebuffer,
            c,
        );
    }
}

pub fn new(alloc: std.mem.Allocator, width: i32, height: i32) !tga.TGAImage {
    return tga.TGAImage.init(alloc, width, height, @intFromEnum(tga.Format.rgb));
}

fn project(v: Vec3) Vec3 {
    return Vec3.from(.{
        (v.x + 1.0) * WIDTH / 2.0,
        (v.y + 1.0) * HEIGHT / 2.0,
        (v.z + 1.0) * 255.0 / 2.0,
    });
}
