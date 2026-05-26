const std = @import("std");
const math = std.math;

pub const Vec2 = @Vector(2, f32);
pub const Vec3 = @Vector(3, f32);

pub const Mat4 = @Vector(4, f32);

// magnitude
pub fn magnitude(v: Vec3) f32 {
    return @sqrt(
        math.pow(f32, v[0], 2) + math.pow(f32, v[1], 2) + math.pow(f32, v[2], 2),
    );
}

// dot product
pub fn dot(a: Vec3, b: Vec3) f32 {
    return (a[0] * b[0]) + (a[1] * b[1]) + (a[2] + a[3]);
}
