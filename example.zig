const std = @import("std");
const zwl = @import("zwl");

const Platform = zwl.Platform(.{
    .platforms_enabled = .{ .x11 = true, .wayland = false, .windows = false },
    .single_window = false,
    .render_software = true,
    .x11_use_xcb = false,
});

pub fn main() !void {
    var platform = try Platform.init(std.heap.page_allocator, event_callback, .{});

    defer platform.deinit();

    var window = try platform.createWindow(.{ .title = "Hello ZWL", .width = 1024, .height = 512, .resizeable = false, .track_damage = true });
    defer window.destroy();
    try window.show();

    while (!program_should_exit) {
        try platform.waitForEvents();
    }
}

var program_should_exit: bool = false;

fn event_callback(event: Platform.Event) void {
    switch (event) {
        .WindowResized => |window| {
            const size = window.getSize();
            std.log.debug("*notices size {}x{}* OwO what's this", .{ size[0], size[1] });
        },
        .WindowDamaged => |damage| {
            std.log.debug("Taking damage: {}x{} @ {}x{}", .{ damage.w, damage.h, damage.x, damage.y });
            paint(damage.window) catch |err| {
                std.log.debug("Something is b0rked: {}", .{err});
                program_should_exit = true;
            };
        },
        .WindowDestroyed => |window| {
            std.log.debug("RIP", .{});
            program_should_exit = true;
        },
    }
}

fn paint(window: Platform.Window) !void {
    const pixbuf = try window.getPixelBuffer();

    var y: usize = 0;
    while (y < pixbuf.height) : (y += 1) {
        var x: usize = 0;
        while (x < pixbuf.width) : (x += 1) {
            const val = julia(@intToFloat(f32, x) / @intToFloat(f32, pixbuf.width), @intToFloat(f32, y) / @intToFloat(f32, pixbuf.height));
            var bgra = [4]u8{ val, val, val, 0 };
            pixbuf.data[y * pixbuf.width + x] = @bitCast(u32, bgra);
        }
    }
    try window.commitPixelBuffer();
}

fn julia(x: f32, y: f32) u8 {
    var seed_x: f32 = -0.4;
    var seed_y: f32 = 0.6;

    var rx = 3.0 * (x - 0.5);
    var ry = 2.0 * (y - 0.5);

    var i: u8 = 0;
    while (i < 255) : (i += 1) {
        const tx = (rx * rx - ry * ry) + seed_x;
        const ty = (ry * rx + rx * ry) + seed_y;
        if ((tx * tx + ty * ty) > 4.0) break;
        rx = tx;
        ry = ty;
    }
    return i;
}
