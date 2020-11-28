const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const x11 = @import("x11/x11.zig");
const wayland = @import("wayland/wayland.zig");
const windows = @import("windows/windows.zig");

pub const PlatformType = enum {
    X11,
    Wayland,
    Windows,
};

pub const PlatformsEnabled = struct {
    x11: bool = if (builtin.os.tag == .linux) true else false,
    wayland: bool = if (builtin.os.tag == .linux) true else false,
    windows: bool = if (builtin.os.tag == .windows) true else false,
};

/// Global compile-time platform settings
pub const PlatformSettings = struct {
    /// The list of platforms you'd like to compile in support for.
    platforms_enabled: PlatformsEnabled = .{},

    /// If you need to track data about specific monitors, set this to true. Usually not needed for
    /// always-windowed applications or programs that don't need explicit control on what monitor to
    /// fullscreen themselves on.
    monitors: bool = false,

    /// Set this to "true" if you're never creating more than a single window. Doing so
    /// simplifies the internal library bookkeeping, but means any call to
    /// createWindow() is undefined behaviour if a window already exists.
    single_window: bool = false,

    /// Specify if you want to do hardware or software rendering, or both. Or neither, if you just
    /// want to look at a blank window or something.
    /// You probably don't want to enable hardware rendering on Linux without linking XCB/Xlib or libwayland.
    render_software: bool = false,
    render_hardware: bool = false,

    /// Specify if you want to be able to render to a remote server over TCP. This only works on X11 with software rendering
    /// and has quite poor performance. Does not affect X11 on Windows as the TCP connection is the only way it works.
    remote: bool = false,

    /// There is one Vulkan extension (VK_EXT_acquire_xlib_display) that only exists for Xlib, not XCB, If
    /// this is enabled, Xlib is linked instead and an XCB connection is acquired through that so this
    /// extension can be used.
    xcb_through_xlib: bool = false,

    /// If you set 'hdr' to true, the pixel buffer(s) you get is in the native window/monitor colour depth,
    /// which can have more (or fewer, technically) than 8 bits per colour.
    /// If false, the library will always give you an 8-bit buffer and automatically convert it to
    /// the native depth for you if needed.
    hdr: bool = false,
};

/// Backend-specific runtime options.
pub const PlatformOptions = struct {
    x11: struct {
        /// The X11 host we will connect to. 'null' here means using the DISPLAY environment variable,
        /// parsed in the same manner as XCB. Specifying "localhost" or a zero-length string will use
        /// a Unix domain socket if supported by the OS.
        /// Note that ZWL does not support the really ancient protocol specification syntax (i.e. proto/host),
        /// used e.g. for DECnet and will instead treat it as a malformed host.
        host: ?[]const u8 = null,

        /// What X11 display to connect to. Practically always 0 for modern X11.
        /// 'null' here means using the DISPLAY environment variable, parsed in the same manner as XCB.
        display: ?u6 = null,

        /// What X11 screen to use. Practically always 0 for modern X11.
        /// 'null' here means using the DISPLAY environment variable, parsed in the same manner as XCB.
        screen: ?u8 = null,

        /// The X11 MIT-MAGIC-COOKIE-1 to be used during authentication.
        /// 'null' here means reading it from the .Xauthority file
        mit_magic_cookie: ?[16]u8 = null,

        /// The location of the X11 .Xauthority file, used if mit_magic_cookie is null.
        /// 'null' here means reading it from the XAUTHORITY environment variable.
        xauthority_location: ?[]const u8 = null,
    } = .{},

    wayland: struct {
        // Todo
    } = .{},

    windows: struct {
        // Todo
    } = .{},
};

/// The window mode. All options degrade downwards towards the following option if not supported by the platform.
pub const WindowMode = enum {
    //// The window is an icon on the system tray.
    Systray,

    //// The window is minimized to the taskbar.
    Minimized,

    /// A normal desktop window.
    Windowed,

    /// A normal desktop window, resized so that it covers the entire screen. Compared to proper fullscreen
    /// this does not bypass the compositor, which usually adds one frame of latency and degrades performance slightly.
    /// The upside is that switching desktops or alt-tabbing from this application to another is much faster.
    WindowedFullscreen,

    /// A normal fullscreen window.
    Fullscreen,
};

pub const EventType = enum {
    WindowResized,
    WindowDestroyed,
    WindowDamaged,
    WindowVBlank,
    PlatformTerminated,
};

