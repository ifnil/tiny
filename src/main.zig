const build_options = @import("build_options");

const std = @import("std");
const tga = @import("tgaimage.zig");
const common = @import("common.zig");
const render = @import("render.zig");

const Model = @import("model.zig").Model;

const Vec2 = common.Vector2;
const Vec3 = common.Vector3;
const Color = common.Color;

const WIDTH = common.WIDTH;
const HEIGHT = common.HEIGHT;

const DEBUG = build_options.debug_log;
const BENCH = build_options.bench;

// TODO: time graphs
pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var gpa = std.heap.DebugAllocator(.{}){};
    errdefer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var path: []const u8 = undefined;
    var args = init.minimal.args.iterate();
    defer args.deinit();
    _ = args.next();
    path = args.next() orelse return;

    std.debug.print("build opts: {}\n", .{build_options.debug_log});

    const seed: u64 = @intCast(std.Io.Clock.real.now(io).toNanoseconds());
    var prng = std.Random.DefaultPrng.init(seed);
    const rng = prng.random();

    var framebuffer = try render.new(alloc, WIDTH, HEIGHT);
    defer framebuffer.deinit();

    var zbuffer = try render.new(alloc, WIDTH, HEIGHT);
    defer zbuffer.deinit();

    var start = std.Io.Clock.now(.awake, io);

    var mm = try Model.new(alloc, io, path);
    defer mm.deinit();
    const obj = try mm.load();

    const end = std.Io.Clock.now(.awake, io);
    var duration = start.durationTo(end).toMilliseconds();

    std.debug.print("\x1b[36m# vertices:\x1b[0m     {d}\n", .{obj.verts.items.len});
    std.debug.print("\x1b[36m# faces:\x1b[0m        {d}\n\n", .{obj.nfaces()});
    std.debug.print("\x1b[36mload\x1b[0m..........\t\x1b[31m{d}ms\x1b[0m\n", .{duration});

    start = std.Io.Clock.now(.awake, io);
    var i: usize = 0;
    while (i < obj.nfaces()) : (i += 1) {
        const pa = render.project(obj.vert(@intCast(i), 0));
        const pb = render.project(obj.vert(@intCast(i), 1));
        const pc = render.project(obj.vert(@intCast(i), 2));

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
            rng.intRangeAtMost(u8, 0, 255),
            rng.intRangeAtMost(u8, 0, 255),
            rng.intRangeAtMost(u8, 0, 255),
            255,
        );

        render.triangle(
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

    duration = start.durationTo(std.Io.Clock.now(.awake, io)).toMilliseconds();
    std.debug.print("\x1b[36mframe took\x1b[0m....\t\x1b[31m{d}ms\x1b[0m\n", .{duration});

    try framebuffer.writeTgaFile(io, "framebuffer.tga", true, true);
    try zbuffer.writeTgaFile(io, "zbuffer.tga", true, true);
}
