const std = @import("std");
const builtin = @import("builtin");
const zwl = @import("zwl.zig");
usingnamespace @import("x11/types.zig");
const Allocator = std.mem.Allocator;

const DisplayInfo = @import("x11/display_info.zig").DisplayInfo;
const auth = @import("x11/auth.zig");

// A circular buffer for reply events that we expect
const ReplyCBuffer = struct {
    const ReplyHandler = enum {
        ExtensionQueryBigRequests,
        BigRequestsEnable,
        ExtensionQueryXKB,
        ExtensionQueryMitShm,
        MitShmEnable,
        ExtensionQueryPresent,
        PresentEnable,
        ExtensionQueryXFixes,
        XFixesEnable,
        AtomMotifWmHints,
    };

    const ReplyEvent = struct {
        seq: u32,
        handler: ReplyHandler,
    };

    mem: [32]ReplyEvent = undefined,
    tail: u8 = 0,
    head: u8 = 0,
    seq_next: u32 = 1,

    pub fn len(self: *ReplyCBuffer) usize {
        var hp: usize = self.head;
        if (self.head < self.tail)
            hp += self.mem.len;
        return hp - self.tail;
    }

    pub fn push(self: *ReplyCBuffer, handler: ReplyHandler) !void {
        if (self.len() == self.mem.len - 1) return error.OutOfMemory;
        self.mem[self.head] = .{ .handler = handler, .seq = self.seq_next };
        self.seq_next += 1;
        self.head = @intCast(u8, (self.head + 1) % self.mem.len);
    }

    pub fn ignoreEvent(self: *ReplyCBuffer) void {
        self.seq_next += 1;
    }

    pub fn get(self: *ReplyCBuffer, seq: u32) ?ReplyHandler {
        while (self.len() > 0) {
            const tailp = self.tail;
            const ev = self.mem[tailp];
            if (ev.seq < seq) {
                unreachable;
            } else if (ev.seq == seq) {
                self.tail = @intCast(u8, (self.tail + 1) % self.mem.len);
                return ev.handler;
            } else {
                return null;
            }
        }
        return null;
    }
};

