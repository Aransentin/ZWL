const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const x11 = @import("x11.zig");
const wayland = @import("wayland.zig");
const windows = @import("windows.zig");
const xlib = @import("xlib.zig");

pub const PlatformType = enum {
    Xlib,
    X11,
    Wayland,
    Windows,
};

pub const PlatformsEnabled = struct {
    x11: bool = if (builtin.os.tag == .linux) true else false,
    wayland: bool = if (builtin.os.tag == .linux) true else false,
    windows: bool = if (builtin.os.tag == .windows) true else false,
    /// The Xlib backend provides OpenGL features for all platforms. Fuck NVIDIA for us requiring to do this!
    xlib: bool = false,
};

pub const OpenGlVersion = struct {
    major: u8,
    minor: u8,
    core: bool = true, // enable core profile
};

/// This enum lists all possible render backends ZWL can initialize on a window.
pub const Backend = union(enum) {
    /// Initialize no render backend, the window is just a raw window handle.
    none,

    /// Initialize basic software rendering. This enables the `mapPixels` and `submitPixels` functions.
    software,

    /// Initializes a OpenGL context for the window. The given version is the minimum version required.
    opengl: OpenGlVersion,

    /// Creates a vulkan swapchain for the window.
    vulkan,
};

pub const BackendEnabled = struct {
    /// When this is enabled, you can create windows that allow mapping their pixel content
    /// into system memory and allow framebuffer modification by the CPU.
    /// Create the window with Backend.software to use this feature.
    software: bool = false,

    /// When this is enabled, you can create windows that export an OpenGL context.
    /// Create the window with Backend.opengl to use this feature.
    opengl: bool = false,

    /// When this is enabled, you can create windows that export a Vulkan swap chain.
    /// In addition to that, the Platform itself will try initializing vulkan and provide
    /// access to a vkInstance.
    /// Create the window with Backend.vulkan to use this feature.
    vulkan: bool = false,
};

/// Global compile-time platform settings
pub const PlatformSettings = struct {
    /// The list of platforms you'd like to compile in support for.
    platforms_enabled: PlatformsEnabled = .{},

    /// Specify which rendering backends you want to compile in support for.
    /// You probably don't want to enable hardware rendering on Linux without linking XCB/Xlib or libwayland.
    backends_enabled: BackendEnabled = .{},

    /// If you need to track data about specific monitors, set this to true. Usually not needed for
    /// always-windowed applications or programs that don't need explicit control on what monitor to
    /// fullscreen themselves on.
    monitors: bool = false,

    // Set this to "true" if you're never creating more than a single window. Doing so
    // simplifies the internal library bookkeeping, but means any call to
    // createWindow() is undefined behaviour if a window already exists.
    single_window: bool = false,

    /// Specify if you want to be able to render to a remote server over TCP. This only works on X11 with software rendering
    /// and has quite poor performance. Does not affect X11 on Windows as the TCP connection is the only way it works.
    remote: bool = false,

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
        // todo: stuff
    } = .{},

    windows: struct {
        // todo: stuff
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
};

/// Options for windows
pub const WindowOptions = struct {
    /// The title of the window. Ignored if the platform does not support it. If specifying a title is not optional
    /// for the current platform, a null title will be interpreted as an empty string.
    title: ?[]const u8 = null,

    width: ?u16 = null,
    height: ?u16 = null,
    visible: ?bool = null,
    mode: ?WindowMode = null,

    /// Whether the user is allowed to resize the window or not. Note that this is more of a suggestion,
    /// and the window manager could resize us anyway if it so chooses.
    resizeable: ?bool = null,

    /// Set this to "true" you want the default system border and title bar with the name, buttons, etc. when windowed.
    /// Set this to "false" if you're a time traveller from 1999 developing your latest winamp skin or something.
    decorations: ?bool = null,

    /// Set 'transparent' to true if you'd like to get pixels with an alpha component, so that parts of your window
    /// can be made transparent. Note that this will only work if the platform has a compositor running.
    transparent: ?bool = null,

    /// This means that the event callback will notify you if any of your window is "damaged", i.e.
    /// needs to be re-rendered due to (for example) another window having covered part of it.
    /// Not needed if you're constantly re-rendering the entire window anyway.
    track_damage: ?bool = null,

    /// This means that mouse motion and click events will be tracked.
    track_mouse: ?bool = null,

    /// This means that keyboard events will be tracked.
    track_keyboard: ?bool = null,

    /// This defines the render backend ZWL will initialize.
    backend: Backend = Backend.none,
};

pub const EventType = enum {
    WindowResized,
    WindowDestroyed,
    WindowDamaged,
    WindowVBlank,
    ApplicationTerminated,
    KeyDown,
    KeyUp,
    MouseButtonDown,
    MouseButtonUp,
    MouseMotion,
};

