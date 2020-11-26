const std = @import("std");

const windows = @import("../windows.zig").windows;
usingnamespace @import("bits.zig");

pub const HBITMAP = *opaque {
    pub fn toGdiObject(self: HBITMAP) HGDIOBJ {
        return @ptrCast(HGDIOBJ, self);
    }
};
pub const HGDIOBJ = *opaque {};

pub const Compression = extern enum {
    BI_RGB = 0x0000,
    BI_RLE8 = 0x0001,
    BI_RLE4 = 0x0002,
    BI_BITFIELDS = 0x0003,
    BI_JPEG = 0x0004,
    BI_PNG = 0x0005,
    BI_CMYK = 0x000B,
    BI_CMYKRLE8 = 0x000C,
    BI_CMYKRLE4 = 0x000D,
};

pub const DIBColors = extern enum {
    DIB_RGB_COLORS = 0x00,
    DIB_PAL_COLORS = 0x01,
    DIB_PAL_INDICES = 0x02,
};

pub const BITMAPINFOHEADER = extern struct {
    biSize: DWORD = @SizeOf(@This()),
    biWidth: LONG,
    biHeight: LONG,
    biPlanes: WORD,
    biBitCount: WORD,
    biCompression: DWORD,
    biSizeImage: DWORD,
    biXPelsPerMeter: LONG,
    biYPelsPerMeter: LONG,
    biClrUsed: DWORD,
    biClrImportant: DWORD,
};

pub const RGBQUAD = extern struct {
    rgbBlue: BYTE,
    rgbGreen: BYTE,
    rgbRed: BYTE,
    rgbReserved: BYTE,
};

pub const BITMAPINFO = extern struct {
    bmiHeader: BITMAPINFOHEADER,
    bmiColors: [1]RGBQUAD, // dynamic size...
};

pub const TernaryRasterOperation = extern enum {
    SRCCOPY = 0x00CC0020, // dest = source
    SRCPAINT = 0x00EE0086, // dest = source OR dest
    SRCAND = 0x008800C6, // dest = source AND dest
    SRCINVERT = 0x00660046, // dest = source XOR dest
    SRCERASE = 0x00440328, // dest = source AND (NOT dest )
    NOTSRCCOPY = 0x00330008, // dest = (NOT source)
    NOTSRCERASE = 0x001100A6, // dest = (NOT src) AND (NOT dest)
    MERGECOPY = 0x00C000CA, // dest = (source AND pattern)
    MERGEPAINT = 0x00BB0226, // dest = (NOT source) OR dest
    PATCOPY = 0x00F00021, // dest = pattern
    PATPAINT = 0x00FB0A09, // dest = DPSnoo
    PATINVERT = 0x005A0049, // dest = pattern XOR dest
    DSTINVERT = 0x00550009, // dest = (NOT dest)
    BLACKNESS = 0x00000042, // dest = BLACK
    WHITENESS = 0x00FF0062, // dest = WHITE
};

pub extern "gdi32" fn CreateDIBSection(
    hdc: HDC,
    pbmi: *const BITMAPINFO,
    usage: UINT,
    ppvBits: **c_void,
    hSection: ?HANDLE,
    offset: DWORD,
) callconv(WINAPI) ?HBITMAP;

pub extern "gdi32" fn DeleteObject(
    bitmap: HGDIOBJ,
) callconv(WINAPI) BOOL;

pub extern "gdi32" fn CreateCompatibleDC(
    hdc: ?HDC,
) callconv(WINAPI) ?HDC;

pub extern "gdi32" fn SelectObject(
    hdc: HDC,
    h: HGDIOBJ,
) callconv(WINAPI) HGDIOBJ;

pub extern "gdi32" fn BitBlt(
    hdc: HDC,
    x: c_int,
    y: c_int,
    cx: c_int,
    cy: c_int,
    hdcSrc: HDC,
    x1: c_int,
    y1: c_int,
    rop: DWORD,
) callconv(WINAPI) BOOL;

pub extern "gdi32" fn DeleteDC(
    hdc: HDC,
) callconv(WINAPI) BOOL;

pub extern "gdi32" fn TextOutA(
    hdc: HDC,
    x: c_int,
    y: c_int,
    lpString: [*:0]const u8,
    c: c_int,
) callconv(WINAPI) BOOL;

