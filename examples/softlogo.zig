const std = @import("std");
const zwl = @import("zwl");

const Platform = zwl.Platform(.{
    .single_window = true,
    .render_software = true,
    .remote = true,
    .platforms_enabled = .{.x11=true},
});

var logo: [70][200][4]u8 = undefined;
pub const log_level = .info;

pub fn main() !void {

    var platform = try Platform.init(std.heap.page_allocator, .{});
    defer platform.deinit();

    _ = try std.fs.cwd().readFile("logo.bgra", std.mem.asBytes(&logo));

    var window = try platform.createWindow(.{ .title = "Softlogo", .width = 512, .height = 512, .resizeable = false, .visible = true, .decorations = true, .track_damage = true });
    defer window.deinit();

    while (true) {
        const event = try platform.waitForEvent();

        switch (event) {
            .WindowDamaged => |damage| {
                std.log.info("Taking damage: {}x{} @ {}x{}", .{ damage.w, damage.h, damage.x, damage.y });

                var pixbuf = try damage.window.mapPixels();
                paint(pixbuf, damage.x, damage.y, damage.w, damage.h);
                try damage.window.submitPixels();
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
        }
    }
}

fn paint(pixbuf: Platform.PixelBuffer, x: u16, y: u16, w: u16, h: u16) void {
    var yp: usize = 0;
    while (yp < pixbuf.height) : (yp += 1) {
        var xp: usize = 0;
        while (xp < pixbuf.width) : (xp += 1) {
            if (xp < x or xp > x + w) continue;
            if (yp < y or yp > y + h) continue;

            const background = [4]u8{ 255, 255, 255, 0 };
            const mid = [2]i32{ pixbuf.width >> 1, pixbuf.height >> 1 };
            if (xp < mid[0] - 100 or xp >= mid[0] + 100 or yp < mid[1] - 35 or yp >= mid[1] + 35) {
                pixbuf.data[yp * pixbuf.width + xp] = @bitCast(u32, background);
            } else {
                // std.debug.print("{}, {}\n", .{ yp, mid[1] });
                const tx = @intCast(usize, @intCast(isize, xp) - (mid[0] - 100));
                const ty = @intCast(usize, @intCast(isize, yp) - (mid[1] - 35));
                const pix = logo[ty][tx];
                const B = @intCast(u16, pix[0]) * pix[3] + @intCast(u16, background[0]) * (255 - pix[3]);
                const G = @intCast(u16, pix[1]) * pix[3] + @intCast(u16, background[1]) * (255 - pix[3]);
                const R = @intCast(u16, pix[2]) * pix[3] + @intCast(u16, background[2]) * (255 - pix[3]);
                pixbuf.data[yp * pixbuf.width + xp] = @bitCast(u32, [4]u8{ @intCast(u8, B >> 8), @intCast(u8, G >> 8), @intCast(u8, R >> 8), 0 });
            }
        }
    }
}
