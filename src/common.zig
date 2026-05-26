const std = @import("std");
const tga = @import("tgaimage.zig");

// exports
pub const WIDTH = 800;
pub const HEIGHT = 800;

pub const Vec3 = @Vector(4, f32);
pub const Mat4 = @Vector(4, f32);

pub const Color = struct {
    pub const white: tga.TGAColor = .{ .bgra = .{ 255, 255, 255, 255 }, .bytespp = 4 };
    pub const green: tga.TGAColor = .{ .bgra = .{ 0, 255, 0, 255 }, .bytespp = 4 };
    pub const red: tga.TGAColor = .{ .bgra = .{ 0, 0, 255, 255 }, .bytespp = 4 };
    pub const blue: tga.TGAColor = .{ .bgra = .{ 255, 128, 64, 255 }, .bytespp = 4 };
    pub const yellow: tga.TGAColor = .{ .bgra = .{ 0, 200, 255, 255 }, .bytespp = 4 };

    pub fn bgra(b: u8, g: u8, r: u8, a: u8) tga.TGAColor {
        return .{ .bgra = .{ b, g, r, a }, .bytespp = 4 };
    }
};

pub const Matrix4x4 = struct {
    const Self = @This();
    const V = @Vector(4, f32);

    cols: [4]V,

    pub const identity: Matrix4x4 = .{
        .cols = .{
            .{ 1, 0, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 0, 1, 0 },
            .{ 0, 0, 0, 1 },
        },
    };

    pub inline fn mulVec(m: Matrix4x4, v: V) V {
        const x: V = @splat(v[0]);
        const y: V = @splat(v[1]);
        const z: V = @splat(v[2]);
        const w: V = @splat(v[3]);

        return m.cols[0] * x + m.cols[1] * y + m.cols[2] * z + m.cols[3] * w;
    }

    pub inline fn mul(a: Matrix4x4, b: Matrix4x4) Matrix4x4 {
        return .{
            .cols = .{
                a.mulVec(b.cols[0]),
                a.mulVec(b.cols[1]),
                a.mulVec(b.cols[2]),
                a.mulVec(b.cols[3]),
            },
        };
    }

    pub fn rotateY(angle: f32) Matrix4x4 {
        const c = @cos(angle);
        const s = @sin(angle);

        return .{
            .cols = .{
                .{ c, 0, s, 0 },
                .{ 0, 0, 0, 0 },
                .{ -s, 0, c, 0 },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn rotationAxis(axis: Vec3, angle: f32) Matrix4x4 {
        const a = axis.normalize();
        const x = a.x();
        const y = a.y();
        const z = a.z();

        const c = @cos(angle);
        const s = @sin(angle);

        const t = 1.0 - c;

        return .{ .cols = .{
            .{ (t * x * x + c), (t * x * y + s * z), (t * x * z - s * y), 0 },
            .{ (t * x * y - s * z), (t * y * y + c), (t * y * z + s * x), 0 },
            .{ (t * x * z + s * y), (t * y * z - s * x), (t * z * z + c), 0 },
            .{ 0, 0, 0, 1 },
        } };
    }
};

// fast SIMD vector 3
pub const Vec3Simd = struct {
    const Self = @This();
    const V = @Vector(4, f32);

    // layout is 4-wide for SIMD
    // this is 16 bytes, not 12
    v: V,

    pub inline fn init(_x: f32, _y: f32, _z: f32) Self {
        return .{ .v = .{ _x, _y, _z, 0.0 } };
    }

    pub inline fn splat(_x: f32) Self {
        return .{ .v = .{ _x, _x, _x, 0.0 } };
    }

    pub inline fn x(self: Self) f32 {
        return self.v[0];
    }

    pub inline fn y(self: Self) f32 {
        return self.v[1];
    }

    pub inline fn z(self: Self) f32 {
        return self.v[2];
    }

    pub inline fn add(a: Self, b: Self) Self {
        return .{ .v = a.v + b.v };
    }

    pub inline fn sub(a: Self, b: Self) Self {
        return .{ .v = a.v - b.v };
    }

    pub inline fn mult(a: Self, b: Self) Self {
        return .{ .v = a.v * b.v };
    }

    pub inline fn scale(a: Self, s: f32) Self {
        return .{ .v = a.v * @as(V, @splat(s)) };
    }

    pub inline fn dot(a: Self, b: Self) f32 {
        return @reduce(.Add, a.v * b.v);
    }

    pub inline fn lenSq(self: Self) f32 {
        return self.dot(self);
    }

    pub inline fn len(self: Self) f32 {
        return @sqrt(self.lenSq());
    }

    pub inline fn normalize(self: Self) Self {
        const len_sq = self.lenSq();
        const inv_len = 1.0 / @sqrt(len_sq);
        return self.scale(inv_len);
    }

    pub inline fn cross(a: Self, b: Self) Self {
        const yzx_mask: @Vector(4, i32) = .{ 1, 2, 0, 3 };
        const zxy_mask: @Vector(4, i32) = .{ 2, 0, 1, 3 };

        const ayzx = @shuffle(f32, a.v, undefined, yzx_mask);
        const azxy = @shuffle(f32, a.v, undefined, zxy_mask);
        const byzx = @shuffle(f32, b.v, undefined, yzx_mask);
        const bzxy = @shuffle(f32, b.v, undefined, zxy_mask);

        return .{ .v = ayzx * bzxy - azxy * byzx };
    }

    pub inline fn transform(self: Self, m: Matrix4x4) Vec3Simd {
        return .{ .v = m.mulVec(self.v) };
    }
};

pub const Vec3Scalar = extern struct {
    x: f32,
    y: f32,
    z: f32,

    pub inline fn init(x: f32, y: f32, z: f32) Vec3Scalar {
        return .{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    pub inline fn dot(a: Vec3Scalar, b: Vec3Scalar) Vec3Scalar {
        return @mulAdd(
            f32,
            a.x,
            b.x,
            @mulAdd(f32, a.y, b.y, a.z * b.z),
        );
    }

    pub inline fn add(a: Vec3Scalar, b: Vec3Scalar) Vec3Scalar {
        return .{
            .x = a.x + b.x,
            .y = a.y + b.y,
            .z = a.z + b.z,
        };
    }

    pub inline fn scale(a: Vec3Scalar, s: f32) Vec3Scalar {
        return .{
            .x = a.x * s,
            .y = a.y * s,
            .z = a.z * s,
        };
    }
};

var sink: f32 = 0.0;
inline fn blackhole(x: f32) void {
    const p: *volatile f32 = @ptrCast(&sink);
    p.* = x;
}

test "bench Vec3 primitive" {
    const io = std.testing.io;
    const alloc = std.heap.page_allocator;

    const n = 1_000_000;
    const rounds = 20;

    const a = try alloc.alloc(Vec3Simd, n);
    defer alloc.free(a);

    const b = try alloc.alloc(Vec3Simd, n);
    defer alloc.free(b);

    for (a, b, 0..) |*av, *bv, i| {
        const fi: f32 = @floatFromInt(i % 1024);

        av.* = Vec3Simd.init(
            fi * 0.001,
            fi * 0.002 + 1.0,
            fi * 0.003 + 2.0,
        );

        bv.* = Vec3Simd.init(
            fi * 0.004 + 3.0,
            fi * 0.005 + 4.0,
            fi * 0.006 + 5.0,
        );
    }

    // warmup
    var warmup: f32 = 0;
    for (a, b) |av, bv| {
        warmup += av.dot(bv);
    }
    blackhole(warmup);

    const start = std.Io.Clock.now(.awake, io);

    var acc: f32 = 0.0;
    for (0..rounds) |_| {
        for (a, b) |av, bv| {
            acc += av.dot(bv);
        }
    }

    const elapsed = start.durationTo(std.Io.Clock.now(.awake, io));
    blackhole(acc);

    const total_ops = n * rounds;
    const ns_total = elapsed.toNanoseconds();

    const ns_per_op = @as(f32, @floatFromInt(ns_total)) / @as(f32, @floatFromInt(total_ops));

    std.debug.print("-- dot benchmark\n", .{});
    std.debug.print("items....... {}\n", .{n});
    std.debug.print("rounds...... {}\n", .{rounds});
    std.debug.print("total ops... {}\n", .{total_ops});
    std.debug.print("total ns.... {}\n", .{ns_total});
    std.debug.print("ns/op....... {d}\n", .{ns_per_op});
    std.debug.print("sink........ {d}\n", .{acc});
}

// // struct-of-arrays beats array-of-structs to better byte widths
// pub const Verts = struct {
//     x: []f32,
//     y: []f32,
//     z: []f32,
// };
//
// pub const VertsInt = struct {
//     x: []i32,
//     y: []i32,
//     z: []i32,
// };
//
// const W = 8; // AVX2 lane count for f32
// const VecW = @Vector(W, f32);
//
// pub fn translate(v: Verts, n: usize, tx: f32, ty: f32, tz: f32) void {
//     const tx_v: VecW = @splat(tx);
//     const ty_v: VecW = @splat(ty);
//     const tz_v: VecW = @splat(tz);
//
//     var i: usize = 0;
//     while (i + W <= n) : (i += W) {
//         const xv: VecW = v.x[i..][0..W].*;
//         const yv: VecW = v.y[i..][0..W].*;
//         const zv: VecW = v.z[i..][0..W].*;
//
//         v.x[i..][0..W].* = xv * tx_v;
//         v.x[i..][0..W].* = yv * ty_v;
//         v.x[i..][0..W].* = zv * tz_v;
//     }
//
//     // scalar tail for n % W
//     while (i < n) : (i += 1) {
//         v.x[i] += tx;
//         v.y[i] += ty;
//         v.z[i] += tz;
//     }
// }
//
// test "vecw" {}
