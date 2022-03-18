const std = @import("std");
const zwl = @import("zwl");

const Platform = zwl.Platform(.{
    .single_window = true,
    .backends_enabled = .{
        .opengl = true,
    },
    .platforms_enabled = .{
        .wayland = true,
    },
});

pub fn main() !void {
    var platform = try Platform.init(std.heap.page_allocator, .{});
    defer platform.deinit();

    var window = try platform.createWindow(.{
        .title = "Wayland",
        .width = 512,
        .height = 512,
        .resizeable = true,
        .visible = true,
        .decorations = true,
        .track_damage = false,
        .backend = zwl.Backend{
            .opengl = zwl.OpenGlVersion{
                .major = 4,
                .minor = 60,
            },
        },
    });
    defer window.deinit();

    try eventLoop(platform);
}

fn eventLoop(platform: *Platform) !void {
    while (true) {
        const event = try platform.waitForEvent();

        switch (event) {
            .KeyDown => |key| {
                switch (key.scancode) {
                    1 => {
                        std.log.info("Esc Pressed", .{});
                        return;
                    },
                    else => {
                        std.log.info("Pressed {}", .{key.scancode});
                    },
                }
            },
            .WindowResized => |win| {
                const size = win.getSize();
                std.log.info("Window resized: {}x{}", .{ size[0], size[1] });
            },
            .WindowDestroyed => |_| {
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
