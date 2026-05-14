const std = @import("std");

pub const Vec3 = @Vector(3, f32);

pub const ObjectData = struct {
    verts: std.ArrayList(Vec3) = .empty,
    faces: std.ArrayList(i32) = .empty,

    pub fn deinit(self: ObjectData, alloc: std.mem.Allocator) void {
        self.verts.deinit(alloc);
        self.faces.deinit(alloc);
    }

    pub fn vert(self: ObjectData, iface: usize, n: usize) Vec3 {
        const f = self.faces.items[iface * 3 + n];
        const v = self.verts.items[@intCast(f - 1)];
        return v;
    }
};

pub const Model = struct {
    pub fn load(alloc: std.mem.Allocator, io: std.Io, path: []const u8) !ObjectData {
        const file_data = try std.Io.Dir.cwd().readFileAlloc(
            io,
            path,
            alloc,
            .unlimited,
        );
        errdefer alloc.free(file_data);

        var verts: std.ArrayList(Vec3) = .empty;
        var faces: std.ArrayList(i32) = .empty;

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

                try verts.append(alloc, .{ vx, vy, vz });
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

                try faces.append(alloc, dx);
                try faces.append(alloc, dy);
                try faces.append(alloc, dz);
            }
        }

        const object: ObjectData = .{
            .faces = faces,
            .verts = verts,
        };

        return object;
    }
};
