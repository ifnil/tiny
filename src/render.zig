const std = @import("std");
const tga = @import("tgaimage.zig");
const common = @import("common.zig");
const Model = @import("model.zig").Model;
const ObjectData = @import("model.zig").ObjectData;

const draw = @import("render/draw.zig");

const Verts = @import("render/primitives/vector.zig").Verts;
const VertsInt = @import("render/primitives/vector.zig").VertsInt;

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
    verticies: *const Verts,
    faces: *const Verts,
};

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

fn project_point(x: f32, y: f32, z: f32) struct { f32, f32, f32 } {
    return .{
        (x + 1.0) * WIDTH / 2.0,
        (y + 1.0) * HEIGHT / 2.0,
        (z + 1.0) * 255.0 / 2.0,
    };
}

pub fn renderFrame(ctx: RenderContext) !void {
    @memset(ctx.framebuffer.data, 0);
    @memset(ctx.zbuffer.data, 0);

    var i: usize = 0;
    while (i < ctx.obj.nfaces()) : (i += 1) {
        const pa = project(ctx.obj.vert(@intCast(i), 0));
        const pb = project(ctx.obj.vert(@intCast(i), 1));
        const pc = project(ctx.obj.vert(@intCast(i), 2));

        std.debug.print("\ni: {d}\n", .{i});
        const tpax = ctx.verticies.x[@intCast(ctx.faces.x[i] - 1)];
        const tpay = ctx.verticies.y[@intCast(ctx.faces.x[i] - 1)];
        const tpaz = ctx.verticies.z[@intCast(ctx.faces.x[i] - 1)];
        const x, const y, const z = project_point(tpax, tpay, tpaz);
        std.debug.print("tpa:\t{d}\t{d}\t{d}\n", .{ tpax, tpay, tpaz });
        std.debug.print("xyz:\t{d}\t{d}\t{d}\n", .{ x, y, z });
        std.debug.print("pa:\t{d}\t{d}\t{d}\n", .{ pa.x, pa.y, pa.z });

        const tpbx = ctx.verticies.x[@intCast(ctx.faces.y[i] - 1)];
        const tpby = ctx.verticies.y[@intCast(ctx.faces.y[i] - 1)];
        const tpbz = ctx.verticies.z[@intCast(ctx.faces.y[i] - 1)];
        const tbx, const tby, const tbz = project_point(tpbx, tpby, tpbz);
        std.debug.print("\ntpb:\t{d}\t{d}\t{d}\n", .{ tpbx, tpby, tpbz });
        std.debug.print("xyz:\t{d}\t{d}\t{d}\n", .{ tbx, tby, tbz });
        std.debug.print("pb:\t{d}\t{d}\t{d}\n", .{ pb.x, pb.y, pb.z });

        const tpcx = ctx.verticies.x[@intCast(ctx.faces.z[i] - 1)];
        const tpcy = ctx.verticies.y[@intCast(ctx.faces.z[i] - 1)];
        const tpcz = ctx.verticies.z[@intCast(ctx.faces.z[i] - 1)];
        const tcx, const tcy, const tcz = project_point(tpcx, tpcy, tpcz);
        std.debug.print("\ntpc:\t{d}\t{d}\t{d}\n", .{ tpcx, tpcy, tpcz });
        std.debug.print("xyz:\t{d}\t{d}\t{d}\n", .{ tcx, tcy, tcz });
        std.debug.print("pc:\t{d}\t{d}\t{d}\n", .{ pc.x, pc.y, pc.z });

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
