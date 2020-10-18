const std = @import("std");
const builtin = @import("builtin");
const zwl = @import("zwl.zig");
const Allocator = std.mem.Allocator;
const c = @import("xcb/c.zig");
const DisplayInfo = @import("x11/display_info.zig").DisplayInfo;

pub fn Platform(comptime Parent: anytype) type {
    return struct {
        const Self = @This();
        allocator: *Allocator,

        xlib_display: if (Parent.settings.x11_use_xcb_through_xlib) *c.Display else void = undefined,
        connection: *c.xcb_connection_t,

        root: c.xcb_window_t = undefined,
        root_depth: u8 = undefined,
        root_visual: u32 = undefined,
        // root_color_bits: u8 = undefined,
        motif_wm_hints: u32 = undefined,

        windows: if (Parent.settings.single_window) void else []*Window,
        single_window: if (!Parent.settings.single_window) void else Window = undefined,

        pub fn init(allocator: *Allocator, options: zwl.PlatformOptions) !Parent {
            var display_info_buf: [256]u8 = undefined;
            var display_info_allocator = std.heap.FixedBufferAllocator.init(display_info_buf[0..]);
            const display_info = try DisplayInfo.init(allocator, options.x11.host, options.x11.display, options.x11.screen);

            const self = blk: {
                if (Parent.settings.x11_use_xcb_through_xlib) {
                    try c.initXlib();
                    errdefer c.deinitXlib();
                    var dbuf: [256]u8 = undefined;
                    const DISPLAY = try std.fmt.bufPrintZ(dbuf[0..], "{}:{}.{}", .{ display_info.host, display_info.display, display_info.screen });
                    const display = c.XOpenDisplay(DISPLAY) orelse return error.XOpenDisplayFailed;
                    errdefer _ = c.XCloseDisplay(display);

                    const connection = c.XGetXCBConnection(display);
                    try c.xcbConnectionHasError(connection);

                    var self = try allocator.create(Self);
                    errdefer allocator.destroy(self);
                    self.* = Self{
                        .allocator = allocator,
                        .xlib_display = display,
                        .connection = connection,
                        .windows = if (Parent.settings.single_window) undefined else &[0]*Window{},
                    };
                    break :blk self;
                } else {
                    try c.initXCB();
                    errdefer c.deinitXCB();
                    var dbuf: [256]u8 = undefined;
                    const DISPLAY = try std.fmt.bufPrintZ(dbuf[0..], "{}:{}.{}", .{ display_info.host, display_info.display, display_info.screen });
                    const connection = c.xcb_connect(DISPLAY, null);
                    errdefer c.xcb_disconnect(connection);
                    try c.xcbConnectionHasError(connection);

                    var self = try allocator.create(Self);
                    errdefer allocator.destroy(self);
                    self.* = Self{
                        .allocator = allocator,
                        .connection = connection,
                        .windows = if (Parent.settings.single_window) undefined else &[0]*Window{},
                    };
                    break :blk self;
                }
            };
            errdefer self.deinit();

            // Get the correct screen
            const setup = c.xcb_get_setup(self.connection);
            var iter = c.xcb_setup_roots_iterator(setup);
            const screens_n = iter.rem;
            if (display_info.screen >= screens_n) return error.InvalidScreen;
            var scri: usize = 0;
            while (scri < display_info.screen) : (scri += 1) {
                c.xcb_screen_next(&iter);
            }
            const screen = iter.data;

            self.root = screen.root;
            self.root_depth = screen.root_depth;
            self.root_visual = screen.root_visual;

            // TODO: Get the compat 8-bit format

            // Grab atoms
            const motif_wm_hints_cookie = c.xcb_intern_atom(self.connection, 0, "_MOTIF_WM_HINTS".len, "_MOTIF_WM_HINTS");
            const motif_wm_hints_reply = c.xcb_intern_atom_reply(self.connection, motif_wm_hints_cookie, null);
            self.motif_wm_hints = motif_wm_hints_reply.atom;
            std.c.free(motif_wm_hints_reply);

            return Parent{ .X11 = self };
        }

        pub fn deinit(self: *Self) void {
            if (!Parent.settings.single_window) {
                self.allocator.free(self.windows);
            }

            if (Parent.settings.x11_use_xcb_through_xlib) {
                _ = c.XCloseDisplay(self.xlib_display);
                c.deinitXlib();
            } else {
                c.xcb_disconnect(self.connection);
                c.deinitXCB();
            }
            self.allocator.destroy(self);
        }

        pub fn waitForEvent(self: *Self) !Parent.Event {
            while (true) {
                const g_event = c.xcb_wait_for_event(self.connection) orelse return error.ConnectionClosed;
                defer std.c.free(g_event);
                const evtype = g_event.response_type & ~@as(u8, 0x80);

                switch (evtype) {
                    c.XCB_EXPOSE => {
                        const event = @ptrCast(*c.xcb_expose_event_t, g_event);
                        if (self.getWindowById(event.window)) |window| {
                            const pwindow = Parent.Window{ .X11 = window };
                            return Parent.Event{
                                .WindowDamaged = .{
                                    .window = pwindow,
                                    .x = event.x,
                                    .y = event.y,
                                    .w = event.width,
                                    .h = event.height,
                                },
                            };
                        }
                    },
                    c.XCB_DESTROY_NOTIFY => {
                        const event = @ptrCast(*c.xcb_destroy_notify_event_t, g_event);
                        if (self.getWindowById(event.window)) |window| {
                            const pwindow = Parent.Window{ .X11 = window };
                            return Parent.Event{ .WindowDestroyed = pwindow };
                        }
                    },
                    c.XCB_UNMAP_NOTIFY => {},
                    c.XCB_MAP_NOTIFY => {},
                    c.XCB_REPARENT_NOTIFY => {},
                    c.XCB_CONFIGURE_NOTIFY => {
                        const event = @ptrCast(*c.xcb_configure_notify_event_t, g_event);
                        if (self.getWindowById(event.window)) |window| {
                            if (window.width != event.width or window.height != event.height) {
                                window.width = event.width;
                                window.height = event.height;
                                const pwindow = Parent.Window{ .X11 = window };
                                return Parent.Event{ .WindowResized = pwindow };
                            }
                        }
                    },
                    else => {
                        std.log.debug("{}", .{evtype});
                    },
                }
            }
        }

        pub fn freeEvent(self: *Self, event: Parent.Event) void {
            // Noop, for now
        }

        pub fn createWindow(self: *Self, options: zwl.WindowOptions) !Parent.Window {
            var win: *Window = blk: {
                if (Parent.settings.single_window) {
                    break :blk &self.single_window;
                } else {
                    break :blk try self.allocator.create(Window);
                }
            };
            errdefer if (!Parent.settings.single_window) {
                self.allocator.destroy(win);
            };

            win.* = .{
                .platform = self,
                .id = c.xcb_generate_id(self.connection),
                .width = options.width orelse 640,
                .height = options.height orelse 480,
                .sw = undefined,
            };

            if (!Parent.settings.single_window) {
                self.windows = try self.allocator.realloc(self.windows, self.windows.len + 1);
                self.windows[self.windows.len - 1] = win;
            }
            errdefer if (!Parent.settings.single_window) {
                self.windows = self.allocator.realloc(self.windows, self.windows.len - 1) catch unreachable;
            };

            var values_n: u32 = 0;
            var value_mask: u32 = 0;
            var values: [4]u32 = undefined;
            if (options.backing_store == true) {
                values[values_n] = 1;
                values_n += 1;
                value_mask |= c.XCB_CW_BACKING_STORE;
            }

            values[values_n] = c.XCB_EVENT_MASK_STRUCTURE_NOTIFY;
            values[values_n] |= if (options.track_damage == true) @as(u32, c.XCB_EVENT_MASK_EXPOSURE) else 0;
            values_n += 1;
            value_mask |= c.XCB_CW_EVENT_MASK;

            _ = c.xcb_create_window(self.connection, c.XCB_COPY_FROM_PARENT, win.id, self.root, 0, 0, win.width, win.height, 0, c.XCB_WINDOW_CLASS_INPUT_OUTPUT, self.root_visual, value_mask, &values);

            if (options.resizeable == false) {
                const size_hints = c.xcb_size_hints_t{
                    .flags = (1 << 4) + (1 << 5) + (1 << 8),
                    .min = [2]i32{ win.width, win.height },
                    .max = [2]i32{ win.width, win.height },
                    .base = [2]i32{ win.width, win.height },
                };
                _ = c.xcb_change_property(self.connection, c.XCB_PROP_MODE_REPLACE, win.id, c.WM_NORMAL_HINTS, c.WM_SIZE_HINTS, 32, @sizeOf(c.xcb_size_hints_t) >> 2, &size_hints);
            }

            if (options.title) |title| {
                _ = c.xcb_change_property(self.connection, c.XCB_PROP_MODE_REPLACE, win.id, c.WM_NAME, c.WM_SIZE_HINTS, 8, @intCast(u32, title.len), title.ptr);
            }

            if (options.decorations == false) {
                var hints = c.MotifHints{ .flags = 2, .functions = 0, .decorations = 0, .input_mode = 0, .status = 0 };
                _ = c.xcb_change_property(self.connection, c.XCB_PROP_MODE_REPLACE, win.id, self.motif_wm_hints, self.motif_wm_hints, 32, @intCast(u32, @sizeOf(c.MotifHints) >> 2), &hints);
            }

            if (Parent.settings.render_software) {
                win.sw = .{
                    .gc = c.xcb_generate_id(self.connection),
                };
                _ = c.xcb_create_gc(self.connection, win.sw.gc, win.id, 0, null);
            }

            if (options.visible == true) {
                _ = c.xcb_map_window(self.connection, win.id);
            }

            try c.xcbFlush(self.connection);
            return Parent.Window{ .X11 = win };
        }

        fn getWindowById(self: *Self, id: u32) ?*Window {
            if (Parent.settings.single_window) {
                if (id == self.single_window.id) {
                    return &self.single_window;
                }
            } else {
                for (self.windows) |win| {
                    if (win.id == id) return win;
                }
            }
            return null;
        }

        pub const Window = struct {
            platform: *Self,
            id: u32,
            width: u16,
            height: u16,

            sw: if (Parent.settings.render_software)
                struct {
                    gc: c.xcb_gcontext_t,
                    data: []u32 = &[0]u32{},
                    width: u16 = 0,
                    height: u16 = 0,
                }
            else
                void,

            pub fn destroy(self: *Window) void {
                if (Parent.settings.render_software) {
                    _ = c.xcb_free_gc(self.platform.connection, self.sw.gc);
                    self.platform.allocator.free(self.sw.data);
                    // TODO: free MIT-SHM
                }

                if (self.id != 0) {
                    _ = c.xcb_destroy_window(self.platform.connection, self.id);
                    c.xcbFlush(self.platform.connection) catch {};
                }

                if (!Parent.settings.single_window) {
                    for (self.platform.windows) |*w, i| {
                        if (w.* == self) {
                            w.* = self.platform.windows[self.platform.windows.len - 1];
                        }
                    }
                    self.platform.windows = self.platform.allocator.realloc(self.platform.windows, self.platform.windows.len - 1) catch unreachable;
                    self.platform.allocator.destroy(self);
                } else {
                    self.id = 0;
                }
            }

            pub fn getPixelBuffer(self: *Window) !Parent.PixelBuffer {

                // Case 1: PutPixels
                if (self.sw.width != self.width or self.sw.height != self.height) {
                    self.sw.width = self.width;
                    self.sw.height = self.height;
                    self.sw.data = try self.platform.allocator.realloc(self.sw.data, @intCast(usize, self.sw.width) * @intCast(usize, self.sw.height));
                }

                // TODO: MIT-SHM

                return Parent.PixelBuffer{ .data = self.sw.data.ptr, .width = self.sw.width, .height = self.sw.height };
            }

            pub fn commitPixelBuffer(self: *Window) !void {
                // TODO: MIT-SHM
                _ = c.xcb_put_image(self.platform.connection, c.XCB_IMAGE_FORMAT_Z_PIXMAP, self.id, self.sw.gc, self.sw.width, self.sw.height, 0, 0, 0, 24, @intCast(u32, self.sw.data.len * @sizeOf(u32)), @ptrCast([*]const u8, self.sw.data.ptr));
            }
        };
    };
}
