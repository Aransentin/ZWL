const std = @import("std");
const zwl = @import("zwl");

const Platform = zwl.Platform(.{
    .single_window = true,
    .backends_enabled = .{
        .software = true,
        .opengl = false,
        .vulkan = false,
    },
    .remote = true,
    .platforms_enabled = .{
        .wayland = (std.builtin.os.tag != .windows),
    },
});

var stripes: [32][4]u8 = undefined;
var logo: [70][200][4]u8 = undefined;
pub const log_level = .info;

pub fn main() !void {
    var platform = try Platform.init(std.heap.page_allocator, .{});
    defer platform.deinit();

    // init logo, stripes
    var seed_bytes: [@sizeOf(u64)]u8 = undefined;
    std.crypto.random.bytes(seed_bytes[0..]);
    var rng = std.rand.DefaultPrng.init(std.mem.readIntNative(u64, &seed_bytes));
    for (stripes) |*stripe| {
        stripe.* = .{ @as(u8, rng.random.int(u6)) + 191, @as(u8, rng.random.int(u6)) + 191, @as(u8, rng.random.int(u6)) + 191, 0 };
    }
    _ = try std.fs.cwd().readFile("logo.bgra", std.mem.asBytes(&logo));

    var window = try platform.createWindow(.{
        .title = "Softlogo",
        .width = 512,
        .height = 512,
        .resizeable = false,
        .visible = true,
        .decorations = true,
        .track_damage = false,
        .backend = .software,
    });
    defer window.deinit();

    {
        var pixbuf = try window.mapPixels();
        paint(pixbuf);
        const updates = [_]zwl.UpdateArea{.{ .x = 0, .y = 0, .w = 128, .h = 128 }};
        try window.submitPixels(&updates);
    }

    while (true) {
        const event = try platform.waitForEvent();

        switch (event) {
            .WindowVBlank => |win| {
                var pixbuf = try win.mapPixels();
                paint(pixbuf);
                const updates = [_]zwl.UpdateArea{.{ .x = 0, .y = 0, .w = pixbuf.width, .h = pixbuf.height }};
                try win.submitPixels(&updates);
            },
            .WindowResized => |win| {
                const size = win.getSize();
                std.log.info("Window resized: {}x{}", .{ size[0], size[1] });
            },
            .WindowDestroyed => |win| {
                std.log.info("Window destroyed", .{});
                return;
            },
            .ApplicationTerminated => { // Can only happen on Windows
                return;
            },
            else => {},
        }
    }
}

fn paint(pixbuf: zwl.PixelBuffer) void {
    const ts = std.time.milliTimestamp();
    const tsf = @intToFloat(f32, @intCast(usize, ts) % (60 * 1000000));

    var y: usize = 0;
    while (y < pixbuf.height) : (y += 1) {
        var x: usize = 0;
        while (x < pixbuf.width) : (x += 1) {
            const fp = @intToFloat(f32, x * 2 + y / 2) * 0.01 + tsf * 0.005;
            const background = stripes[@floatToInt(u32, fp) % stripes.len];

            const mid = [2]i32{ pixbuf.width >> 1, pixbuf.height >> 1 };
            if (x < mid[0] - 100 or x >= mid[0] + 100 or y < mid[1] - 35 or y >= mid[1] + 35) {
                pixbuf.data[y * pixbuf.width + x] = @bitCast(u32, background);
            } else {
                const tx = @intCast(usize, @intCast(isize, x) - (mid[0] - 100));
                const ty = @intCast(usize, @intCast(isize, y) - (mid[1] - 35));
                const pix = logo[ty][tx];
                const B = @intCast(u16, pix[0]) * pix[3] + @intCast(u16, background[0]) * (255 - pix[3]);
                const G = @intCast(u16, pix[1]) * pix[3] + @intCast(u16, background[1]) * (255 - pix[3]);
                const R = @intCast(u16, pix[2]) * pix[3] + @intCast(u16, background[2]) * (255 - pix[3]);
                pixbuf.data[y * pixbuf.width + x] = @bitCast(u32, [4]u8{ @intCast(u8, B >> 8), @intCast(u8, G >> 8), @intCast(u8, R >> 8), 0 });
            }
        }
    }
}
