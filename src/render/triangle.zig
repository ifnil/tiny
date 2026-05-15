const common = @import("../common.zig");

const Vec3 = common.Vector3;

pub const Triangle = struct {
    a: Vec3,
    b: Vec3,
    c: Vec3,

    pub fn new(a: Vec3, b: Vec3, c: Vec3) Triangle {
        return .{ .a = a, .b = b, .c = c };
    }
};
