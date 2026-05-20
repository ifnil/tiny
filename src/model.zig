const std = @import("std");
const common = @import("common.zig");
const Regex = @import("regex").Regex;

const Verts = @import("render/primitives/vector.zig").Verts;
const VertsInt = @import("render/primitives/vector.zig").VertsInt;

const Vec3 = common.Vector3;

pub const ObjectData = struct {
    verts: std.ArrayList(Vec3) = .empty,
    faces: std.ArrayList(i32) = .empty,

    pub fn nfaces(self: ObjectData) usize {
        return self.faces.items.len / 3;
    }

    pub fn nverts(self: ObjectData) usize {
        return self.verts.items.len;
    }

    pub fn vert(self: ObjectData, iface: usize, n: usize) Vec3 {
        const f = self.faces.items[iface * 3 + n];
        const v = self.verts.items[@intCast(f - 1)];
        return v;
    }

    pub fn vertices(self: *ObjectData, alloc: std.mem.Allocator) []Vec3 {
        return self.verts.toOwnedSlice(alloc);
    }
};

pub const Model = struct {
    alloc: std.mem.Allocator,
    io: std.Io,
    object: *ObjectData,
    filepath: []const u8,
    vertices: Verts = undefined,
    face_vertices: Verts = undefined,

    pub const Counts = struct {
        vertices: i32 = 0,
        faces: i32 = 0,
    };

    pub fn new(alloc: std.mem.Allocator, io: std.Io, path: []const u8) !Model {
        return .{
            .alloc = alloc,
            .io = io,
            .object = try alloc.create(ObjectData),
            .filepath = path,
        };
    }

    pub fn deinit(self: *Model) void {
        self.object.faces.deinit(self.alloc);
        self.object.verts.deinit(self.alloc);
    }

    fn getCounts(file_data: []const u8) !Counts {
        var count = Counts{};
        var iter = std.mem.splitScalar(u8, file_data, '\n');
        while (iter.next()) |line| {
            if (std.mem.containsAtLeast(u8, line, 1, "#")) {
                var tok = std.mem.splitScalar(u8, line, ' ');
                _ = tok.next();

                const c = tok.next() orelse continue;
                const k = tok.next() orelse continue;

                if (std.mem.eql(u8, k, "vertices")) {
                    count.vertices = try std.fmt.parseInt(i32, c, 10);
                }

                if (std.mem.eql(u8, k, "faces")) {
                    count.faces = try std.fmt.parseInt(i32, c, 10);
                }
            }
        }

        return count;
    }

    // TODO: improve
    pub fn load(self: *Model) !*ObjectData {
        const file_data = try std.Io.Dir.cwd().readFileAlloc(
            self.io,
            self.filepath,
            self.alloc,
            .unlimited,
        );
        errdefer self.alloc.free(file_data);

        var fv: std.AutoHashMap(i32, [3]f32) = .init(self.alloc);
        const counts = try getCounts(file_data);
        std.debug.print("verts: {d}\n", .{counts.vertices});
        std.debug.print("faces: {d}\n", .{counts.faces});

        var face_vertices = Verts{
            .x = try self.alloc.alloc(f32, @intCast(counts.faces)),
            .y = try self.alloc.alloc(f32, @intCast(counts.faces)),
            .z = try self.alloc.alloc(f32, @intCast(counts.faces)),
        };

        var vertices = Verts{
            .x = try self.alloc.alloc(f32, @intCast(counts.vertices)),
            .y = try self.alloc.alloc(f32, @intCast(counts.vertices)),
            .z = try self.alloc.alloc(f32, @intCast(counts.vertices)),
        };

        var verts: std.ArrayList(Vec3) = .empty;
        var faces: std.ArrayList(i32) = .empty;

        defer verts.deinit(self.alloc);
        defer faces.deinit(self.alloc);

        var vert_idx: usize = 0;
        var face_idx: usize = 0;
        var iter = std.mem.splitScalar(u8, file_data, '\n');
        while (iter.next()) |line| {
            var words_iter = std.mem.splitScalar(u8, line, ' ');

            const line_type = words_iter.next() orelse continue;
            const x = words_iter.next() orelse continue;
            const y = words_iter.next() orelse continue;
            const z = words_iter.next() orelse continue;

            if (std.mem.eql(u8, line_type, "v")) {
                const vx = try std.fmt.parseFloat(f32, x);
                const vy = try std.fmt.parseFloat(f32, y);
                const vz = try std.fmt.parseFloat(f32, z);
                try verts.append(self.alloc, Vec3.from(.{ vx, vy, vz }));

                // TODO: handle
                if (vert_idx >= counts.vertices)
                    continue;
                vertices.x[vert_idx] = vx;
                vertices.y[vert_idx] = vy;
                vertices.z[vert_idx] = vz;
                vert_idx += 1;
            } else if (std.mem.eql(u8, line_type, "f")) {
                var face_iter = std.mem.splitScalar(u8, x, '/');
                const fx = face_iter.next() orelse continue;

                face_iter = std.mem.splitScalar(u8, y, '/');
                const fy = face_iter.next() orelse continue;

                face_iter = std.mem.splitScalar(u8, z, '/');
                const fz = face_iter.next() orelse continue;

                const dx: i32 = try std.fmt.parseInt(i32, fx, 10);
                const dy: i32 = try std.fmt.parseInt(i32, fy, 10);
                const dz: i32 = try std.fmt.parseInt(i32, fz, 10);

                try faces.append(self.alloc, dx);
                try faces.append(self.alloc, dy);
                try faces.append(self.alloc, dz);

                face_vertices.x[face_idx] = @floatFromInt(dx);
                face_vertices.y[face_idx] = @floatFromInt(dy);
                face_vertices.z[face_idx] = @floatFromInt(dz);
                face_idx += 1;
            }
        }

        self.object.faces = try faces.clone(self.alloc);
        self.object.verts = try verts.clone(self.alloc);
        self.vertices = vertices;
        self.face_vertices = face_vertices;

        for (self.face_vertices.x) |v| {
            try fv.put(@intFromFloat(v), .{
                self.vertices.x[@intFromFloat(v - 1)],
                self.vertices.y[@intFromFloat(v - 1)],
                self.vertices.z[@intFromFloat(v - 1)],
            });
        }

        std.debug.print("x: {d}\n", .{self.vertices.x.len});
        std.debug.print("y: {d}\n", .{self.vertices.y.len});
        std.debug.print("z: {d}\n", .{self.vertices.z.len});

        std.debug.print("x: {d}\n", .{face_vertices.x.len});
        std.debug.print("y: {d}\n", .{face_vertices.y.len});
        std.debug.print("z: {d}\n", .{face_vertices.z.len});
        return self.object;
    }
};
