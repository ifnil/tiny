const std = @import("std");
const Io = std.Io;

pub const Format = enum(u8) {
    grayscale = 1,
    rgb = 3,
    rgba = 4,
};

pub const TGAColor = struct {
    bgra: [4]u8 = .{ 0, 0, 0, 0 },
    bytespp: u8 = 4,

    pub fn get(self: TGAColor, i: usize) u8 {
        return self.bgra[i];
    }
};

pub const TGAHeader = struct {
    idlength: u8 = 0,
    colormaptype: u8 = 0,
    datatypecode: u8 = 0,
    colormaporigin: u16 = 0,
    colormaplength: u16 = 0,
    colormapdepth: u8 = 0,
    x_origin: u16 = 0,
    y_origin: u16 = 0,
    width: u16 = 0,
    height: u16 = 0,
    bitsperpixel: u8 = 0,
    imagedescriptor: u8 = 0,

    pub const byte_size: usize = 18;

    pub fn decode(buf: *const [byte_size]u8) TGAHeader {
        return .{
            .idlength = buf[0],
            .colormaptype = buf[1],
            .datatypecode = buf[2],
            .colormaporigin = std.mem.readInt(u16, buf[3..5], .little),
            .colormaplength = std.mem.readInt(u16, buf[5..7], .little),
            .colormapdepth = buf[7],
            .x_origin = std.mem.readInt(u16, buf[8..10], .little),
            .y_origin = std.mem.readInt(u16, buf[10..12], .little),
            .width = std.mem.readInt(u16, buf[12..14], .little),
            .height = std.mem.readInt(u16, buf[14..16], .little),
            .bitsperpixel = buf[16],
            .imagedescriptor = buf[17],
        };
    }

    pub fn encode(self: TGAHeader) [byte_size]u8 {
        var buf: [byte_size]u8 = undefined;
        buf[0] = self.idlength;
        buf[1] = self.colormaptype;
        buf[2] = self.datatypecode;
        std.mem.writeInt(u16, buf[3..5], self.colormaporigin, .little);
        std.mem.writeInt(u16, buf[5..7], self.colormaplength, .little);
        buf[7] = self.colormapdepth;
        std.mem.writeInt(u16, buf[8..10], self.x_origin, .little);
        std.mem.writeInt(u16, buf[10..12], self.y_origin, .little);
        std.mem.writeInt(u16, buf[12..14], self.width, .little);
        std.mem.writeInt(u16, buf[14..16], self.height, .little);
        buf[16] = self.bitsperpixel;
        buf[17] = self.imagedescriptor;
        return buf;
    }
};

pub const TGAError = error{
    BadFormat,
    BadHeader,
    BadData,
    TooManyPixels,
    UnknownFormat,
};

