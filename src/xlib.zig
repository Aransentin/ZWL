const std = @import("std");
const builtin = @import("builtin");
const zwl = @import("zwl.zig");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.zwl);

pub fn Platform(comptime Parent: anytype) type {
    return struct {
        const c = @cImport({
            @cInclude("X11/X.h");
            @cInclude("X11/Xlib.h");
            if (Parent.settings.backends_enabled.opengl) {
                @cInclude("GL/gl.h");
                @cInclude("GL/glx.h");
            }
        });

        const Self = @This();
        const GlXCreateContextAttribsARB = fn (
            dpy: *c.Display,
            config: c.GLXFBConfig,
            share_context: c.GLXContext,
            direct: c.Bool,
            attrib_list: [*:0]const c_int,
        ) c.GLXContext;

        const PlatformGLData = struct {
            glxCreateContextAttribsARB: GlXCreateContextAttribsARB,
        };

        parent: Parent,

        display: *c.Display,
        root_window: c_ulong,
        gl: if (Parent.settings.backends_enabled.opengl) PlatformGLData else void,

        pub fn init(allocator: *Allocator, options: zwl.PlatformOptions) !*Parent {
            var self = try allocator.create(Self);
            errdefer allocator.destroy(self);

            var display = c.XOpenDisplay(null) orelse return error.FailedToOpenDisplay;
            errdefer _ = c.XCloseDisplay(display);

            var root = DefaultRootWindow(display); //orelse return error.FailedToGetRootWindow;

            self.* = .{
                .parent = .{
                    .allocator = allocator,
                    .type = .Xlib,
                    .window = undefined,
                    .windows = if (!Parent.settings.single_window) &[0]*Parent.Window{} else undefined,
                },
                .display = display,
                .root_window = root,
                .gl = undefined,
            };

            if (Parent.settings.backends_enabled.opengl) {
                self.gl.glxCreateContextAttribsARB = @ptrCast(
                    GlXCreateContextAttribsARB,
                    c.glXGetProcAddress("glXCreateContextAttribsARB") orelse return error.InvalidOpenGL,
                );

                var glx_major: c_int = 0;
                var glx_minor: c_int = 0;

                // FBConfigs were added in GLX version 1.3.
                if (0 == c.glXQueryVersion(display, &glx_major, &glx_minor))
                    return error.GlxFailure;
                if ((glx_major < 1) or ((glx_major == 1) and (glx_minor < 3)))
                    return error.UnsupportedGlxVersion;

                const extensions = std.mem.span(c.glXQueryExtensionsString(
                    display,
                    DefaultScreen(display),
                ));
                var ext_iter = std.mem.tokenize(extensions, " ");
                const has_ext = while (ext_iter.next()) |extension| {
                    if (std.mem.eql(u8, extension, "GLX_ARB_create_context"))
                        break true;
                } else false;
                if (!has_ext)
                    return error.UnsupportedGlxVersion;
            }

            std.log.scoped(.zwl).info("Platform Initialized: Xlib", .{});
            return @ptrCast(*Parent, self);
        }

        pub fn deinit(self: *Self) void {
            _ = c.XCloseDisplay(self.display);
            self.parent.allocator.destroy(self);
        }

        pub fn waitForEvent(self: *Self) error{}!Parent.Event {
            while (true) {
                var xev = std.mem.zeroes(c.XEvent);

                _ = c.XNextEvent(self.display, &xev);

                switch (xev.type) {
                    c.Expose => {
                        const ev = xev.xexpose;
                        if (self.getWindowById(ev.window)) |window| {
                            _ = c.XSendEvent(
                                self.display,
                                ev.window,
                                c.False,
                                c.ExposureMask,
                                &c.XEvent{
                                    .xexpose = .{
                                        .type = c.Expose,
                                        .serial = 0,
                                        .send_event = c.False,
                                        .display = self.display,
                                        .window = ev.window,
                                        .x = 0,
                                        .y = 0,
                                        .width = window.width,
                                        .height = window.height,
                                        .count = 0,
                                    },
                                },
                            );

                            return Parent.Event{
                                .WindowDamaged = .{
                                    .window = &window.parent,
                                    .x = @intCast(u16, ev.x),
                                    .y = @intCast(u16, ev.y),
                                    .w = @intCast(u16, ev.width),
                                    .h = @intCast(u16, ev.height),
                                },
                            };
                        }
                    },
                    c.KeyPress,
                    c.KeyRelease,
                    => {
                        const ev = xev.xkey;
                        if (self.getWindowById(ev.window)) |window| {
                            var kev = zwl.KeyEvent{
                                .scancode = @intCast(u8, ev.keycode - 8),
                            };

                            return switch (ev.type) {
                                c.KeyPress => Parent.Event{ .KeyDown = kev },
                                c.KeyRelease => Parent.Event{ .KeyUp = kev },
                                else => unreachable,
                            };
                        }
                    },
                    c.ButtonPress,
                    c.ButtonRelease,
                    => {
                        const ev = xev.xbutton;
                        if (self.getWindowById(ev.window)) |window| {
                            var bev = zwl.MouseButtonEvent{
                                .x = @intCast(i16, ev.x),
                                .y = @intCast(i16, ev.y),
                                .button = @intToEnum(zwl.MouseButton, @intCast(u8, ev.button)),
                            };

                            return switch (ev.type) {
                                c.ButtonPress => Parent.Event{ .MouseButtonDown = bev },
                                c.ButtonRelease => Parent.Event{ .MouseButtonUp = bev },
                                else => unreachable,
                            };
                        }
                    },
                    c.MotionNotify => {
                        const ev = xev.xmotion;
                        if (self.getWindowById(ev.window)) |window| {
                            return Parent.Event{
                                .MouseMotion = zwl.MouseMotionEvent{
                                    .x = @intCast(i16, ev.x),
                                    .y = @intCast(i16, ev.y),
                                },
                            };
                        }
                    },
                    c.CirculateNotify, c.CreateNotify, c.GravityNotify, c.MapNotify, c.ReparentNotify, c.UnmapNotify => {
                        // Whatever
                    },
                    c.ConfigureNotify => {
                        const ev = xev.xconfigure;
                        if (self.getWindowById(ev.window)) |window| {
                            if (window.width != ev.width or window.height != ev.height) {
                                window.width = @intCast(u16, ev.width);
                                window.height = @intCast(u16, ev.height);
                                return Parent.Event{ .WindowResized = @ptrCast(*Parent.Window, window) };
                            }
                        }
                    },
                    c.DestroyNotify => {
                        const ev = xev.xdestroywindow;
                        if (self.getWindowById(ev.window)) |window| {
                            window.window = 0;
                            return Parent.Event{ .WindowDestroyed = @ptrCast(*Parent.Window, window) };
                        }
                    },
                    else => {
                        log.info("unhandled event {}", .{xev.type});
                    },
                }
            }
        }

        pub fn getOpenGlProcAddress(self: *Self, entry_point: [:0]const u8) ?*c_void {
            return @intToPtr(?*c_void, @ptrToInt(c.glXGetProcAddress(entry_point.ptr)));
        }

        pub fn createWindow(self: *Self, options: zwl.WindowOptions) !*Parent.Window {
            var window = try self.parent.allocator.create(Window);
            errdefer self.parent.allocator.destroy(window);

            try window.init(self, options);

            return @ptrCast(*Parent.Window, window);
        }

        fn getWindowById(self: *Self, id: c.Window) ?*Window {
            if (Parent.settings.single_window) {
                const win = @ptrCast(*Window, self.parent.window);
                if (id == win.window)
                    return win;
            } else {
                return for (self.parent.windows) |pwin| {
                    const win = @ptrCast(*Window, pwin);
                    if (win.window == id)
                        return win;
                } else null;
            }
            return null;
    }

        const WindowGLData = struct {
            glx_context: c.GLXContext,
        };

        pub const Window = struct {
            parent: Parent.Window,
            width: u16,
            height: u16,
            window: c.Window,
            gl: if (Parent.settings.backends_enabled.opengl) ?WindowGLData else void,

            pub fn init(self: *Window, parent: *Self, options: zwl.WindowOptions) !void {
                self.* = .{
                    .parent = .{
                        .platform = @ptrCast(*Parent, parent),
                    },
                    .width = options.width orelse 800,
                    .height = options.height orelse 600,
                    .window = undefined,
                    .gl = if (Parent.settings.backends_enabled.opengl) null else {},
                };

                switch (options.backend) {
                    .opengl => |version| {
                        try self.initGL(parent, options);
                        return;
                    },
                    .none => {},
                    else => return error.NotImplementedYet,
                }

                var swa = std.mem.zeroes(c.XSetWindowAttributes);
                swa.event_mask = c.StructureNotifyMask;
                swa.event_mask |= if (options.track_damage == true) c.ExposureMask else 0;
                swa.event_mask |= if (options.track_mouse == true) c.ButtonPressMask | c.ButtonReleaseMask | c.PointerMotionMask else 0;
                swa.event_mask |= if (options.track_keyboard == true) c.KeyPressMask | c.KeyReleaseMask else 0;

                self.window = c.XCreateWindow(
                    parent.display,
                    DefaultRootWindow(parent.display),
                    0,
                    0,
                    self.width,
                    self.height,
                    0,
                    c.CopyFromParent,
                    c.InputOutput,
                    c.CopyFromParent,
                    c.CWEventMask,
                    &swa,
                );

                _ = c.XMapWindow(parent.display, self.window);
                _ = c.XStoreName(parent.display, self.window, "VERY SIMPLE APPLICATION");
            }

            fn initGL(self: *Window, parent: *Self, options: zwl.WindowOptions) !void {
                if (!Parent.settings.backends_enabled.opengl) {
                    return error.PlatformNotEnabled;
                }

                const visual_attribs = [_:0]c_int{
                    c.GLX_X_RENDERABLE,  c.True,
                    c.GLX_DRAWABLE_TYPE, c.GLX_WINDOW_BIT,
                    c.GLX_RENDER_TYPE,   c.GLX_RGBA_BIT,
                    c.GLX_X_VISUAL_TYPE, c.GLX_TRUE_COLOR,
                    c.GLX_RED_SIZE,      8,
                    c.GLX_GREEN_SIZE,    8,
                    c.GLX_BLUE_SIZE,     8,
                    c.GLX_ALPHA_SIZE,    8,
                    c.GLX_DEPTH_SIZE,    24,
                    c.GLX_STENCIL_SIZE,  8,
                    c.GLX_DOUBLEBUFFER,  c.True,
                    //GLX_SAMPLE_BUFFERS  , 1,
                    //GLX_SAMPLES         , 4,
                    c.None,
                };

                var fbcount: c_int = 0;
                const fbc: [*]c.GLXFBConfig = c.glXChooseFBConfig(
                    parent.display,
                    DefaultScreen(parent.display),
                    &visual_attribs,
                    &fbcount,
                ) orelse return error.GlxFailure;
                defer _ = c.XFree(fbc);

                // Pick the FB config/visual with the most samples per pixel

                var best_fbc: c_int = -1;
                var best_num_samp: c_int = -1;

                var i: c_int = 0;
                while (i < fbcount) : (i += 1) {
                    const current_fbc = fbc[@intCast(usize, i)];
                    const vi: *c.XVisualInfo = c.glXGetVisualFromFBConfig(
                        parent.display,
                        current_fbc,
                    ) orelse continue;
                    defer _ = c.XFree(vi);

                    var samp_buf: c_int = 0;
                    var samples: c_int = 0;
                    _ = c.glXGetFBConfigAttrib(
                        parent.display,
                        current_fbc,
                        c.GLX_SAMPLE_BUFFERS,
                        &samp_buf,
                    );
                    _ = c.glXGetFBConfigAttrib(
                        parent.display,
                        current_fbc,
                        c.GLX_SAMPLES,
                        &samples,
                    );

                    if (best_fbc < 0 or samp_buf != 0 and samples > best_num_samp) {
                        best_fbc = i;
                        best_num_samp = samples;
                    }
                }

                var bestFbc = fbc[@intCast(usize, best_fbc)];

                // Get a visual
                const vi: *c.XVisualInfo = c.glXGetVisualFromFBConfig(
                    parent.display,
                    bestFbc,
                ) orelse return error.GlxFailure;
                defer _ = c.XFree(vi);

                const colormap: c.Colormap = c.XCreateColormap(
                    parent.display,
                    RootWindow(parent.display, vi.screen),
                    vi.visual,
                    c.AllocNone,
                );

                var swa = std.mem.zeroes(c.XSetWindowAttributes);
                swa.colormap = colormap;
                swa.event_mask = c.StructureNotifyMask;
                swa.background_pixmap = c.None;
                swa.border_pixel = 0;

                swa.event_mask |= if (options.track_damage == true) c.ExposureMask else 0;
                swa.event_mask |= if (options.track_mouse == true) c.ButtonPressMask | c.ButtonReleaseMask | c.PointerMotionMask else 0;
                swa.event_mask |= if (options.track_keyboard == true) c.KeyPressMask | c.KeyReleaseMask else 0;

                self.window = c.XCreateWindow(
                    parent.display,
                    RootWindow(parent.display, vi.screen),
                    0,
                    0,
                    self.width,
                    self.height,
                    0,
                    vi.depth,
                    c.InputOutput,
                    vi.visual,
                    c.CWBorderPixel | c.CWColormap | c.CWEventMask,
                    &swa,
                );
                if (self.window == 0)
                    return error.CouldNotCreateWindow;

                _ = c.XMapWindow(parent.display, self.window);
                _ = c.XStoreName(parent.display, self.window, "VERY SIMPLE APPLICATION");

                const version = options.backend.opengl;

                self.gl = WindowGLData{
                    .glx_context = parent.gl.glxCreateContextAttribsARB(
                        parent.display,
                        bestFbc,
                        null,
                        c.True,
                        &[_:0]c_int{
                            c.GLX_CONTEXT_MAJOR_VERSION_ARB, version.major,
                            c.GLX_CONTEXT_MINOR_VERSION_ARB, version.minor,
                            c.GLX_CONTEXT_FLAGS_ARB,         c.GLX_CONTEXT_DEBUG_BIT_ARB | c.GLX_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB,
                            c.GLX_CONTEXT_PROFILE_MASK_ARB,  if (version.core) c.GLX_CONTEXT_CORE_PROFILE_BIT_ARB else c.GLX_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
                            0,
                        },
                    ) orelse return error.InvalidOpenGL,
                };

                _ = c.glXMakeCurrent(
                    parent.display,
                    self.window,
                    self.gl.?.glx_context,
                );
            }

            pub fn deinit(self: *Window) void {
                var platform = @ptrCast(*Self, self.parent.platform);

                if (Parent.settings.backends_enabled.opengl) {
                    if (self.gl) |gl| {
                        c.glXDestroyContext(platform.display, gl.glx_context);
                    }
                }

                if (self.window != 0) {
                    _ = c.XDestroyWindow(platform.display, self.window);
                }

                platform.parent.allocator.destroy(self);
            }

            pub fn present(self: *Window) void {
                c.glXSwapBuffers(@ptrCast(*Self, self.parent.platform).display, self.window);
            }

            pub fn configure(self: *Window, options: zwl.WindowOptions) !void {
                // Do
            }

            pub fn getSize(self: *Window) [2]u16 {
                return [2]u16{ self.width, self.height };
            }

            pub fn mapPixels(self: *Window) !zwl.PixelBuffer {
                return error.Unimplemented;
            }

            pub fn submitPixels(self: *Window, pdates: []const zwl.UpdateArea) !void {
                return error.Unimplemented;
            }
        };

        inline fn RootWindow(dpy: *c.Display, screen: c_int) c.Window {
            const private_display = @ptrCast(c._XPrivDisplay, @alignCast(@alignOf(c._XPrivDisplay), dpy));
            return ScreenOfDisplay(
                private_display,
                @intCast(usize, screen),
            ).root;
        }

        inline fn DefaultRootWindow(dpy: *c.Display) c.Window {
            const private_display = @ptrCast(c._XPrivDisplay, @alignCast(@alignOf(c._XPrivDisplay), dpy));
            return ScreenOfDisplay(
                private_display,
                @intCast(usize, private_display.*.default_screen),
            ).root;
        }

        inline fn DefaultScreen(dpy: *c.Display) c_int {
            return @ptrCast(c._XPrivDisplay, @alignCast(@alignOf(c._XPrivDisplay), dpy)).*.default_screen;
        }

        inline fn ScreenOfDisplay(dpy: c._XPrivDisplay, scr: usize) *c.Screen {
            return @ptrCast(*c.Screen, &dpy.*.screens[scr]);
        }
    };
}