pub fn Platform(comptime Parent: anytype) type {
    const file_is_always_unix = if (Parent.settings.remote == false and builtin.os.tag != .windows) true else false;

    return struct {
        const Self = @This();
        parent: Parent,
        file: std.fs.File,
        file_is_unix: if (file_is_always_unix) void else bool,
        replies: ReplyCBuffer = .{},

        rbuf: [1024]u8 align(8) = undefined,
        rbuf_n: usize = 0,

        xid_next: u32,
        root: WINDOW,
        root_depth: u8,
        root_color_bits: u8,

        max_req_len: u32 = 262140,

        // Atoms
        atom_motif_wm_hints: u32 = 0,

        // Extension info
        xfixes_major_opcode: u8 = 0,
        xfixes_first_event: u8 = 0,
        xkb_opcode_major: u8 = 0,
        xkb_first_event: u8 = 0,
        mitshm_major_opcode: u8 = 0,
        mitshm_first_event: u8 = 0,
        present_major_opcode: u8 = 0,
        present_first_event: u8 = 0,

        pub fn init(allocator: *Allocator, options: zwl.PlatformOptions) !*Parent {
            if (builtin.os.tag == .windows) {
                _ = try std.os.windows.WSAStartup(2, 2);
            }
            errdefer {
                if (builtin.os.tag == .windows) {
                    std.os.windows.WSACleanup() catch unreachable;
                }
            }

            var display_info_buf: [256]u8 = undefined;
            var display_info_allocator = std.heap.FixedBufferAllocator.init(display_info_buf[0..]);
            const display_info = try DisplayInfo.init(&display_info_allocator.allocator, options.x11.host, options.x11.display, options.x11.screen);

            const file = blk: {
                if (file_is_always_unix or display_info.unix) {
                    break :blk try displayConnectUnix(display_info);
                } else {
                    break :blk try displayConnectTCP(display_info);
                }
            };
            errdefer file.close();

            const auth_cookie: ?[16]u8 = if (options.x11.mit_magic_cookie != null) options.x11.mit_magic_cookie.? else try auth.getCookie(options.x11.xauthority_location);

            var rbuf = std.io.bufferedReader(file.reader());
            var wbuf = std.io.bufferedWriter(file.writer());
            var reader = rbuf.reader();
            var writer = wbuf.writer();

            try sendClientHandshake(auth_cookie, writer);
            try wbuf.flush();
            const server_handshake = try readServerHandshake(reader);
            if (display_info.screen >= server_handshake.roots_len) {
                std.log.scoped(.zwl).err("X11 screen {} does not exist, max is {}", .{ display_info.screen, server_handshake.roots_len });
                return error.InvalidScreen;
            }

            const screen_info = try readScreenInfo(server_handshake, display_info.screen, reader);
            var self = try allocator.create(Self);
            errdefer allocator.destroy(self);
            self.* = .{
                .parent = .{
                    .allocator = allocator,
                    .type = .X11,
                    .window = undefined,
                    .windows = if (!Parent.settings.single_window) &[0]*Parent.Window{} else undefined,
                },
                .file = file,
                .file_is_unix = if (file_is_always_unix) undefined else display_info.unix,
                .xid_next = server_handshake.resource_id_base,
                .root = screen_info.root,
                .root_depth = screen_info.root_depth,
                .root_color_bits = screen_info.root_color_bits,
            };

            // Init extensions
            try writer.writeAll(std.mem.asBytes(&QueryExtensionRequest{ .length_request = 4, .length_name = 6 }));
            try writer.writeAll("XFIXES");
            try writer.writeByteNTimes(0, xpad("XFIXES".len));
            try self.replies.push(.ExtensionQueryXFixes);

            try writer.writeAll(std.mem.asBytes(&QueryExtensionRequest{ .length_request = 5, .length_name = 12 }));
            try writer.writeAll("BIG-REQUESTS");
            try self.replies.push(.ExtensionQueryBigRequests);

            try writer.writeAll(std.mem.asBytes(&QueryExtensionRequest{ .length_request = 5, .length_name = 9 }));
            try writer.writeAll("XKEYBOARD");
            try writer.writeByteNTimes(0, xpad("XKEYBOARD".len));
            try self.replies.push(.ExtensionQueryXKB);

            try writer.writeAll(std.mem.asBytes(&QueryExtensionRequest{ .length_request = 4, .length_name = 7 }));
            try writer.writeAll("MIT-SHM");
            try writer.writeByteNTimes(0, xpad("MIT-SHM".len));
            try self.replies.push(.ExtensionQueryMitShm);

            try writer.writeAll(std.mem.asBytes(&QueryExtensionRequest{ .length_request = 4, .length_name = 7 }));
            try writer.writeAll("Present");
            try writer.writeByteNTimes(0, xpad("Present".len));
            try self.replies.push(.ExtensionQueryPresent);

            // Get atoms
            try writer.writeAll(std.mem.asBytes(&InternAtom{
                .if_exists = 0,
                .request_length = @intCast(u16, (8 + "_MOTIF_WM_HINTS".len + xpad("_MOTIF_WM_HINTS".len)) >> 2),
                .name_length = "_MOTIF_WM_HINTS".len,
            }));
            try writer.writeAll("_MOTIF_WM_HINTS");
            try writer.writeByteNTimes(0, xpad("_MOTIF_WM_HINTS".len));
            try self.replies.push(.AtomMotifWmHints);

            try wbuf.flush();
            try self.handleInitEvents();

            if (self.present_major_opcode == 0) return error.PresentExtensionNotPresent;

            std.log.scoped(.zwl).info("Platform Initialized: X11", .{});
            return @ptrCast(*Parent, self);
        }

        fn handleInitEvents(self: *Self) !void {
            var rbuf = std.io.bufferedReader(self.file.reader());
            var wbuf = std.io.bufferedWriter(self.file.writer());
            var reader = rbuf.reader();
            var writer = wbuf.writer();

            while (self.replies.len() > 0) {
                var evdata: [32]u8 align(8) = undefined;
                _ = try reader.readAll(evdata[0..]);

                const evtype = evdata[0] & 0x7F;
                const seq = std.mem.readIntNative(u16, evdata[2..4]);
                const extlen = std.mem.readIntNative(u32, evdata[4..8]) * 4;

                if (evtype == @enumToInt(XEventCode.Error)) {
                    unreachable; // We will never make mistakes during init
                } else if (evtype != @enumToInt(XEventCode.Reply)) {
                    continue; // The only possible events here are stuff we don't care about
                }

                const handler = self.replies.get(seq) orelse unreachable;
                switch (handler) {
                    .ExtensionQueryBigRequests => {
                        const qreply = @ptrCast(*const QueryExtensionReply, &evdata);
                        if (qreply.present != 0) {
                            try writer.writeAll(std.mem.asBytes(&BigReqEnable{ .opcode = qreply.major_opcode }));
                            try self.replies.push(.BigRequestsEnable);
                        }
                    },
                    .BigRequestsEnable => {
                        const qreply = @ptrCast(*const BigReqEnableReply, &evdata);
                        self.max_req_len = qreply.max_req_len;
                    },
                    .ExtensionQueryXKB => {
                        const qreply = @ptrCast(*const QueryExtensionReply, &evdata);
                        if (qreply.present != 0) {
                            self.xkb_first_event = qreply.major_opcode;
                            self.xkb_opcode_major = qreply.first_event;
                            // UseExtension
                        }
                    },
                    .ExtensionQueryMitShm => {
                        const qreply = @ptrCast(*const QueryExtensionReply, &evdata);
                        if (qreply.present != 0) {
                            self.mitshm_major_opcode = qreply.major_opcode;
                            self.mitshm_first_event = qreply.first_event;
                            try writer.writeAll(std.mem.asBytes(&MitShmQueryVersion{ .opcode = qreply.major_opcode }));
                            try self.replies.push(.MitShmEnable);
                        }
                    },
                    .MitShmEnable => {
                        // Just need version 1, so whatever
                    },
                    .ExtensionQueryPresent => {
                        const qreply = @ptrCast(*const QueryExtensionReply, &evdata);
                        if (qreply.present != 0) {
                            self.present_major_opcode = qreply.major_opcode;
                            self.present_first_event = qreply.first_event;
                            try writer.writeAll(std.mem.asBytes(&PresentQueryVersion{ .opcode = qreply.major_opcode, .version_major = 1, .version_minor = 0 }));
                            try self.replies.push(.PresentEnable);
                        }
                    },
                    .PresentEnable => {
                        // Just need version 1, so whatever
                    },
                    .ExtensionQueryXFixes => {
                        const qreply = @ptrCast(*const QueryExtensionReply, &evdata);
                        if (qreply.present != 0) {
                            self.xfixes_major_opcode = qreply.major_opcode;
                            self.xfixes_first_event = qreply.first_event;
                            try writer.writeAll(std.mem.asBytes(&XFixesQueryVersion{ .opcode = qreply.major_opcode, .version_major = 5, .version_minor = 0 }));
                            try self.replies.push(.XFixesEnable);
                        }
                    },
                    .XFixesEnable => {
                        // Don't need to verify the version. We depend on the Present extension that depends on this, so whatever.
                    },
                    .AtomMotifWmHints => {
                        const qreply = @ptrCast(*const InternAtomReply, &evdata);
                        self.atom_motif_wm_hints = qreply.atom;
                    },
                    // else => unreachable, // The other events cannot appear during init
                }
                if (rbuf.fifo.readableLength() == 0) {
                    try wbuf.flush();
                }
            }
        }

        pub fn deinit(self: *Self) void {
            if (builtin.os.tag == .windows) {
                std.os.windows.WSACleanup() catch unreachable;
            }
            self.parent.allocator.destroy(self);
        }

        fn genXId(self: *Self) u32 {
            const id = self.xid_next;
            self.xid_next += 1;
            return id;
        }

        pub fn waitForEvent(self: *Self) !Parent.Event {
            var p: usize = 0;
            defer {
                std.mem.copy(u8, self.rbuf[0 .. self.rbuf_n - p], self.rbuf[p..self.rbuf_n]);
                self.rbuf_n -= p;
            }

            const generic_event_size = 32;
            while (true) {
                // If we've skipped so many events that we have to adjust the rbuf prematurely...
                if (self.rbuf.len - p < generic_event_size) {
                    std.mem.copy(u8, self.rbuf[0 .. self.rbuf_n - p], self.rbuf[p..self.rbuf_n]);
                    self.rbuf_n -= p;
                    p = 0;
                }

                // Make sure we've got data for at least one event
                while (self.rbuf_n - p < generic_event_size) {
                    self.rbuf_n += try self.file.read(self.rbuf[self.rbuf_n..]);
                }

                const evdata = self.rbuf[p .. p + generic_event_size];
                const evtype = @intToEnum(XEventCode, evdata[0] & 0x7F);

                if (evtype == .GenericEvent) {
                    const gev = @ptrCast(*const GenericEvent, @alignCast(4, evdata.ptr));

                    // std.log.info("Size: {}", .{generic_event_size + gev.length * 4});
                    // std.time.sleep(1000000);

                    if (self.rbuf_n - p < generic_event_size + gev.length * 4)
                        continue;
                    defer p += generic_event_size + gev.length * 4;

                    if (gev.extension == self.present_major_opcode) {
                        if (gev.evtype == 1) {
                            const present_complete = @ptrCast(*const PresentCompleteNotify, @alignCast(8, evdata.ptr)); // if we ever have an extended event with an odd number of bytes, this alignment will explode
                            if (self.getWindowById(present_complete.window)) |window| {
                                return Parent.Event{ .WindowVBlank = @ptrCast(*Parent.Window, window) };
                            }
                        }
                    } else {
                        std.log.info("Unhandled generic event: {}.{}\n", .{ gev.extension, gev.evtype });
                    }
                } else {
                    defer p += generic_event_size;
                    switch (evtype) {
                        .Error => {
                            const ev = @ptrCast(*const XEventError, @alignCast(4, evdata.ptr));
                            std.log.err("{}: {}", .{ self.replies.seq_next, ev });
                            unreachable;
                        },
                        .Reply => {
                            // explicit reply for some request
                            const extlen = std.mem.readIntNative(u32, evdata[4..8]) * 4;
                            if (extlen > 0) unreachable; // Can't handle this yet
                        },
                        .ReparentNotify, .MapNotify, .UnmapNotify, .NoExposure => {
                            // Whatever
                        },
                        .Expose => {
                            const ev = @ptrCast(*const Expose, @alignCast(4, evdata.ptr));
                            if (self.getWindowById(ev.window)) |window| {
                                // TODO: Not greater than underlying buffer...?
                                return Parent.Event{
                                    .WindowDamaged = .{
                                        .window = @ptrCast(*Parent.Window, window),
                                        .x = ev.x,
                                        .y = ev.y,
                                        .w = ev.width,
                                        .h = ev.height,
                                    },
                                };
                            }
                        },
                        .ConfigureNotify => {
                            const ev = @ptrCast(*const ConfigureNotify, @alignCast(4, evdata.ptr));
                            if (self.getWindowById(ev.window)) |window| {
                                if (window.width != ev.width or window.height != ev.height) {
                                    window.width = ev.width;
                                    window.height = ev.height;
                                    return Parent.Event{ .WindowResized = @ptrCast(*Parent.Window, window) };
                                }
                            }
                        },
                        .DestroyNotify => {
                            const ev = @ptrCast(*const DestroyNotify, @alignCast(4, evdata.ptr));
                            if (self.getWindowById(ev.window)) |window| {
                                window.handle = 0;
                                return Parent.Event{ .WindowDestroyed = @ptrCast(*Parent.Window, window) };
                            }
                        },

                        .KeyPress,
                        .KeyRelease,
                        .ButtonPress,
                        .ButtonRelease,
                        .MotionNotify,
                        => {
                            const ev = @ptrCast(*const InputDeviceEvent, @alignCast(4, evdata.ptr));
                            if (self.getWindowById(ev.event)) |window| {
                                switch (evtype) {
                                    .KeyPress,
                                    .KeyRelease,
                                    => {
                                        var kev = zwl.KeyEvent{
                                            .scancode = ev.detail - 8,
                                        };

                                        return switch (evtype) {
                                            .KeyPress => Parent.Event{ .KeyDown = kev },
                                            .KeyRelease => Parent.Event{ .KeyUp = kev },
                                            else => unreachable,
                                        };
                                    },

                                    .ButtonPress,
                                    .ButtonRelease,
                                    => {
                                        var bev = zwl.MouseButtonEvent{
                                            .x = ev.event_x,
                                            .y = ev.event_y,
                                            .button = @intToEnum(zwl.MouseButton, ev.detail),
                                        };

                                        return switch (evtype) {
                                            .ButtonPress => Parent.Event{ .MouseButtonDown = bev },
                                            .ButtonRelease => Parent.Event{ .MouseButtonUp = bev },
                                            else => unreachable,
                                        };
                                    },

                                    .MotionNotify => return Parent.Event{
                                        .MouseMotion = zwl.MouseMotionEvent{
                                            .x = ev.event_x,
                                            .y = ev.event_y,
                                        },
                                    },

                                    else => unreachable,
                                }
                            }
                        },

                        else => {
                            std.log.info("Unhandled event: {}", .{evtype});
                        },
                    }
                }
            }
        }

        fn getWindowById(self: *Self, id: u32) ?*Window {
            if (Parent.settings.single_window) {
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

        pub fn createWindow(self: *Self, options: zwl.WindowOptions) !*Parent.Window {
            var window = try self.parent.allocator.create(Window);
            errdefer self.parent.allocator.destroy(window);

            var wbuf = std.io.bufferedWriter(self.file.writer());
            var writer = wbuf.writer();
            try window.init(self, options, writer);

            // todo: mode
            // todo: transparent

            if (options.resizeable == false) try window.disableResizeable(writer);
            if (options.title) |title| try window.setTitle(writer, title);
            if (options.decorations == false) try window.disableDecorations(writer);
            if (options.visible == true) try window.map(writer);
            try wbuf.flush();

            return @ptrCast(*Parent.Window, window);
        }

        const WindowSWData = struct {
            gc: GCONTEXT,
            pixmap: PIXMAP,
            region: REGION,
            present_event: EventID,
            data: []u32 = &[0]u32{},
            width: u16 = 0,
            height: u16 = 0,
        };

        pub const Window = struct {
            parent: Parent.Window,
            handle: WINDOW,
            mapped: bool,
            width: u16,
            height: u16,
            sw: if (Parent.settings.backends_enabled.software) ?WindowSWData else void,

            pub fn init(self: *Window, platform: *Self, options: zwl.WindowOptions, writer: anytype) !void {
                self.* = .{
                    .parent = .{
                        .platform = @ptrCast(*Parent, platform),
                    },
                    .width = options.width orelse 800,
                    .height = options.height orelse 600,
                    .handle = platform.genXId(),
                    .mapped = if (options.visible == true) true else false,
                    .sw = undefined,
                };

                var values_n: u16 = 0;
                var value_mask: u32 = 0;
                var values: [2]u32 = undefined;
                values[values_n] = EventStructureNotify;
                values[values_n] |= if (options.track_damage == true) @as(u32, EventExposure) else 0;
                values[values_n] |= if (options.track_mouse == true) @as(u32, EventButtonPress | EventButtonRelease | EventPointerMotion) else 0;
                values[values_n] |= if (options.track_keyboard == true) @as(u32, EventKeyPress | EventKeyRelease) else 0;

                values_n += 1;

                value_mask |= CWEventMask;

                const create_window = CreateWindow{
                    .id = self.handle,
                    .depth = 0,
                    .x = 0,
                    .y = 0,
                    .parent = platform.root,
                    .request_length = (@sizeOf(CreateWindow) >> 2) + values_n,
                    .width = self.width,
                    .height = self.height,
                    .visual = 0,
                    .mask = value_mask,
                };
                try writer.writeAll(std.mem.asBytes(&create_window));
                try writer.writeAll(std.mem.sliceAsBytes(values[0..values_n]));
                platform.replies.ignoreEvent();

                if (Parent.settings.backends_enabled.software) {
                    self.sw = .{
                        .gc = platform.genXId(),
                        .pixmap = 0,
                        .region = platform.genXId(),
                        .present_event = platform.genXId(),
                    };
                    const create_gc = CreateGC{
                        .request_length = 4,
                        .cid = self.sw.?.gc,
                        .drawable = .{ .window = self.handle },
                        .bitmask = 0,
                    };

                    const create_region = CreateRegion{
                        .opcode = platform.xfixes_major_opcode,
                        .length_request = 2,
                        .region = self.sw.?.region,
                    };
                    try writer.writeAll(std.mem.asBytes(&create_region));
                    platform.replies.ignoreEvent();

                    const select_input = PresentSelectInput{
                        .opcode = platform.present_major_opcode,
                        .event_id = self.sw.?.present_event,
                        .window = self.handle,
                        .mask = 2,
                    };
                    try writer.writeAll(std.mem.asBytes(&select_input));
                    platform.replies.ignoreEvent();

                    // TODO: SHM when it's in Zig stdlib...

                    // TODO: disable GraphicsExpose and NoExpose?
                    try writer.writeAll(std.mem.asBytes(&create_gc));
                    platform.replies.ignoreEvent();
                }
            }

            pub fn deinit(self: *Window) void {
                var platform = @ptrCast(*Self, self.parent.platform);

                var wbuf = std.io.bufferedWriter(platform.file.writer());
                var writer = wbuf.writer();

                if (Parent.settings.backends_enabled.software) {
                    writer.writeAll(std.mem.asBytes(&FreeGC{ .gc = self.sw.?.gc })) catch return;
                    platform.replies.ignoreEvent();
                    if (self.sw.?.pixmap != 0) {
                        writer.writeAll(std.mem.asBytes(&FreePixmap{ .pixmap = self.sw.?.pixmap })) catch return;
                        platform.replies.ignoreEvent();
                    }

                    const destroy_region = DestroyRegion{ .opcode = platform.xfixes_major_opcode, .region = self.sw.?.region };
                    writer.writeAll(std.mem.asBytes(&destroy_region)) catch return;
                    platform.replies.ignoreEvent();

                    const select_input = PresentSelectInput{
                        .opcode = platform.present_major_opcode,
                        .event_id = self.sw.?.present_event,
                        .window = self.handle,
                        .mask = 0,
                    };
                    writer.writeAll(std.mem.asBytes(&select_input)) catch return;
                    platform.replies.ignoreEvent();

                    platform.parent.allocator.free(self.sw.?.data);
                }

                if (self.handle != 0) {
                    const destroy_window = DestroyWindow{ .id = self.handle };
                    writer.writeAll(std.mem.asBytes(&destroy_window)) catch return;
                    platform.replies.ignoreEvent();
                }

                wbuf.flush() catch return;
                platform.parent.allocator.destroy(self);
            }

            pub fn configure(self: *Window, options: zwl.WindowOptions) !void {
                var platform = @ptrCast(*Self, self.parent.platform);
                var wbuf = std.io.bufferedWriter(platform.file.writer());
                var writer = wbuf.writer();

                const needs_remap = (options.resizeable != null);
                if (needs_remap and self.mapped == true) {
                    try self.unmap(writer);
                }

                // todo: width, height
                // todo: mode
                // todo: transparent

                if (options.resizeable == true) try self.enableResizeable(writer);
                if (options.resizeable == false) try self.disableResizeable(writer);
                if (options.decorations == true) try self.enableDecorations(writer);
                if (options.decorations == false) try self.disableDecorations(writer);
                if (options.title) |title| try self.setTitle(writer, title);

                if (options.visible == false) {
                    try self.unmap(writer);
                } else if (options.visible == true) {
                    try self.map(writer);
                } else if (needs_remap == true) {
                    try self.map(writer);
                }

                try wbuf.flush();
            }

            pub fn mapPixels(self: *Window) !zwl.PixelBuffer {
                var platform = @ptrCast(*Self, self.parent.platform);
                var wbuf = std.io.bufferedWriter(platform.file.writer());
                var writer = wbuf.writer();

                if (self.sw.?.pixmap == 0 or self.sw.?.width != self.width or self.sw.?.height != self.height) {
                    if (self.sw.?.pixmap != 0) {
                        try writer.writeAll(std.mem.asBytes(&FreePixmap{ .pixmap = self.sw.?.pixmap }));
                        platform.replies.ignoreEvent();
                    }
                    self.sw.?.pixmap = platform.genXId();
                    self.sw.?.width = self.width;
                    self.sw.?.height = self.height;

                    const create_pixmap = CreatePixmap{
                        .depth = platform.root_depth,
                        .pid = self.sw.?.pixmap,
                        .drawable = .{ .window = self.handle },
                        .width = self.sw.?.width,
                        .height = self.sw.?.height,
                    };
                    try writer.writeAll(std.mem.asBytes(&create_pixmap));
                    platform.replies.ignoreEvent();

                    // Todo: MIT-SHM

                    self.sw.?.data = try platform.parent.allocator.realloc(self.sw.?.data, @intCast(usize, self.sw.?.width) * @intCast(usize, self.sw.?.height));
                }
                try wbuf.flush();
                return zwl.PixelBuffer{ .data = self.sw.?.data.ptr, .width = self.sw.?.width, .height = self.sw.?.height };
            }

            pub fn submitPixels(self: *Window, updates: []const zwl.UpdateArea) !void {
                var platform = @ptrCast(*Self, self.parent.platform);
                var wbuf = std.io.bufferedWriter(platform.file.writer());
                var writer = wbuf.writer();

                // If no MIT-SHM, send pixels manually
                if (true) {
                    for (updates) |update| {
                        const pixels_n = @as(u32, update.w) * @as(u32, update.h);
                        const put_image = PutImageBig{
                            .request_length = 7 + pixels_n,
                            .drawable = .{ .pixmap = self.sw.?.pixmap },
                            .gc = self.sw.?.gc,
                            .width = update.w,
                            .height = update.h,
                            .dst = [2]u16{ update.x, update.y },
                            .left_pad = 0,
                            .depth = 24,
                        };
                        try writer.writeAll(std.mem.asBytes(&put_image));

                        if (update.w == self.sw.?.width) {
                            const offset = @as(u32, update.w) * @as(u32, update.y);
                            try writer.writeAll(std.mem.sliceAsBytes(self.sw.?.data[offset .. offset + pixels_n]));
                        } else {
                            var ri: u16 = 0;
                            while (ri < update.h) : (ri += 1) {
                                const row_pixels_n = @as(u32, update.w);
                                const row_pixels_offset = (@as(u32, self.sw.?.width) * @as(u32, update.y + ri)) + @as(u32, update.x);
                                try writer.writeAll(std.mem.sliceAsBytes(self.sw.?.data[row_pixels_offset .. row_pixels_offset + row_pixels_n]));
                            }
                        }
                        platform.replies.ignoreEvent();
                    }
                }

                // TODO: MIT-SHM

                // Set the change region
                const set_region = SetRegion{
                    .opcode = platform.xfixes_major_opcode,
                    .length_request = 2 + @intCast(u16, updates.len * 2),
                    .region = self.sw.?.region,
                };
                try writer.writeAll(std.mem.asBytes(&set_region));
                for (updates) |update| {
                    const rect = [4]u16{ update.x, update.y, update.w, update.h };
                    try writer.writeAll(std.mem.asBytes(&rect));
                }
                platform.replies.ignoreEvent();

                // Present!
                const present_pixmap = PresentPixmap{
                    .length = 18,
                    .opcode = platform.present_major_opcode,
                    .window = self.handle,
                    .pixmap = self.sw.?.pixmap,
                    .serial = 0,
                    .valid_area = self.sw.?.region,
                    .update_area = self.sw.?.region,
                    .crtc = 0,
                    .wait_fence = 0,
                    .idle_fence = 0,
                    .options = 0,
                    .target_msc = 0,
                    .divisor = 0,
                    .remainder = 0,
                };
                try writer.writeAll(std.mem.asBytes(&present_pixmap));
                const present_notify = PresentNotify{
                    .window = self.handle,
                    .serial = 0,
                };
                // Add this to segfault X11
                //try writer.writeAll(std.mem.asBytes(&present_notify));
                platform.replies.ignoreEvent();
                try wbuf.flush();
            }

            pub fn getSize(self: *Window) [2]u16 {
                return [2]u16{ self.width, self.height };
            }

            fn map(self: *Window, writer: anytype) !void {
                var platform = @ptrCast(*Self, self.parent.platform);
                try writer.writeAll(std.mem.asBytes(&MapWindow{ .id = self.handle }));
                platform.replies.ignoreEvent();
            }

            fn unmap(self: *Window, writer: anytype) !void {
                var platform = @ptrCast(*Self, self.parent.platform);
                try writer.writeAll(std.mem.asBytes(&UnmapWindow{ .id = self.handle }));
                platform.replies.ignoreEvent();
            }

            fn disableResizeable(self: *Window, writer: anytype) !void {
                var platform = @ptrCast(*Self, self.parent.platform);

                const size_hints_request = ChangeProperty{
                    .window = self.handle,
                    .request_length = @intCast(u16, (@sizeOf(ChangeProperty) + @sizeOf(SizeHints)) >> 2),
                    .property = @enumToInt(BuiltinAtom.WM_NORMAL_HINTS),
                    .property_type = @enumToInt(BuiltinAtom.WM_SIZE_HINTS),
                    .format = 32,
                    .length = @sizeOf(SizeHints) >> 2,
                };
                try writer.writeAll(std.mem.asBytes(&size_hints_request));

                const size_hints: SizeHints = .{
                    .flags = (1 << 4) + (1 << 5) + (1 << 8),
                    .min = [2]u32{ self.width, self.height },
                    .max = [2]u32{ self.width, self.height },
                    .base = [2]u32{ self.width, self.height },
                };
                try writer.writeAll(std.mem.asBytes(&size_hints));
                platform.replies.ignoreEvent();
            }

            fn enableResizeable(self: *Window, writer: anytype) !void {
                var platform = @ptrCast(*Self, self.parent.platform);
                const size_hints_request = DeleteProperty{
                    .window = self.handle,
                    .property = @enumToInt(BuiltinAtom.WM_NORMAL_HINTS),
                };
                try writer.writeAll(std.mem.asBytes(&size_hints_request));
                platform.replies.ignoreEvent();
            }

            fn setTitle(self: *Window, writer: anytype, title: []const u8) !void {
                var platform = @ptrCast(*Self, self.parent.platform);
                const title_request = ChangeProperty{
                    .window = self.handle,
                    .request_length = @intCast(u16, (@sizeOf(ChangeProperty) + title.len + xpad(title.len)) >> 2),
                    .property = @enumToInt(BuiltinAtom.WM_NAME),
                    .property_type = @enumToInt(BuiltinAtom.STRING),
                    .format = 8,
                    .length = @intCast(u32, title.len),
                };
                try writer.writeAll(std.mem.asBytes(&title_request));
                try writer.writeAll(title);
                try writer.writeByteNTimes(0, xpad(title.len));
                platform.replies.ignoreEvent();
            }

            fn disableDecorations(self: *Window, writer: anytype) !void {
                var platform = @ptrCast(*Self, self.parent.platform);
                const hints = MotifHints{ .flags = 2, .functions = 0, .decorations = 0, .input_mode = 0, .status = 0 };
                const hints_request = ChangeProperty{
                    .window = self.handle,
                    .request_length = @intCast(u16, (@sizeOf(ChangeProperty) + @sizeOf(MotifHints)) >> 2),
                    .property = platform.atom_motif_wm_hints,
                    .property_type = platform.atom_motif_wm_hints,
                    .format = 32,
                    .length = @intCast(u32, @sizeOf(MotifHints) >> 2),
                };
                try writer.writeAll(std.mem.asBytes(&hints_request));
                try writer.writeAll(std.mem.asBytes(&hints));
                platform.replies.ignoreEvent();
            }

            fn enableDecorations(self: *Window, writer: anytype) !void {
                var platform = @ptrCast(*Self, self.parent.platform);
                const size_hints_request = DeleteProperty{
                    .window = self.handle,
                    .property = platform.atom_motif_wm_hints,
                };
                try writer.writeAll(std.mem.asBytes(&size_hints_request));
                platform.replies.ignoreEvent();
            }
        };
    };
}

fn xpad(n: usize) usize {
    return @bitCast(usize, (-%@bitCast(isize, n)) & 3);
}

fn displayConnectUnix(display_info: DisplayInfo) !std.fs.File {
    const opt_non_block = if (std.io.is_async) os.SOCK_NONBLOCK else 0;
    var socket = try std.os.socket(std.os.AF_UNIX, std.os.SOCK_STREAM | std.os.SOCK_CLOEXEC | opt_non_block, 0);
    errdefer std.os.close(socket);
    var addr = std.os.sockaddr_un{ .path = [_]u8{0} ** 108 };
    std.mem.copy(u8, addr.path[0..], "\x00/tmp/.X11-unix/X");
    _ = std.fmt.formatIntBuf(addr.path["\x00/tmp/.X11-unix/X".len..], display_info.display, 10, false, .{});
    const addrlen = 1 + std.mem.lenZ(@ptrCast([*:0]u8, addr.path[1..]));
    try std.os.connect(socket, @ptrCast(*const std.os.sockaddr, &addr), @sizeOf(std.os.sockaddr_un) - @intCast(u32, addr.path.len - addrlen));
    return std.fs.File{ .handle = socket };
}

fn displayConnectTCP(display_info: DisplayInfo) !std.fs.File {
    const hostname = if (std.mem.eql(u8, display_info.host, "")) "127.0.0.1" else display_info.host;
    var tmpmem: [4096]u8 = undefined;
    var tmpalloc = std.heap.FixedBufferAllocator.init(tmpmem[0..]);
    const file = try std.net.tcpConnectToHost(&tmpalloc.allocator, hostname, 6000 + @intCast(u16, display_info.display));
    errdefer file.close();
    // Set TCP_NODELAY?
    return file;
}

fn sendClientHandshake(auth_cookie: ?[16]u8, writer: anytype) !void {
    if (auth_cookie) |cookie| {
        const req: extern struct {
            setup: SetupRequest,
            mit_magic_cookie_str: [20]u8,
            mit_magic_cookie_value: [16]u8,
        } = .{
            .setup = .{
                .auth_proto_name_len = "MIT-MAGIC-COOKIE-1".len,
                .auth_proto_data_len = 16,
            },
            .mit_magic_cookie_str = "MIT-MAGIC-COOKIE-1\x00\x00".*,
            .mit_magic_cookie_value = cookie,
        };
        _ = try writer.writeAll(std.mem.asBytes(&req));
    } else {
        _ = try writer.writeAll(std.mem.asBytes(&SetupRequest{}));
    }
}

const ServerHandshake = struct {
    resource_id_base: u32,
    pixmap_formats_len: u32,
    roots_len: u32,
};

fn readServerHandshake(reader: anytype) !ServerHandshake {
    const response_header = try reader.readStruct(SetupResponseHeader);
    switch (response_header.status) {
        0 => {
            var reason_buf: [256]u8 = undefined;
            _ = try reader.readAll(reason_buf[0..response_header.reason_length]);
            var reason = reason_buf[0..response_header.reason_length];
            if (reason.len > 0 and reason[reason.len - 1] == '\n')
                reason = reason[0 .. reason.len - 1];
            std.log.scoped(.zwl).err("X11 handshake failed: {}", .{reason});
            return error.HandshakeFailed;
        },
        1 => {
            var server_handshake: ServerHandshake = undefined;
            const response = try reader.readStruct(SetupAccepted);
            server_handshake.resource_id_base = response.resource_id_base;
            server_handshake.pixmap_formats_len = response.pixmap_formats_len;
            server_handshake.roots_len = response.roots_len;
            try reader.skipBytes(response.vendor_len + xpad(response.vendor_len), .{ .buf_size = 32 });
            return server_handshake;
        },
        else => return error.Protocol,
    }
}

const ScreenInfo = struct {
    root: u32,
    root_depth: u8,
    root_color_bits: u8,
};

fn readScreenInfo(server_handshake: ServerHandshake, screen_id: usize, reader: anytype) !ScreenInfo {
    var screen_info: ScreenInfo = undefined;

    var pfi: usize = 0;
    while (pfi < server_handshake.pixmap_formats_len) : (pfi += 1) {
        const format = try reader.readStruct(PixmapFormat);
    }

    var sci: usize = 0;
    while (sci < server_handshake.roots_len) : (sci += 1) {
        const screen = try reader.readStruct(Screen);
        if (sci == screen_id) {
            screen_info.root = screen.root;
        }

        var dpi: usize = 0;
        while (dpi < screen.allowed_depths_len) : (dpi += 1) {
            const depth = try reader.readStruct(Depth);
            var vii: usize = 0;
            while (vii < depth.visual_count) : (vii += 1) {
                const visual = try reader.readStruct(Visual);
                if (sci == screen_id and screen.root_visual_id == visual.id) {
                    screen_info.root_depth = depth.depth;
                    screen_info.root_color_bits = visual.bits_per_rgb;
                }
            }
        }
    }
    return screen_info;
}