pub const TGAImage = struct {
    w: i32 = 0,
    h: i32 = 0,
    bpp: u8 = 0,
    data: []u8 = &.{},
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, w: i32, h: i32, bpp: u8) !Self {
        const nbytes: usize = @intCast(w * h * @as(i32, bpp));
        const data = try allocator.alloc(u8, nbytes);
        @memset(data, 0);
        return .{
            .w = w,
            .h = h,
            .bpp = bpp,
            .data = data,
            .allocator = allocator,
        };
    }

    pub fn initEmpty(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        if (self.data.len > 0) self.allocator.free(self.data);
        self.data = &.{};
    }

    pub fn width(self: Self) i32 {
        return self.w;
    }

    pub fn height(self: Self) i32 {
        return self.h;
    }

    pub fn get(self: Self, x: i32, y: i32) TGAColor {
        if (self.data.len == 0 or x < 0 or y < 0 or x >= self.w or y >= self.h) return .{};
        var ret: TGAColor = .{ .bytespp = self.bpp };
        const base: usize = @intCast((x + y * self.w) * @as(i32, self.bpp));
        var i: usize = self.bpp;
        while (i > 0) {
            i -= 1;
            ret.bgra[i] = self.data[base + i];
        }
        return ret;
    }

    pub fn set(self: *Self, x: i32, y: i32, c: TGAColor) void {
        if (self.data.len == 0 or x < 0 or y < 0 or x >= self.w or y >= self.h) return;
        const base: usize = @intCast((x + y * self.w) * @as(i32, self.bpp));
        @memcpy(self.data[base .. base + self.bpp], c.bgra[0..self.bpp]);
    }

    pub fn flipHorizontally(self: *Self) void {
        var i: i32 = 0;
        while (i < @divTrunc(self.w, 2)) : (i += 1) {
            var j: i32 = 0;
            while (j < self.h) : (j += 1) {
                var b: i32 = 0;
                while (b < self.bpp) : (b += 1) {
                    const a: usize = @intCast((i + j * self.w) * @as(i32, self.bpp) + b);
                    const c: usize = @intCast((self.w - 1 - i + j * self.w) * @as(i32, self.bpp) + b);
                    std.mem.swap(u8, &self.data[a], &self.data[c]);
                }
            }
        }
    }

    pub fn flipVertically(self: *Self) void {
        var i: i32 = 0;
        while (i < self.w) : (i += 1) {
            var j: i32 = 0;
            while (j < @divTrunc(self.h, 2)) : (j += 1) {
                var b: i32 = 0;
                while (b < self.bpp) : (b += 1) {
                    const a: usize = @intCast((i + j * self.w) * @as(i32, self.bpp) + b);
                    const c: usize = @intCast((i + (self.h - 1 - j) * self.w) * @as(i32, self.bpp) + b);
                    std.mem.swap(u8, &self.data[a], &self.data[c]);
                }
            }
        }
    }

    pub fn readTgaFile(self: *Self, io: Io, path: []const u8) !void {
        const file = Io.Dir.cwd().openFile(io, path, .{}) catch |e| {
            std.debug.print("can't open file {s}\n", .{path});
            return e;
        };
        defer file.close(io);

        var read_buf: [4096]u8 = undefined;
        var file_reader: Io.File.Reader = .init(file, io, &read_buf);
        const r = &file_reader.interface;

        const hdr_arr = r.takeArray(TGAHeader.byte_size) catch |e| {
            std.debug.print("an error occured while reading the header\n", .{});
            return e;
        };
        const header = TGAHeader.decode(hdr_arr);

        const w: i32 = header.width;
        const h: i32 = header.height;
        const bpp: u8 = @intCast(header.bitsperpixel >> 3);
        if (w <= 0 or h <= 0 or
            (bpp != @intFromEnum(Format.grayscale) and
                bpp != @intFromEnum(Format.rgb) and
                bpp != @intFromEnum(Format.rgba)))
        {
            std.debug.print("bad bpp (or width/height) value\n", .{});
            return TGAError.BadFormat;
        }

        const nbytes: usize = @intCast(@as(i32, bpp) * w * h);
        if (self.data.len > 0) self.allocator.free(self.data);
        self.data = try self.allocator.alloc(u8, nbytes);
        @memset(self.data, 0);
        self.w = w;
        self.h = h;
        self.bpp = bpp;

        switch (header.datatypecode) {
            2, 3 => {
                r.readSliceAll(self.data) catch |e| {
                    std.debug.print("an error occured while reading the data\n", .{});
                    return e;
                };
            },
            10, 11 => {
                self.loadRleData(r) catch |e| {
                    std.debug.print("an error occured while reading the data\n", .{});
                    return e;
                };
            },
            else => {
                std.debug.print("unknown file format {d}\n", .{header.datatypecode});
                return TGAError.UnknownFormat;
            },
        }

        if ((header.imagedescriptor & 0x20) == 0) self.flipVertically();
        if ((header.imagedescriptor & 0x10) != 0) self.flipHorizontally();
        std.debug.print("{d}x{d}/{d}\n", .{ self.w, self.h, @as(u32, self.bpp) * 8 });
    }

    fn loadRleData(self: *Self, r: *Io.Reader) !void {
        const pixelcount: usize = @intCast(self.w * self.h);
        var currentpixel: usize = 0;
        var currentbyte: usize = 0;
        var colorbuffer: TGAColor = .{};
        while (true) {
            const ch_raw = try r.takeByte();
            var ch: u16 = ch_raw;
            if (ch < 128) {
                ch += 1;
                var i: u16 = 0;
                while (i < ch) : (i += 1) {
                    try r.readSliceAll(colorbuffer.bgra[0..self.bpp]);
                    var t: u8 = 0;
                    while (t < self.bpp) : (t += 1) {
                        self.data[currentbyte] = colorbuffer.bgra[t];
                        currentbyte += 1;
                    }
                    currentpixel += 1;
                    if (currentpixel > pixelcount) {
                        std.debug.print("Too many pixels read\n", .{});
                        return TGAError.TooManyPixels;
                    }
                }
            } else {
                ch -= 127;
                try r.readSliceAll(colorbuffer.bgra[0..self.bpp]);
                var i: u16 = 0;
                while (i < ch) : (i += 1) {
                    var t: u8 = 0;
                    while (t < self.bpp) : (t += 1) {
                        self.data[currentbyte] = colorbuffer.bgra[t];
                        currentbyte += 1;
                    }
                    currentpixel += 1;
                    if (currentpixel > pixelcount) {
                        std.debug.print("Too many pixels read\n", .{});
                        return TGAError.TooManyPixels;
                    }
                }
            }
            if (currentpixel >= pixelcount) break;
        }
    }

    pub fn writeTgaFile(self: Self, io: Io, path: []const u8, vflip: bool, rle: bool) !void {
        const developer_area_ref = [_]u8{ 0, 0, 0, 0 };
        const extension_area_ref = [_]u8{ 0, 0, 0, 0 };
        const footer = [_]u8{ 'T', 'R', 'U', 'E', 'V', 'I', 'S', 'I', 'O', 'N', '-', 'X', 'F', 'I', 'L', 'E', '.', 0 };

        const file = Io.Dir.cwd().createFile(io, path, .{}) catch |e| {
            std.debug.print("can't open file {s}\n", .{path});
            return e;
        };
        defer file.close(io);

        var write_buf: [4096]u8 = undefined;
        var file_writer: Io.File.Writer = .init(file, io, &write_buf);
        const w = &file_writer.interface;

        var header: TGAHeader = .{};
        header.bitsperpixel = @as(u8, self.bpp) << 3;
        header.width = @intCast(self.w);
        header.height = @intCast(self.h);
        header.datatypecode = if (self.bpp == @intFromEnum(Format.grayscale))
            (if (rle) @as(u8, 11) else 3)
        else
            (if (rle) @as(u8, 10) else 2);
        header.imagedescriptor = if (vflip) 0x00 else 0x20;

        const hdr_bytes = header.encode();
        w.writeAll(&hdr_bytes) catch |e| {
            std.debug.print("can't dump the tga file\n", .{});
            return e;
        };

        if (!rle) {
            w.writeAll(self.data) catch |e| {
                std.debug.print("can't dump the tga file\n", .{});
                return e;
            };
        } else {
            self.unloadRleData(w) catch |e| {
                std.debug.print("can't dump the tga file\n", .{});
                return e;
            };
        }

        w.writeAll(&developer_area_ref) catch |e| {
            std.debug.print("can't dump the tga file\n", .{});
            return e;
        };
        w.writeAll(&extension_area_ref) catch |e| {
            std.debug.print("can't dump the tga file\n", .{});
            return e;
        };
        w.writeAll(&footer) catch |e| {
            std.debug.print("can't dump the tga file\n", .{});
            return e;
        };
        w.flush() catch |e| {
            std.debug.print("can't dump the tga file\n", .{});
            return e;
        };
    }

    fn unloadRleData(self: Self, w: *Io.Writer) !void {
        const max_chunk_length: u8 = 128;
        const npixels: usize = @intCast(self.w * self.h);
        var curpix: usize = 0;
        while (curpix < npixels) {
            const chunkstart: usize = curpix * self.bpp;
            var curbyte: usize = curpix * self.bpp;
            var run_length: u8 = 1;
            var raw: bool = true;
            while (curpix + run_length < npixels and run_length < max_chunk_length) {
                var succ_eq: bool = true;
                var t: u8 = 0;
                while (succ_eq and t < self.bpp) : (t += 1) {
                    succ_eq = self.data[curbyte + t] == self.data[curbyte + t + self.bpp];
                }
                curbyte += self.bpp;
                if (run_length == 1) raw = !succ_eq;
                if (raw and succ_eq) {
                    run_length -= 1;
                    break;
                }
                if (!raw and !succ_eq) break;
                run_length += 1;
            }
            curpix += run_length;
            const head_byte: u8 = if (raw) run_length - 1 else run_length + 127;
            try w.writeAll(&[_]u8{head_byte});
            const payload_len: usize = if (raw) @as(usize, run_length) * self.bpp else self.bpp;
            try w.writeAll(self.data[chunkstart .. chunkstart + payload_len]);
        }
    }
};

