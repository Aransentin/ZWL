const std = @import("std");
const builtin = @import("builtin");
const zwl = @import("../zwl.zig");
usingnamespace @import("proto.zig");
const Allocator = std.mem.Allocator;

const ReplyBuffer = @import("replybuffer.zig").ReplyBuffer;
const DisplayInfo = @import("display_info.zig").DisplayInfo;
const Connection = @import("connection.zig").Connection;
const AuthCookie = @import("auth.zig").AuthCookie;
const setup = @import("setup.zig");

pub fn Platform(comptime PPlatform: anytype) type {
    return struct {
        const Self = @This();
        pub const connection_is_always_unix = if (PPlatform.settings.remote == false and builtin.os.tag != .windows) true else false;
        pub const Window = @import("window.zig").Window(PPlatform);

        parent: PPlatform,
        connection: Connection,
        replybuf: ReplyBuffer = .{},

        rbuf: std.io.BufferedReader(4096, @TypeOf(std.fs.File.reader(undefined))) = undefined,
        wbuf: std.io.BufferedWriter(4096, @TypeOf(std.fs.File.writer(undefined))) = undefined,

        xid_next: u32 = undefined,
        root: WINDOW = undefined,
        root_depth: u8 = undefined,
        root_color_bits: u8 = undefined,
        alpha_compat_visual: u32 = undefined,

        ext_op_xfixes: u8 = 0,
        ext_op_mitshm: u8 = 0,
        ext_op_randr: u8 = 0,
        ext_op_present: u8 = 0,
        ext_ev_present: u8 = 0,

        atom_motif_wm_hints: u32 = 0,

        pub fn init(allocator: *Allocator, options: zwl.PlatformOptions) !*PPlatform {

            // Before allocating platform data, prepare the information needed and connect,
            // so as to not pointlessly allocate for a platform that's not going to work.
            const display_info = try DisplayInfo.parse(options.x11.host, options.x11.display, options.x11.screen);
            const auth_cookie = AuthCookie.parse(display_info, options, connection_is_always_unix) catch null;
            var connection = try Connection.init(display_info, connection_is_always_unix);
            errdefer connection.deinit();

            var self = try allocator.create(Self);
            errdefer allocator.destroy(self);
            self.* = Self{
                .parent = .{
                    .allocator = allocator,
                    .type = .X11,
                    .window = if (!PPlatform.settings.single_window) undefined else null,
                    .windows = if (PPlatform.settings.single_window) undefined else &[0]*PPlatform.Window{},
                },
                .connection = connection,
            };
            self.rbuf = std.io.bufferedReader(self.connection.file.reader());
            self.wbuf = std.io.bufferedWriter(self.connection.file.writer());

            // The setup does the handshake and initializes all the extensions and atoms we need
            try setup.do(self, display_info, auth_cookie);

            std.log.scoped(.zwl).info("Platform Initialized: X11", .{});
            return @ptrCast(*PPlatform, self);
        }

        pub fn deinit(self: *Self) void {
            self.wbuf.flush() catch {};
            self.connection.deinit();
            self.parent.allocator.destroy(self);
        }

        pub fn createWindow(self: *Self, options: zwl.WindowOptions) !*PPlatform.Window {
            var window = try self.parent.allocator.create(Window);
            errdefer self.parent.allocator.destroy(window);
            window.parent.platform = @ptrCast(*PPlatform, self);
            try window.init(options);
            return @ptrCast(*PPlatform.Window, window);
        }

        fn getWindowById(self: *Self, id: u32) ?*Window {
            if (PPlatform.settings.single_window) {
                const win = @ptrCast(*Window, self.parent.window);
                if (id == win.handle) return win;
            } else {
                for (self.parent.windows) |pwin| {
                    const win = @ptrCast(*Window, pwin);
                    if (win.handle == id) return win;
                }
            }
            return null;
        }

        pub fn genXId(self: *Self) u32 {
            const id = self.xid_next;
            self.xid_next += 1;
            return id;
        }

        pub fn waitForEvent(self: *Self) !PPlatform.Event {
            try self.wbuf.flush();
            var reader = self.rbuf.reader();
            var writer = self.wbuf.writer();

            while (true) {
                var eventdata: [32]u8 align(8) = undefined;
                _ = try reader.readAll(&eventdata);
                const event_type = @intToEnum(XEvent, eventdata[0] & 0x7F);
                switch (event_type) {
                    .Error => {
                        // Somebody set us up the bomb
                        const ev = @ptrCast(*const ErrorEvent, &eventdata);
                        std.log.scoped(.zwl).debug("X11 error: {}", .{ev});
                        unreachable;
                    },
                    .Reply => {
                        // None yet
                    },
                    .ConfigureNotify => {
                        const ev = @ptrCast(*const ConfigureNotify, &eventdata);
                        if (self.getWindowById(ev.window)) |window| {
                            if (window.width != ev.width or window.height != ev.height) {
                                window.width = ev.width;
                                window.height = ev.height;
                                return PPlatform.Event{ .WindowResized = @ptrCast(*PPlatform.Window, window) };
                            }
                        }
                    },
                    .Expose => {
                        const ev = @ptrCast(*const ExposeEvent, &eventdata);
                        if (self.getWindowById(ev.window)) |window| {
                            return PPlatform.Event{
                                .WindowDamaged = .{
                                    .window = @ptrCast(*PPlatform.Window, window),
                                    .x = ev.x,
                                    .y = ev.y,
                                    .w = ev.width,
                                    .h = ev.height,
                                },
                            };
                        }
                    },
                    .DestroyNotify => {
                        const ev = @ptrCast(*const DestroyNotify, &eventdata);
                        if (self.getWindowById(ev.window)) |window| {
                            window.handle = 0;
                            return PPlatform.Event{ .WindowDestroyed = @ptrCast(*PPlatform.Window, window) };
                        }
                    },
                    .GenericEvent => {
                        const gev = @ptrCast(*const GenericEvent, &eventdata);
                        const extralen = gev.length * 4;
                        var extrabuf: [32]u8 align(8) = undefined;
                        if (extralen > extrabuf.len) unreachable;
                        _ = try reader.readAll(extrabuf[0..extralen]);
                        if (gev.extension == self.ext_op_present) {
                            if (gev.evtype == 1) {
                                var present_complete: PresentCompleteNotify = undefined;
                                std.mem.copy(u8, std.mem.asBytes(&present_complete), eventdata[0..]);
                                std.mem.copy(u8, std.mem.asBytes(&present_complete)[32..], extrabuf[0..extralen]);

                                if (self.getWindowById(present_complete.window)) |window| {
                                    if (window.frame_id == present_complete.serial) {
                                        window.frame_id += 1;
                                        return PPlatform.Event{ .WindowVBlank = @ptrCast(*PPlatform.Window, window) };
                                    }
                                }
                            }
                        }
                    },
                    .ReparentNotify, .MapNotify, .UnmapNotify => {}, // Who cares
                    else => {
                        std.log.scoped(.zwl).debug("Unhandled X11 event: {}", .{event_type});
                    },
                }
            }
        }
    };
}
