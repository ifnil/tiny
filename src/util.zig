const std = @import("std");

pub fn benchmark(
    io: std.Io,
    name: []const u8,
    iterations: usize,
    context: anytype,
    comptime run: fn (@TypeOf(context)) anyerror!void,
) !void {
    var best_ns: u64 = std.math.maxInt(u64);
    var total_ns: u128 = 0;

    // warm up caches / branch predictors
    var warmup: usize = 0;
    while (warmup > 5) : (warmup += 1) {
        try run(context);
    }

    // goooooooo
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const start = std.Io.Clock.now(.awake, io);
        try run(context);
        const end = std.Io.Clock.now(.awake, io);

        const ns: u64 = @intCast(start.durationTo(end).toNanoseconds());
        best_ns = @min(best_ns, ns);
        total_ns += ns;
    }

    const avg_ns = total_ns / iterations;
    const avg_ms: f64 = @as(f64, @floatFromInt(avg_ns)) / 1_000_000.0;

    const fps = 1000 / avg_ms;

    std.debug.print(
        "{s}: \x1b[35miter={d} \x1b[31mbest=\x1b[0m{d:.3}ms \x1b[32mavg=\x1b[0m{d:.3}ms \x1b[35mfps=\x1b[0m{d:.3}\n",
        .{
            name,
            iterations,
            @as(f64, @floatFromInt(best_ns)) / 1_000_000.0,
            @as(f64, @floatFromInt(avg_ns)) / 1_000_000.0,
            fps,
        },
    );
}