/// Options for windows
pub const WindowOptions = struct {
    /// The title of the window. Ignored if the platform does not support it. If specifying a title is not optional
    /// for the current platform, a null title will be interpreted as an empty string.
    title: ?[]const u8 = null,

    width: u16 = 1024,
    height: u16 = 600,
    visible: bool = true,
    mode: WindowMode = .Windowed,

    /// Whether the user is allowed to resize the window or not. Note that this is more of a suggestion,
    /// and the window manager could resize us anyway if it so chooses.
    resizeable: bool = true,

    /// Set this to "true" you want the default system border and title bar with the name, buttons, etc. when windowed.
    /// Set this to "false" if you're a time traveller from 1999 developing your latest winamp skin or something.
    decorations: bool = true,

    /// Set 'transparent' to true if you'd like to get pixels with an alpha component, so that parts of your window
    /// can be made transparent. Note that this will only work if the platform has a compositor running.
    transparent: bool = false,

    /// This means you will get an event every time vblank happens after you've submitted a pixel update.
    track_vblank: bool = false,

    /// This means that the event callback will notify you if any of your window is "damaged", i.e.
    /// needs to be re-rendered due to (for example) another window having covered part of it.
    /// Not needed if you're constantly re-rendering the entire window anyway.
    track_damage: bool = false,

    /// This means that mouse motion and click events will be tracked.
    track_mouse: bool = false,

    /// This means that keyboard events will be tracked.
    track_keyboard: bool = false,
};

