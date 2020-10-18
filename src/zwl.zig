const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const way = @import("wayland.zig");
const lwl = @import("libwayland.zig");
const x11 = @import("x11.zig");
const xcb = @import("xcb.zig");
const win = @import("windows.zig");

pub const PlatformType = enum {
    Wayland,
    X11,
    Windows,
    // planned: DRM
    // planned: MacOS
    // planned: Browser
};

pub const PlatformsEnabled = struct {
    wayland: bool = if (builtin.os.tag == .linux) true else false,
    x11: bool = if (builtin.os.tag == .linux) true else false,
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

    // Set this to "true" if you're never creating more than a single window. Doing so
    // simplifies the internal library bookkeeping, but means any call to
    // createWindow() is undefined behaviour if a window already exists.
    single_window: bool = false,

    /// Specify if you want to do hardware or software rendering, or both. Or neither, if you just
    /// want to look at a blank window or something.
    /// You probably don't want to enable hardware rendering on Linux without linking XCB/Xlib or libwayland.
    render_software: bool = false,
    render_hardware: bool = false,

    /// Specify if you'd like to use XCB instead of the native Zig X11 connection. This is chiefly
    /// useful for hardware rendering when you need to hand over the connection to other rendering APIs, e.g. Vulkan.
    x11_use_xcb: bool = false,

    /// There is one Vulkan extension (VK_EXT_acquire_xlib_display) that only exists for Xlib, not XCB, If
    /// this is enabled, Xlib is linked instead and an XCB connection is acquired through that so this
    /// extension can be used.
    x11_use_xcb_through_xlib: bool = false,

    /// Specify if you'd like to use libwayland instead of the native Zig Wayland connection. This is chiefly
    /// useful for hardware rendering when you need to hand over the connection to other rendering APIs, e.g. Vulkan.
    wayland_use_libwayland: bool = false,
};

/// Backend-specific runtime options.
pub const PlatformOptions = struct {
    wayland: struct {
        // todo: stuff
    } = .{},

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
};

/// The window mode. All options degrade to "Fullscreen" if not supported by the platform.
pub const WindowMode = enum {
    /// A normal desktop window.
    Windowed,

    /// A normal desktop window, resized so that it covers the entire screen. Compared to proper fullscreen
    /// this does not bypass the compositor, which usually adds one frame of latency and degrades performance slightly.
    /// The upside is that switching desktops or alt-tabbing from this application to another is much faster.
    WindowedFullscreen,

    /// A normal fullscreen window.
    Fullscreen,

    /// Some platforms support taking exclusive control over the screen, bypassing the entire window manager.
    /// This is sometimes necessary to change certain monitor settings (e.g. colour depth on X11) and enables
    /// techniques for low-latency rendering for e.g. VR displays.
    ExclusiveFullscreen,
};

/// Options for windows.
pub const WindowOptions = struct {
    /// The title of the window. Ignored if the platform does not support it. If specifying a title is not optional
    /// for the current platform, a null title will be interpreted as an empty string.
    title: ?[]const u8,

    /// The initial width of the window, in pixels.
    width: u16,

    /// The initial height of the window, in pixels.
    height: u16,

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

    /// If you set 'hdr' to true, the pixel buffer(s) you get is in the native window/monitor colour depth,
    /// which can have more (or fewer, technically) than 8 bits per colour.
    /// If false, the library will always give you an 8-bit buffer and automatically convert it to
    /// the native depth for you if needed.
    hdr: bool = false,

    /// This means that the event callback will notify you if any of your window is "damaged", i.e.
    /// needs to be re-rendered due to (for example) another window having covered part of it.
    /// Not needed if you're constantly re-rendering the entire window anyway.
    track_damage: bool = false,

    /// If this is set to true, you will get a callback whenever vblank happens. This enables
    /// rendering to the screen at the right moment to prevent tearing and similar artefacts.
    track_vblank: bool = false,

    /// If this is set to true, the contents of the window will be saved so that you don't have to
    /// re-render anything after another window has obscured it. On some platforms (e.g. Wayland)
    /// this is mandatory so this option does nothing.
    backing_store: bool = true,
};

pub const EventType = enum {
    WindowResized,
    WindowDamaged,
    WindowDestroyed,
};