pub const KeyEvent = struct {
    scancode: u32,
};

pub const MouseMotionEvent = struct {
    x: i16,
    y: i16,
};

pub const MouseButtonEvent = struct {
    x: i16,
    y: i16,
    button: MouseButton,
};

pub const MouseButton = enum(u8) {
    left = 1,
    middle = 2,
    right = 3,
    wheel_up = 4,
    wheel_down = 5,
    nav_backward = 6,
    nav_forward = 7,
    _,
};

pub fn Platform(comptime _settings: PlatformSettings) type {
    return struct {
        const Self = @This();
        pub const settings = _settings;
        pub const PlatformX11 = x11.Platform(Self);
        pub const PlatformWayland = wayland.Platform(Self);
        pub const PlatformWindows = windows.Platform(Self);
        pub const PlatformXlib = xlib.Platform(Self);

        type: PlatformType,
        allocator: *Allocator,
        window: if (settings.single_window) ?*Window else void,
        windows: if (settings.single_window) void else []*Window,

        pub fn init(allocator: *Allocator, options: PlatformOptions) !*Self {
            if (settings.platforms_enabled.xlib) blk: {
                return PlatformXlib.init(allocator, options) catch break :blk;
            }
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
                .Xlib => if (!settings.platforms_enabled.xlib) unreachable else PlatformXlib.deinit(@ptrCast(*PlatformXlib, self)),
            }
        }

        pub fn waitForEvent(self: *Self) anyerror!Event {
            return switch (self.type) {
                .X11 => if (!settings.platforms_enabled.x11) unreachable else PlatformX11.waitForEvent(@ptrCast(*PlatformX11, self)),
                .Wayland => if (!settings.platforms_enabled.wayland) unreachable else PlatformWayland.waitForEvent(@ptrCast(*PlatformWayland, self)),
                .Windows => if (!settings.platforms_enabled.windows) unreachable else PlatformWindows.waitForEvent(@ptrCast(*PlatformWindows, self)),
                .Xlib => if (!settings.platforms_enabled.xlib) unreachable else PlatformXlib.waitForEvent(@ptrCast(*PlatformXlib, self)),
            };
        }

        pub fn createWindow(self: *Self, options: WindowOptions) anyerror!*Window {
            const window = try switch (self.type) {
                .X11 => if (!settings.platforms_enabled.x11) unreachable else PlatformX11.createWindow(@ptrCast(*PlatformX11, self), options),
                .Wayland => if (!settings.platforms_enabled.wayland) unreachable else PlatformWayland.createWindow(@ptrCast(*PlatformWayland, self), options),
                .Windows => if (!settings.platforms_enabled.windows) unreachable else PlatformWindows.createWindow(@ptrCast(*PlatformWindows, self), options),
                .Xlib => if (!settings.platforms_enabled.xlib) unreachable else PlatformXlib.createWindow(@ptrCast(*PlatformXlib, self), options),
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

        pub fn getOpenGlProcAddress(self: *Self, entry_point: [:0]const u8) ?*c_void {
            return switch (self.type) {
                .X11 => if (!settings.platforms_enabled.x11) unreachable else PlatformX11.getOpenGlProcAddress(@ptrCast(*PlatformX11, self), entry_point),
                .Wayland => if (!settings.platforms_enabled.wayland) unreachable else PlatformWayland.getOpenGlProcAddress(@ptrCast(*PlatformWayland, self), entry_point),
                .Windows => if (!settings.platforms_enabled.windows) unreachable else PlatformWindows.getOpenGlProcAddress(@ptrCast(*PlatformWindows, self), entry_point),
                .Xlib => if (!settings.platforms_enabled.xlib) unreachable else PlatformXlib.getOpenGlProcAddress(@ptrCast(*PlatformXlib, self), entry_point),
            };
        }

        pub const Event = union(EventType) {
            WindowResized: *Window,
            WindowDestroyed: *Window,
            WindowDamaged: struct { window: *Window, x: u16, y: u16, w: u16, h: u16 },
            WindowVBlank: *Window,
            ApplicationTerminated: void,
            KeyDown: KeyEvent,
            KeyUp: KeyEvent,
            MouseButtonDown: MouseButtonEvent,
            MouseButtonUp: MouseButtonEvent,
            MouseMotion: MouseMotionEvent,
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
                    .Xlib => if (!settings.platforms_enabled.xlib) unreachable else PlatformXlib.Window.deinit(@ptrCast(*PlatformXlib.Window, self)),
                };
            }

            pub fn configure(self: *Window, options: WindowOptions) !void {
                return switch (self.platform.type) {
                    .X11 => if (!settings.platforms_enabled.x11) unreachable else PlatformX11.Window.configure(@ptrCast(*PlatformX11.Window, self), options),
                    .Wayland => if (!settings.platforms_enabled.wayland) unreachable else PlatformWayland.Window.configure(@ptrCast(*PlatformWayland.Window, self), options),
                    .Windows => if (!settings.platforms_enabled.windows) unreachable else PlatformWindows.Window.configure(@ptrCast(*PlatformWindows.Window, self), options),
                    .Xlib => if (!settings.platforms_enabled.xlib) unreachable else PlatformXlib.Window.configure(@ptrCast(*PlatformXlib.Window, self), options),
                };
            }

            pub fn getSize(self: *Window) [2]u16 {
                return switch (self.platform.type) {
                    .X11 => if (!settings.platforms_enabled.x11) unreachable else PlatformX11.Window.getSize(@ptrCast(*PlatformX11.Window, self)),
                    .Wayland => if (!settings.platforms_enabled.wayland) unreachable else PlatformWayland.Window.getSize(@ptrCast(*PlatformWayland.Window, self)),
                    .Windows => if (!settings.platforms_enabled.windows) unreachable else PlatformWindows.Window.getSize(@ptrCast(*PlatformWindows.Window, self)),
                    .Xlib => if (!settings.platforms_enabled.xlib) unreachable else PlatformXlib.Window.getSize(@ptrCast(*PlatformXlib.Window, self)),
                };
            }

            pub fn present(self: *Window) !void {
                return switch (self.platform.type) {
                    .X11 => @panic("not implemented yet!"),
                    .Wayland => @panic("not implemented yet!"),
                    .Windows => if (!settings.platforms_enabled.windows) unreachable else PlatformWindows.Window.present(@ptrCast(*PlatformWindows.Window, self)),
                    .Xlib => if (!settings.platforms_enabled.xlib) unreachable else PlatformXlib.Window.present(@ptrCast(*PlatformXlib.Window, self)),
                };
            }

            pub fn mapPixels(self: *Window) anyerror!PixelBuffer {
                return switch (self.platform.type) {
                    .X11 => if (!settings.platforms_enabled.x11) unreachable else PlatformX11.Window.mapPixels(@ptrCast(*PlatformX11.Window, self)),
                    .Wayland => if (!settings.platforms_enabled.wayland) unreachable else PlatformWayland.Window.mapPixels(@ptrCast(*PlatformWayland.Window, self)),
                    .Windows => if (!settings.platforms_enabled.windows) unreachable else PlatformWindows.Window.mapPixels(@ptrCast(*PlatformWindows.Window, self)),
                    .Xlib => if (!settings.platforms_enabled.xlib) unreachable else PlatformXlib.Window.mapPixels(@ptrCast(*PlatformXlib.Window, self)),
                };
            }

            pub fn submitPixels(self: *Window, updates: []const UpdateArea) !void {
                return switch (self.platform.type) {
                    .X11 => if (!settings.platforms_enabled.x11) unreachable else PlatformX11.Window.submitPixels(@ptrCast(*PlatformX11.Window, self), updates),
                    .Wayland => if (!settings.platforms_enabled.wayland) unreachable else PlatformWayland.Window.submitPixels(@ptrCast(*PlatformWayland.Window, self), updates),
                    .Windows => if (!settings.platforms_enabled.windows) unreachable else PlatformWindows.Window.submitPixels(@ptrCast(*PlatformWindows.Window, self), updates),
                    .Xlib => if (!settings.platforms_enabled.xlib) unreachable else PlatformXlib.Window.submitPixels(@ptrCast(*PlatformXlib.Window, self), updates),
                };
            }
        };
    };
}

pub const Pixel = extern struct {
    //  TODO: Maybe make this *order* platform dependent!
    b: u8,
    g: u8,
    r: u8,
    a: u8 = 0xFF,
};

pub const UpdateArea = struct {
    x: u16,
    y: u16,
    w: u16,
    h: u16,
};

pub const PixelBuffer = struct {
    const Self = @This();

    data: [*]u32,
    // todo: format as well
    width: u16,
    height: u16,

    pub inline fn setPixel(self: Self, x: usize, y: usize, color: Pixel) void {
        self.data[self.width * y + x] = @bitCast(u32, color);
    }

    pub inline fn getPixel(self: Self, x: usize, y: usize) Pixel {
        return @bitCast(Pixel, self.data[self.width * y + x]);
    }

    pub fn span(self: Self) []u32 {
        return self.data[0 .. @as(usize, self.width) * @as(usize, self.height)];
    }
};

comptime {
    std.debug.assert(@sizeOf(Pixel) == 4);
    std.debug.assert(@bitSizeOf(Pixel) == 32);
}
