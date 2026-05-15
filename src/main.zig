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

    std.debug.print("model: \x1b[36m{s}\x1b[0m\n", .{path});

    const obj = try mm.load();

    var end = std.Io.Clock.now(.awake, io);
    var duration = start.durationTo(end).toMilliseconds();

    std.debug.print("\x1b[36m# vertices:\x1b[0m     {d}\n", .{obj.verts.items.len});
    std.debug.print("\x1b[36m# faces:\x1b[0m        {d}\n\n", .{obj.nfaces()});
    std.debug.print("\x1b[36mload\x1b[0m..........\t\x1b[31m{d}ms\x1b[0m\n", .{duration});

    var triangle_times: std.ArrayList(std.Io.Duration) = .empty;
    defer triangle_times.deinit(alloc);

    var project_times: std.ArrayList(std.Io.Duration) = .empty;
    defer project_times.deinit(alloc);

    var cast_times: std.ArrayList(std.Io.Duration) = .empty;
    defer cast_times.deinit(alloc);

    start = std.Io.Clock.now(.awake, io);
    var i: usize = 0;
    while (i < obj.nfaces()) : (i += 1) {
        var s = std.Io.Clock.now(.awake, io);

        const pa = render.project(obj.vert(@intCast(i), 0));
        const pb = render.project(obj.vert(@intCast(i), 1));
        const pc = render.project(obj.vert(@intCast(i), 2));

        var e = std.Io.Clock.now(.awake, io);
        try project_times.append(alloc, s.durationTo(e));

        s = std.Io.Clock.now(.awake, io);
        const ax: i32 = @intFromFloat(@floor(pa.x));
        const ay: i32 = @intFromFloat(@floor(pa.y));
        const az: i32 = @intFromFloat(@floor(pa.z));

        const bx: i32 = @intFromFloat(@floor(pb.x));
        const by: i32 = @intFromFloat(@floor(pb.y));
        const bz: i32 = @intFromFloat(@floor(pb.z));

        const cx: i32 = @intFromFloat(@floor(pc.x));
        const cy: i32 = @intFromFloat(@floor(pc.y));
        const cz: i32 = @intFromFloat(@floor(pc.z));

        e = std.Io.Clock.now(.awake, io);
        try cast_times.append(alloc, s.durationTo(e));

        const c = Color.bgra(
            rng.intRangeAtMost(u8, 0, 255),
            rng.intRangeAtMost(u8, 0, 255),
            rng.intRangeAtMost(u8, 0, 255),
            255,
        );

        s = std.Io.Clock.now(.awake, io);

        render.triangle(ax, ay, az, bx, by, bz, cx, cy, cz, &zbuffer, &framebuffer, c);

        e = std.Io.Clock.now(.awake, io);
        try triangle_times.append(alloc, s.durationTo(e));
    }

    end = std.Io.Clock.now(.awake, io);
    duration = start.durationTo(end).toMilliseconds();
    std.debug.print("\x1b[36mframe took\x1b[0m....\t\x1b[31m{d}ms\x1b[0m\n", .{duration});

    var total: i64 = 0;
    for (triangle_times.items) |t| {
        total += t.toMicroseconds();
    }
    var avg = @divTrunc(total, @as(i64, @intCast(triangle_times.items.len)));
    std.debug.print("\x1b[36mavg triangle\x1b[0m..\t\x1b[31m{d}μs\x1b[0m\n", .{avg});

    total = 0;
    for (triangle_times.items) |t| {
        total += t.toMicroseconds();
    }
    avg = @divTrunc(total, @as(i64, @intCast(project_times.items.len)));
    std.debug.print("\x1b[36mavg project\x1b[0m..\t\x1b[31m{d}μs\x1b[0m\n", .{avg});

    total = 0;
    for (triangle_times.items) |t| {
        total += t.toMicroseconds();
    }
    avg = @divTrunc(total, @as(i64, @intCast(cast_times.items.len)));
    std.debug.print("\x1b[36mavg cast\x1b[0m..\t\x1b[31m{d}μs\x1b[0m\n", .{avg});

    try framebuffer.writeTgaFile(io, "framebuffer.tga", true, true);
    try zbuffer.writeTgaFile(io, "zbuffer.tga", true, true);
}
