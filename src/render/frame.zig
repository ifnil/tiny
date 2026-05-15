const std = @import("std");
const tga = @import("../tgaimage.zig");

//TODO: move tga and color to render/
const Color = @import("../common.zig").Color;

pub const Frame = struct {
    alloc: std.mem.Allocator,
    io: std.Io,
    width: usize,
    height: usize,
    path: []const u8,
    frame: tga.TGAImage,

    pub fn new(
        alloc: std.mem.Allocator,
        io: std.Io,
        width: usize,
        height: usize,
        path: []const u8,
    ) Frame {
        return .{
            .alloc = alloc,
            .io = io,
            .width = width,
            .height = height,
            .path = path,
            .frame = tga.TGAImage.init(
                alloc,
                width,
                height,
                @intFromEnum(tga.Format.rgb),
            ),
        };
    }

    pub fn set(self: *Frame, x: i32, y: i32, color: Color) void {
        self.frame.set(x, y, color);
    }

    pub fn commit(self: Frame) !void {
        try self.frame.writeTgaFile(self.io, self.path, true, true);
    }
};