pub fn Platform(comptime _settings: PlatformSettings) type {
    return struct {
        const Self = @This();
        pub const settings = _settings;
        pub const PlatformX11 = x11.Platform(Self);
        pub const PlatformWayland = wayland.Platform(Self);
        pub const PlatformWindows = windows.Platform(Self);

        type: PlatformType,
        allocator: *Allocator,
        window: if (!settings.single_window) void else ?*Window,
        windows: if (settings.single_window) void else []*Window,

        pub fn init(allocator: *Allocator, options: PlatformOptions) !*Self {
            if (settings.platforms_enabled.wayland) blk: {
                return PlatformWayland.init(allocator, options) catch break :blk;
            }
            if (settings.platforms_enabled.x11) blk: {
                return PlatformX11.init(allocator, options) catch break :blk;
            }
            if (settings.platforms_enabled.windows) blk: {
                return PlatformWindows.init(allocator, options) catch break :blk;
            }
            return error.NoPlatformAvailable;
        }

        pub fn deinit(self: *Self) void {
            switch (self.type) {
                .X11 => if (!settings.platforms_enabled.x11) unreachable else PlatformX11.deinit(@ptrCast(*PlatformX11, self)),
                .Wayland => if (!settings.platforms_enabled.wayland) unreachable else PlatformWayland.deinit(@ptrCast(*PlatformWayland, self)),
                .Windows => if (!settings.platforms_enabled.windows) unreachable else PlatformWindows.deinit(@ptrCast(*PlatformWindows, self)),
            }
        }

        pub fn waitForEvent(self: *Self) anyerror!Event {
            return switch (self.type) {
                .X11 => if (!settings.platforms_enabled.x11) unreachable else PlatformX11.waitForEvent(@ptrCast(*PlatformX11, self)),
                .Wayland => if (!settings.platforms_enabled.wayland) unreachable else PlatformWayland.waitForEvent(@ptrCast(*PlatformWayland, self)),
                .Windows => if (!settings.platforms_enabled.windows) unreachable else PlatformWindows.waitForEvent(@ptrCast(*PlatformWindows, self)),
            };
        }

        pub fn createWindow(self: *Self, options: WindowOptions) anyerror!*Window {
            const window = try switch (self.type) {
                .X11 => if (!settings.platforms_enabled.x11) unreachable else PlatformX11.createWindow(@ptrCast(*PlatformX11, self), options),
                .Wayland => if (!settings.platforms_enabled.wayland) unreachable else PlatformWayland.createWindow(@ptrCast(*PlatformWayland, self), options),
                .Windows => if (!settings.platforms_enabled.windows) unreachable else PlatformWindows.createWindow(@ptrCast(*PlatformWindows, self), options),
            };
            errdefer window.deinit();
            if (settings.single_window) {
                self.window = window;
            } else {
                self.windows = try self.allocator.realloc(self.windows, self.windows.len + 1);
                self.windows[self.windows.len - 1] = window;
            }
            return window;
        }

        pub const Event = union(EventType) {
            WindowResized: *Window,
            WindowDestroyed: *Window,
            WindowDamaged: struct { window: *Window, x: u16, y: u16, w: u16, h: u16 },
            WindowVBlank: *Window,
            PlatformTerminated: void,
        };

        pub const Window = struct {
            platform: *Self,

            pub fn deinit(self: *Window) void {
                if (settings.single_window) {
                    self.platform.window = null;
                } else {
                    for (self.platform.windows) |*w, i| {
                        if (w.* == self) {
                            w.* = self.platform.windows[self.platform.windows.len - 1];
                            break;
                        }
                    }
                    self.platform.windows = self.platform.allocator.realloc(self.platform.windows, self.platform.windows.len - 1) catch unreachable;
                }
                return switch (self.platform.type) {
                    .X11 => if (!settings.platforms_enabled.x11) unreachable else PlatformX11.Window.deinit(@ptrCast(*PlatformX11.Window, self)),
                    .Wayland => if (!settings.platforms_enabled.wayland) unreachable else PlatformWayland.Window.deinit(@ptrCast(*PlatformWayland.Window, self)),
                    .Windows => if (!settings.platforms_enabled.windows) unreachable else PlatformWindows.Window.deinit(@ptrCast(*PlatformWindows.Window, self)),
                };
            }

            pub fn getSize(self: *Window) [2]u16 {
                return switch (self.platform.type) {
                    .X11 => if (!settings.platforms_enabled.x11) unreachable else PlatformX11.Window.getSize(@ptrCast(*PlatformX11.Window, self)),
                    .Wayland => if (!settings.platforms_enabled.wayland) unreachable else PlatformWayland.Window.getSize(@ptrCast(*PlatformWayland.Window, self)),
                    .Windows => if (!settings.platforms_enabled.windows) unreachable else PlatformWindows.Window.getSize(@ptrCast(*PlatformWindows.Window, self)),
                };
            }

            pub fn setConfiguration(self: *Window, x: i16, y: i16, width: u16, height: u16) !void {
                return switch (self.platform.type) {
                    .X11 => if (!settings.platforms_enabled.x11) unreachable else PlatformX11.Window.setConfiguration(@ptrCast(*PlatformX11.Window, self), x, y, width, height),
                    .Wayland => if (!settings.platforms_enabled.wayland) unreachable else PlatformWayland.Window.setConfiguration(@ptrCast(*PlatformWayland.Window, self), x, y, width, height),
                    .Windows => if (!settings.platforms_enabled.windows) unreachable else PlatformWindows.Window.setConfiguration(@ptrCast(*PlatformWindows.Window, self), x, y, width, height),
                };
            }

            pub fn mapPixels(self: *Window) !PixelBuffer {
                return switch (self.platform.type) {
                    .X11 => if (!settings.platforms_enabled.x11) unreachable else PlatformX11.Window.mapPixels(@ptrCast(*PlatformX11.Window, self)),
                    .Wayland => if (!settings.platforms_enabled.wayland) unreachable else PlatformWayland.Window.mapPixels(@ptrCast(*PlatformWayland.Window, self)),
                    .Windows => if (!settings.platforms_enabled.windows) unreachable else PlatformWindows.Window.mapPixels(@ptrCast(*PlatformWindows.Window, self)),
                };
            }

            pub fn submitPixels(self: *Window, updates: []const UpdateArea) !void {
                return switch (self.platform.type) {
                    .X11 => if (!settings.platforms_enabled.x11) unreachable else PlatformX11.Window.submitPixels(@ptrCast(*PlatformX11.Window, self), updates),
                    .Wayland => if (!settings.platforms_enabled.wayland) unreachable else PlatformWayland.Window.submitPixels(@ptrCast(*PlatformWayland.Window, self), updates),
                    .Windows => if (!settings.platforms_enabled.windows) unreachable else PlatformWindows.Window.submitPixels(@ptrCast(*PlatformWindows.Window, self), updates),
                };
            }
        };
    };
}

pub const UpdateArea = struct {
    x: u16,
    y: u16,
    w: u16,
    h: u16,
};

pub const BufferFormat = enum {
    BGR8,
    BGRA8,
    BGR10,
};

pub const PixelBuffer = struct {
    const Self = @This();
    format: BufferFormat,
    data: [*]align(16) u32,
    width: u16,
    height: u16,
    pub inline fn setPixel(self: Self, x: usize, y: usize, pixel: u32) void {
        self.data[self.width * y + x] = pixel;
    }
};
