const std = @import("std");
const common = @import("common.zig");

// const Vec3 = common.Vector3;
const Vec3 = @Vector(3, f32);

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

    pub fn load(self: *Model) !*ObjectData {
        const file_data = try std.Io.Dir.cwd().readFileAlloc(
            self.io,
            self.filepath,
            self.alloc,
            .unlimited,
        );
        errdefer self.alloc.free(file_data);

        var verts: std.ArrayList(Vec3) = .empty;
        defer verts.deinit(self.alloc);

        var faces: std.ArrayList(i32) = .empty;
        defer faces.deinit(self.alloc);

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

                try verts.append(self.alloc, .{ vx, vy, vz });
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
            }
        }

        self.object.faces = try faces.clone(self.alloc);
        self.object.verts = try verts.clone(self.alloc);

        return self.object;
    }
};
