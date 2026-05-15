const build_options = @import("build_options");

const std = @import("std");
const tga = @import("tgaimage.zig");
const common = @import("common.zig");
const render = @import("render.zig");
const util = @import("util.zig");

const Model = @import("model.zig").Model;
const ObjectData = @import("model.zig").ObjectData;

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

    const seed: u64 = @intCast(std.Io.Clock.real.now(io).toNanoseconds());
    var prng = std.Random.DefaultPrng.init(seed);
    const rng = prng.random();

    var framebuffer = try render.new(alloc, WIDTH, HEIGHT);
    defer framebuffer.deinit();

    var zbuffer = try render.new(alloc, WIDTH, HEIGHT);
    defer zbuffer.deinit();

    var mm = try Model.new(alloc, io, path);
    defer mm.deinit();
    const obj = try mm.load();

    if (BENCH) {
        try util.benchmark(io, "renderFrame", 100, render.RenderContext{
            .obj = obj,
            .framebuffer = &framebuffer,
            .zbuffer = &zbuffer,
            .rng = &rng,
        }, render.renderFrame);
    } else {
        try render.renderFrame(.{
            .obj = obj,
            .framebuffer = &framebuffer,
            .zbuffer = &zbuffer,
            .rng = &rng,
        });

        try framebuffer.writeTgaFile(io, "framebuffer.tga", true, true);
        try zbuffer.writeTgaFile(io, "zbuffer.tga", true, true);
    }
}