test "init and set/get round trip" {
    const a = std.testing.allocator;
    var img = try TGAImage.init(a, 4, 4, 3);
    defer img.deinit();
    const red: TGAColor = .{ .bgra = .{ 0, 0, 255, 0 }, .bytespp = 3 };
    img.set(1, 2, red);
    const got = img.get(1, 2);
    try std.testing.expectEqual(@as(u8, 0), got.bgra[0]);
    try std.testing.expectEqual(@as(u8, 0), got.bgra[1]);
    try std.testing.expectEqual(@as(u8, 255), got.bgra[2]);
}

test "flip vertically" {
    const a = std.testing.allocator;
    var img = try TGAImage.init(a, 2, 2, 1);
    defer img.deinit();
    img.set(0, 0, .{ .bgra = .{ 1, 0, 0, 0 }, .bytespp = 1 });
    img.set(1, 1, .{ .bgra = .{ 2, 0, 0, 0 }, .bytespp = 1 });
    img.flipVertically();
    try std.testing.expectEqual(@as(u8, 1), img.get(0, 1).bgra[0]);
    try std.testing.expectEqual(@as(u8, 2), img.get(1, 0).bgra[0]);
}

test "write then read round trip rle" {
    const a = std.testing.allocator;
    var threaded = Io.Threaded.init_single_threaded;
    const io = threaded.io();

    var img = try TGAImage.init(a, 8, 8, 3);
    defer img.deinit();
    var y: i32 = 0;
    while (y < 8) : (y += 1) {
        var x: i32 = 0;
        while (x < 8) : (x += 1) {
            const c: TGAColor = .{ .bgra = .{ @intCast(x * 32), @intCast(y * 32), 128, 0 }, .bytespp = 3 };
            img.set(x, y, c);
        }
    }
    const tmp_path = "test_out.tga";
    try img.writeTgaFile(io, tmp_path, false, true);
    defer Io.Dir.cwd().deleteFile(io, tmp_path) catch {};

    var img2 = TGAImage.initEmpty(a);
    defer img2.deinit();
    try img2.readTgaFile(io, tmp_path);
    try std.testing.expectEqual(@as(i32, 8), img2.width());
    try std.testing.expectEqual(@as(i32, 8), img2.height());
    y = 0;
    while (y < 8) : (y += 1) {
        var x: i32 = 0;
        while (x < 8) : (x += 1) {
            const orig = img.get(x, y);
            const back = img2.get(x, y);
            try std.testing.expectEqualSlices(u8, orig.bgra[0..3], back.bgra[0..3]);
        }
    }
}
