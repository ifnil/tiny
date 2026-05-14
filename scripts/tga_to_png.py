#!/usr/bin/env python3

# generated

import argparse
import binascii
import struct
import zlib
from pathlib import Path


def read_tga(path):
    data = path.read_bytes()
    if len(data) < 18:
        raise ValueError("file is too small to be a TGA image")

    (
        id_length,
        color_map_type,
        image_type,
        _color_map_origin,
        color_map_length,
        _color_map_depth,
        _x_origin,
        _y_origin,
        width,
        height,
        bits_per_pixel,
        image_descriptor,
    ) = struct.unpack_from("<BBBHHBHHHHBB", data, 0)

    if color_map_type or color_map_length:
        raise ValueError("color-mapped TGA images are not supported")
    if image_type not in (2, 3, 10, 11):
        raise ValueError(f"unsupported TGA image type: {image_type}")
    if bits_per_pixel not in (8, 24, 32):
        raise ValueError(f"unsupported pixel depth: {bits_per_pixel}")
    if width <= 0 or height <= 0:
        raise ValueError("invalid image dimensions")

    bytes_per_pixel = bits_per_pixel // 8
    offset = 18 + id_length
    pixel_count = width * height

    if image_type in (2, 3):
        byte_count = pixel_count * bytes_per_pixel
        pixels = data[offset : offset + byte_count]
        if len(pixels) != byte_count:
            raise ValueError("TGA pixel data is truncated")
    else:
        pixels = bytearray()
        while len(pixels) < pixel_count * bytes_per_pixel:
            if offset >= len(data):
                raise ValueError("TGA RLE data is truncated")
            chunk_header = data[offset]
            offset += 1
            chunk_length = (chunk_header & 0x7F) + 1
            if chunk_header & 0x80:
                pixel = data[offset : offset + bytes_per_pixel]
                offset += bytes_per_pixel
                if len(pixel) != bytes_per_pixel:
                    raise ValueError("TGA RLE packet is truncated")
                pixels.extend(pixel * chunk_length)
            else:
                byte_count = chunk_length * bytes_per_pixel
                chunk = data[offset : offset + byte_count]
                offset += byte_count
                if len(chunk) != byte_count:
                    raise ValueError("TGA raw packet is truncated")
                pixels.extend(chunk)
        pixels = bytes(pixels[: pixel_count * bytes_per_pixel])

    rows = []
    top_origin = bool(image_descriptor & 0x20)
    right_origin = bool(image_descriptor & 0x10)

    for y in range(height):
        source_y = y if top_origin else height - 1 - y
        row_start = source_y * width * bytes_per_pixel
        row = pixels[row_start : row_start + width * bytes_per_pixel]

        converted = bytearray()
        for x in range(width):
            source_x = width - 1 - x if right_origin else x
            pixel_start = source_x * bytes_per_pixel
            pixel = row[pixel_start : pixel_start + bytes_per_pixel]
            if bytes_per_pixel == 1:
                converted.extend(pixel)
            elif bytes_per_pixel == 3:
                b, g, r = pixel
                converted.extend((r, g, b))
            else:
                b, g, r, a = pixel
                converted.extend((r, g, b, a))
        rows.append(bytes(converted))

    color_type = {1: 0, 3: 2, 4: 6}[bytes_per_pixel]
    return width, height, color_type, rows


def png_chunk(kind, payload):
    crc = binascii.crc32(kind)
    crc = binascii.crc32(payload, crc) & 0xFFFFFFFF
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", crc)


def write_png(path, width, height, color_type, rows):
    scanlines = b"".join(b"\x00" + row for row in rows)
    payload = struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0)
    png = [
        b"\x89PNG\r\n\x1a\n",
        png_chunk(b"IHDR", payload),
        png_chunk(b"IDAT", zlib.compress(scanlines)),
        png_chunk(b"IEND", b""),
    ]
    path.write_bytes(b"".join(png))


def main():
    parser = argparse.ArgumentParser(description="Convert a TGA image to PNG.")
    parser.add_argument("input", nargs="?", default="framebuffer.tga")
    parser.add_argument("output", nargs="?", default="framebuffer.png")
    args = parser.parse_args()

    source = Path(args.input)
    destination = Path(args.output)

    width, height, color_type, rows = read_tga(source)
    write_png(destination, width, height, color_type, rows)
    print(f"wrote {destination} ({width}x{height})")


if __name__ == "__main__":
    main()