pub fn Platform(comptime _settings: PlatformSettings) type {
    return union(PlatformType) {
        const Self = @This();
        pub const settings = _settings; // So that our child platforms can see it

        const PlatformWay = if (settings.wayland_use_libwayland) lwl.Platform(Self) else way.Platform(Self);
        const PlatformX11 = if (settings.x11_use_xcb) xcb.Platform(Self) else x11.Platform(Self);
        const PlatformWin = win.Platform(Self);

        Wayland: if (settings.platforms_enabled.wayland) *PlatformWay else void,
        X11: if (settings.platforms_enabled.x11) *PlatformX11 else void,
        Windows: if (settings.platforms_enabled.windows) *PlatformWin else void,

        pub fn init(allocator: *Allocator, callback: fn (event: Event) void, options: PlatformOptions) !Self {
            if (settings.platforms_enabled.wayland) blk: {
                return PlatformWayland.init(allocator, callback, options) catch break :blk;
            }
            if (settings.platforms_enabled.x11) blk: {
                return PlatformX11.init(allocator, callback, options) catch break :blk;
            }
            if (settings.platforms_enabled.windows) blk: {
                return PlatformWindows.init(allocator, callback, options) catch break :blk;
            }
            return error.NoPlatformAvailable;
        }

        pub fn deinit(self: Self) void {
            switch (self) {
                .Wayland => |native| if (settings.platforms_enabled.wayland) native.deinit() else unreachable,
                .X11 => |native| if (settings.platforms_enabled.x11) native.deinit() else unreachable,
                .Windows => |native| if (settings.platforms_enabled.windows) native.deinit() else unreachable,
            }
        }

        pub fn waitForEvents(self: Self) !void {
            return switch (self) {
                .Wayland => |native| if (settings.platforms_enabled.wayland) native.waitForEvents() else unreachable,
                .X11 => |native| if (settings.platforms_enabled.x11) native.waitForEvents() else unreachable,
                .Windows => |native| if (settings.platforms_enabled.windows) native.waitForEvents() else unreachable,
            };
        }

        pub fn createWindow(self: Self, options: WindowOptions) !Window {
            return try switch (self) {
                .Wayland => |native| if (settings.platforms_enabled.wayland) native.createWindow(options) else unreachable,
                .X11 => |native| if (settings.platforms_enabled.x11) native.createWindow(options) else unreachable,
                .Windows => |native| if (settings.platforms_enabled.windows) native.createWindow(options) else unreachable,
            };
        }

        pub const Event = union(EventType) {
            WindowResized: Window,
            WindowDamaged: struct { window: Window, x: u16, y: u16, w: u16, h: u16 },
            WindowDestroyed: Window,
        };

        pub const Window = union(PlatformType) {
            Wayland: if (settings.platforms_enabled.wayland) *PlatformWayland.Window else void,
            X11: if (settings.platforms_enabled.x11) *PlatformX11.Window else void,
            Windows: if (settings.platforms_enabled.windows) *PlatformWindows.Window else void,

            pub fn destroy(self: Window) void {
                switch (self) {
                    .Wayland => |native| if (settings.platforms_enabled.wayland) native.destroy() else unreachable,
                    .X11 => |native| if (settings.platforms_enabled.x11) native.destroy() else unreachable,
                    .Windows => |native| if (settings.platforms_enabled.windows) native.destroy() else unreachable,
                }
            }

            pub fn show(self: Window) !void {
                try switch (self) {
                    .Wayland => |native| if (settings.platforms_enabled.wayland) native.show() else unreachable,
                    .X11 => |native| if (settings.platforms_enabled.x11) native.show() else unreachable,
                    .Windows => |native| if (settings.platforms_enabled.windows) native.show() else unreachable,
                };
            }

            pub fn hide(self: Window) !void {
                try switch (self) {
                    .Wayland => |native| if (settings.platforms_enabled.wayland) native.hide() else unreachable,
                    .X11 => |native| if (settings.platforms_enabled.x11) native.hide() else unreachable,
                    .Windows => |native| if (settings.platforms_enabled.windows) native.hide() else unreachable,
                };
            }

            pub fn getSize(self: Window) [2]u16 {
                return switch (self) {
                    .Wayland => |native| if (settings.platforms_enabled.wayland) TODO else unreachable,
                    .X11 => |native| if (settings.platforms_enabled.x11) [2]u16{ native.width, native.height } else unreachable,
                    .Windows => |native| if (settings.platforms_enabled.windows) TODO else unreachable,
                };
            }

            pub fn getPixelBuffer(self: Window) !PixelBuffer {
                return try switch (self) {
                    .Wayland => |native| if (settings.platforms_enabled.wayland) TODO else unreachable,
                    .X11 => |native| if (settings.platforms_enabled.x11) native.getPixelBuffer() else unreachable,
                    .Windows => |native| if (settings.platforms_enabled.windows) TODO else unreachable,
                };
            }

            pub fn commitPixelBuffer(self: Window) !void {
                return switch (self) {
                    .Wayland => |native| if (settings.platforms_enabled.wayland) TODO else unreachable,
                    .X11 => |native| if (settings.platforms_enabled.x11) native.commitPixelBuffer() else unreachable,
                    .Windows => |native| if (settings.platforms_enabled.windows) TODO else unreachable,
                };
            }
        };

        pub const PixelBuffer = struct {
            data: [*]u32,
            width: u16,
            height: u16,
        };
    };
}
