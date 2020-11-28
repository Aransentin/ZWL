const std = @import("std");
const zwl = @import("zwl");

const Platform = zwl.Platform(.{
    .render_software = true,
    .single_window = true,
    .remote = true,
    .hdr = false,
    .platforms_enabled = .{ .x11 = true, .wayland = false, .windows = false },
});

//var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//const global_allocator = &gpa.allocator;

// Temporary main wrapper to make all errors unreachable,
// to see how small I can make the binary
pub fn main() void {
    // defer _ = gpa.deinit();
    innerMain() catch unreachable;
}

fn innerMain() !void {
    var platform = try Platform.init(std.heap.page_allocator, .{});
    defer platform.deinit();

    const window = try platform.createWindow(.{ .title = "Demo", .width = 512, .height = 512, .resizeable = false, .visible = true, .decorations = true, .track_damage = true, .track_vblank = true });
    defer window.deinit();

    var prev_ts = std.time.nanoTimestamp();

    while (true) {
        const event = try platform.waitForEvent();
        switch (event) {
            .WindowDamaged => |damage| {
                std.log.info("Window damaged: {}x{} @ {}x{}", .{ damage.w, damage.h, damage.x, damage.y });
                try paint(damage.window, prev_ts);
            },
            .WindowVBlank => |win| {
                var new_ts = std.time.nanoTimestamp();
                const diff = new_ts - prev_ts;
                // std.debug.print("{}\n", .{diff});
                prev_ts = new_ts;
                try paint(win, new_ts);
            },
            .WindowResized => |win| {
                const size = win.getSize();
                std.log.info("Window resized: {}x{}", .{ size[0], size[1] });
            },
            .WindowDestroyed => |win| {
                std.log.info("Window destroyed", .{});
                return;
            },
            .PlatformTerminated => {
                return;
            },
            // else => {},
        }
    }
}

fn paint(window: anytype, ts: i128) !void {
    const pixbuf = try window.mapPixels();
    var y: u16 = 0;
    while (y < pixbuf.height) : (y += 1) {
        var x: u16 = 0;
        while (x < pixbuf.width) : (x += 1) {
            const pos = @intCast(u128, ts) / 1000000;
            const yeet = @intCast(u8, (x + pos) % 256);
            const pixel = [4]u8{ yeet, yeet, yeet, 0 };
            pixbuf.setPixel(x, y, @bitCast(u32, pixel));
        }
    }
    const updates = [_]zwl.UpdateArea{.{ .x = 0, .y = 0, .w = pixbuf.width, .h = pixbuf.height }};
    try window.submitPixels(&updates);
}
