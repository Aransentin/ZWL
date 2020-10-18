const std = @import("std");
const builtin = @import("builtin");
const zwl = @import("zwl.zig");
const Allocator = std.mem.Allocator;
usingnamespace @import("x11/types.zig");
const DisplayInfo = @import("x11/display_info.zig").DisplayInfo;
const auth = @import("x11/auth.zig");

fn xpad(n: usize) usize {
    return @bitCast(usize, (-%@bitCast(isize, n)) & 3);
}

const XEventType = enum {
    ExtensionQueryBigRequests,
    BigRequestsEnable,
};

const XEvent = struct {
    evtype: XEventType,
    seq: u16,
};

const XEventCBuffer = struct {
    mem: [32]XEvent = undefined,
    tail: u8 = 0,
    head: u8 = 0,
    seq_next: u16 = 1,

    pub fn len(self: *XEventCBuffer) usize {
        var hp: usize = self.head;
        if (self.head < self.tail)
            hp += self.mem.len;
        return hp - self.tail;
    }

    pub fn push(self: *XEventCBuffer, evtype: XEventType) !void {
        if (self.len() == self.mem.len - 1) return error.OutOfMemory;
        self.mem[self.head] = .{ .evtype = evtype, .seq = self.seq_next };
        self.seq_next += 1;
        self.head = @intCast(u8, (self.head + 1) % self.mem.len);
    }

    pub fn get(self: *XEventCBuffer, seq: u16) ?XEventType {
        while (self.len() > 0) {
            const tailp = self.tail;
            const ev = self.mem[tailp];
            if (ev.seq < seq) {
                unreachable;
            } else if (ev.seq == seq) {
                self.tail = @intCast(u8, (self.tail + 1) % self.mem.len);
                return ev.evtype;
            } else {
                return null;
            }
        }
        return null;
    }
};

pub fn Platform(comptime Parent: anytype) type {
    return struct {
        const Self = @This();
        allocator: *Allocator,
        file: std.fs.File,

        root: WINDOW = undefined,
        root_depth: u8 = undefined,
        root_color_bits: u8 = undefined,
        xid_next: u32,

        max_req_len: u32 = 262140,

        evbuf: XEventCBuffer = .{},

        windows: if (Parent.settings.single_window) void else []*Window,
        single_window: if (!Parent.settings.single_window) void else Window = undefined,

        callback: fn (event: Parent.Event) void,

        pub fn init(allocator: *Allocator, callback: fn (event: Parent.Event) void, options: zwl.PlatformOptions) !Parent {
            var display_info_buf: [256]u8 = undefined;
            var display_info_allocator = std.heap.FixedBufferAllocator.init(display_info_buf[0..]);
            const display_info = try DisplayInfo.init(allocator, options.x11.host, options.x11.display, options.x11.screen);

            if (builtin.os.tag == .windows) {
                _ = try std.os.windows.WSAStartup(2, 2);
            }

            const file = blk: {
                if (display_info.unix) {
                    const opt_non_block = if (std.io.is_async) os.SOCK_NONBLOCK else 0;
                    var socket = try std.os.socket(std.os.AF_UNIX, std.os.SOCK_STREAM | std.os.SOCK_CLOEXEC | opt_non_block, 0);
                    errdefer std.os.close(socket);
                    var addr = std.os.sockaddr_un{ .path = [_]u8{0} ** 108 };
                    const path = try std.fmt.bufPrint(addr.path[0..], "\x00/tmp/.X11-unix/X{}", .{display_info.display});
                    try std.os.connect(socket, @ptrCast(*const std.os.sockaddr, &addr), @sizeOf(std.os.sockaddr_un) - @intCast(u32, addr.path.len - path.len));
                    break :blk std.fs.File{ .handle = socket };
                } else {
                    const hostname = if (std.mem.eql(u8, display_info.host, "")) "127.0.0.1" else display_info.host;
                    var tmpmem: [4096]u8 = undefined;
                    var tmpalloc = std.heap.FixedBufferAllocator.init(tmpmem[0..]);
                    const file = try std.net.tcpConnectToHost(&tmpalloc.allocator, hostname, 6000 + @intCast(u16, display_info.display));
                    // Set TCP_NODELAY?
                    break :blk file;
                }
            };
            errdefer file.close();

            const auth_cookie: ?[16]u8 = if (options.x11.mit_magic_cookie != null) options.x11.mit_magic_cookie.? else try auth.getCookie(options.x11.xauthority_location);
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
                _ = try file.writeAll(std.mem.asBytes(&req));
            } else {
                _ = try file.writeAll(std.mem.asBytes(&SetupRequest{}));
            }

            var rbuf = std.io.bufferedReader(file.reader());
            var reader = rbuf.reader();

            var setup_length: u32 = undefined;
            var resource_id_base: u32 = undefined;
            var pixmap_formats_len: u32 = undefined;
            var roots_len: u32 = undefined;

            const response_header = try reader.readStruct(SetupResponseHeader);
            switch (response_header.status) {
                0 => {
                    var reason_buf: [256]u8 = undefined;
                    _ = try reader.readAll(reason_buf[0..response_header.reason_length]);
                    var reason = reason_buf[0..response_header.reason_length];
                    if (reason.len > 0 and reason[reason.len - 1] == '\n')
                        reason = reason[0 .. reason.len - 1];
                    std.log.scoped(.zwl).err("X11 Connection failed: {}", .{reason});
                    return error.AuthenticationFailed;
                },
                1 => {
                    const response = try reader.readStruct(SetupAccepted);
                    setup_length = @intCast(u32, response_header.length) << 2;
                    resource_id_base = response.resource_id_base;
                    pixmap_formats_len = response.pixmap_formats_len;
                    roots_len = response.roots_len;
                    try reader.skipBytes(response.vendor_len + xpad(response.vendor_len), .{ .buf_size = 32 });
                },
                else => return error.Protocol,
            }

            if (display_info.screen >= roots_len) return error.InvalidScreen;
            var self = try allocator.create(Self);
            errdefer allocator.destroy(self);
            self.* = Self{
                .allocator = allocator,
                .file = file,
                .callback = callback,
                .windows = if (Parent.settings.single_window) undefined else &[0]*Window{},
                .xid_next = resource_id_base,
            };

            var pfi: usize = 0;
            while (pfi < pixmap_formats_len) : (pfi += 1) {
                const format = try reader.readStruct(PixmapFormat);
            }

            var sci: usize = 0;
            while (sci < roots_len) : (sci += 1) {
                const screen_info = try reader.readStruct(Screen);
                if (sci == display_info.screen) {
                    self.root = screen_info.root;
                }

                var dpi: usize = 0;
                while (dpi < screen_info.allowed_depths_len) : (dpi += 1) {
                    const depth = try reader.readStruct(Depth);
                    var vii: usize = 0;
                    while (vii < depth.visual_count) : (vii += 1) {
                        const visual = try reader.readStruct(Visual);
                        if (screen_info.root_visual_id == visual.id) {
                            self.root_depth = depth.depth;
                            self.root_color_bits = visual.bits_per_rgb;
                        }
                    }
                }
            }

            // Init extensions
            var wbuf = std.io.bufferedWriter(self.file.writer());
            var writer = wbuf.writer();
            try writer.writeAll(std.mem.asBytes(&QueryExtensionRequest{ .length_request = 5, .length_name = 12 }));
            try writer.writeAll("BIG-REQUESTS");
            try self.evbuf.push(.ExtensionQueryBigRequests);

            try wbuf.flush();
            try self.flushEvents();

            return Parent{ .X11 = self };
        }
        pub fn deinit(self: *Self) void {
            self.file.close();

            if (!Parent.settings.single_window) {
                self.allocator.free(self.windows);
            }
            self.allocator.destroy(self);
        }

        fn genXId(self: *Self) u32 {
            const id = self.xid_next;
            self.xid_next += 1;
            return id;
        }

        fn flushEvents(self: *Self) !void {
            while (true) {
                if (self.evbuf.len() == 0)
                    return;
                try self.waitForEvents();
            }
        }

        pub fn waitForEvents(self: *Self) !void {
            var rbuf = std.io.bufferedReader(self.file.reader());
            var wbuf = std.io.bufferedWriter(self.file.writer());
            var reader = rbuf.reader();
            var writer = wbuf.writer();

            while (true) {
                var evdata: [32]u8 align(8) = undefined;
                _ = try reader.readAll(evdata[0..]);

                const evtype = evdata[0] & 0x7F;

                switch (evtype) {
                    @enumToInt(XEventCode.Error) => {
                        std.log.err("TODO: Handle X11 errors", .{});
                    },
                    @enumToInt(XEventCode.Reply) => {
                        const seq = std.mem.readIntNative(u16, evdata[2..4]);
                        const extlen = std.mem.readIntNative(u32, evdata[4..8]) * 4;

                        if (self.evbuf.get(seq)) |rt| switch (rt) {
                            .ExtensionQueryBigRequests => try self.cbExtensionQueryBigRequests(&evdata, writer),
                            .BigRequestsEnable => try self.cbBigRequestsEnable(&evdata, writer),
                        } else {
                            try reader.skipBytes(extlen, .{ .buf_size = 32 });
                        }
                    },
                    @enumToInt(XEventCode.ReparentNotify), @enumToInt(XEventCode.MapNotify) => {
                        // Whatever for now
                    },
                    @enumToInt(XEventCode.ConfigureNotify) => {
                        const ev = @ptrCast(*ConfigureNotify, &evdata);
                        if (self.getWindowById(ev.window)) |window| {
                            if (window.width != ev.width or window.height != ev.height) {
                                window.width = ev.width;
                                window.height = ev.height;
                                const pwindow = Parent.Window{ .X11 = window };
                                const pev = Parent.Event{ .WindowResized = pwindow };
                                self.callback(pev);
                            }
                        }
                    },
                    @enumToInt(XEventCode.Expose) => {
                        const ev = @ptrCast(*Expose, &evdata);
                        if (self.getWindowById(ev.window)) |window| {
                            const pwindow = Parent.Window{ .X11 = window };
                            const pev = Parent.Event{
                                .WindowDamaged = .{
                                    .window = pwindow,
                                    .x = ev.x,
                                    .y = ev.y,
                                    .w = ev.width,
                                    .h = ev.height,
                                },
                            };
                            self.callback(pev);
                        }
                    },
                    @enumToInt(XEventCode.DestroyNotify) => {
                        const ev = @ptrCast(*DestroyNotify, &evdata);
                        if (self.getWindowById(ev.window)) |window| {
                            window.id = 0;
                            const pwindow = Parent.Window{ .X11 = window };
                            const pev = Parent.Event{ .WindowDestroyed = pwindow };
                            self.callback(pev);
                        }
                    },
                    else => {},
                }

                if (rbuf.fifo.readableLength() == 0)
                    break;
            }

            try wbuf.flush();
        }

        fn cbExtensionQueryBigRequests(self: *Self, data: *align(8) [32]u8, writer: anytype) !void {
            const reply = @ptrCast(*const QueryExtensionReply, data);
            if (reply.present == 0)
                return;

            const req = BigReqEnable{ .opcode = reply.major_opcode };
            try writer.writeAll(std.mem.asBytes(&req));
            try self.evbuf.push(.BigRequestsEnable);
        }

        fn cbBigRequestsEnable(self: *Self, data: *align(8) [32]u8, writer: anytype) !void {
            const reply = @ptrCast(*const BigReqEnableReply, data);
            self.max_req_len = reply.max_req_len;
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
                .id = self.genXId(),
                .gc = if (Parent.settings.render_software) self.genXId() else undefined,
                .width = options.width,
                .height = options.height,
            };

            if (!Parent.settings.single_window) {
                self.windows = try self.allocator.realloc(self.windows, self.windows.len + 1);
                self.windows[self.windows.len - 1] = win;
            }
            errdefer if (!Parent.settings.single_window) {
                self.windows = self.allocator.realloc(self.windows, self.windows.len - 1) catch unreachable;
            };

            var wbuf = std.io.bufferedWriter(self.file.writer());
            var writer = wbuf.writer();

            var values_n: u16 = 0;
            var value_mask: u32 = 0;
            var values: [4]u32 = undefined;
            if (options.backing_store) {
                values[values_n] = 1;
                values_n += 1;
                value_mask |= CWBackingStores;
            }

            values[values_n] = EventStructureNotify;
            values[values_n] |= if (options.track_damage) @as(u32, EventExposure) else 0;
            values_n += 1;
            value_mask |= CWEventMask;

            const create_window = CreateWindow{
                .id = win.id,
                .depth = 0, // todo: if not auto depth, fix
                .x = 0,
                .y = 0,
                .parent = self.root,
                .request_length = (@sizeOf(CreateWindow) >> 2) + values_n,
                .width = options.width,
                .height = options.height,
                .visual = 0, // todo: if not auto depth, fix
                .mask = value_mask,
            };
            try writer.writeAll(std.mem.asBytes(&create_window));
            const event_mask: u32 = EventStructureNotify | if (options.track_damage) EventExposure else 0;
            try writer.writeAll(std.mem.sliceAsBytes(values[0..values_n]));

            if (options.resizeable == false) {
                const size_hints_request = ChangeProperty{
                    .window = win.id,
                    .request_length = @intCast(u16, (@sizeOf(ChangeProperty) + @sizeOf(SizeHints)) >> 2),
                    .property = @enumToInt(BuiltinAtom.WM_NORMAL_HINTS),
                    .property_type = @enumToInt(BuiltinAtom.WM_SIZE_HINTS),
                    .format = 32,
                    .length = @sizeOf(SizeHints) >> 2,
                };
                try writer.writeAll(std.mem.asBytes(&size_hints_request));

                const size_hints: SizeHints = .{
                    .flags = (1 << 4) + (1 << 5) + (1 << 8),
                    .min = [2]u32{ options.width, options.height },
                    .max = [2]u32{ options.width, options.height },
                    .base = [2]u32{ options.width, options.height },
                };
                try writer.writeAll(std.mem.asBytes(&size_hints));
            }

            if (options.title) |title| {
                const title_request = ChangeProperty{
                    .window = win.id,
                    .request_length = @intCast(u16, (@sizeOf(ChangeProperty) + title.len + xpad(title.len)) >> 2),
                    .property = @enumToInt(BuiltinAtom.WM_NAME),
                    .property_type = @enumToInt(BuiltinAtom.STRING),
                    .format = 8,
                    .length = @intCast(u32, title.len),
                };
                try writer.writeAll(std.mem.asBytes(&title_request));
                try writer.writeAll(title);
                try writer.writeByteNTimes(0, xpad(title.len));
            }

            if (Parent.settings.render_software) {
                const create_gc = CreateGC{
                    .request_length = 4,
                    .cid = win.gc,
                    .drawable = .{ .window = win.id },
                    .bitmask = 0,
                };
                try writer.writeAll(std.mem.asBytes(&create_gc));
            }
            try wbuf.flush();

            return Parent.Window{ .X11 = win };
        }

        pub const Window = struct {
            platform: *Self,
            id: u32,
            width: u16,
            height: u16,

            gc: if (Parent.settings.render_software) GCONTEXT else void,
            pixeldata: []u32 = &[0]u32{},
            pixeldata_width: u16 = 0,
            pixeldata_height: u16 = 0,

            pub fn destroy(self: *Window) void {
                var wbuf = std.io.bufferedWriter(self.platform.file.writer());
                var writer = wbuf.writer();

                if (Parent.settings.render_software) {
                    const free_gc = FreeGC{
                        .gc = self.gc,
                    };
                    writer.writeAll(std.mem.asBytes(&free_gc)) catch {};
                }

                if (self.id != 0) {
                    const destroy_window = DestroyWindow{ .id = self.id };
                    writer.writeAll(std.mem.asBytes(&destroy_window)) catch {};
                }

                wbuf.flush() catch {};

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

            pub fn show(self: *Window) !void {
                if (self.id == 0) unreachable;
                const map_window = MapWindow{ .id = self.id };
                try self.platform.file.writer().writeAll(std.mem.asBytes(&map_window));
            }

            pub fn hide(self: *Window) !void {
                if (self.id == 0) unreachable;
                const unmap_window = UnmapWindow{ .id = self.id };
                try self.platform.file.writer().writeAll(std.mem.asBytes(&unmap_window));
            }

            pub fn getPixelBuffer(self: *Window) !Parent.PixelBuffer {

                // Case 1: PutPixels
                if (self.pixeldata_width != self.width or self.pixeldata_height != self.height) {
                    self.pixeldata_width = self.width;
                    self.pixeldata_height = self.height;
                    self.pixeldata = try self.platform.allocator.realloc(self.pixeldata, @intCast(usize, self.pixeldata_width) * @intCast(usize, self.pixeldata_height));
                }

                // TODO: MIT-SHM

                return Parent.PixelBuffer{ .data = self.pixeldata.ptr, .width = self.pixeldata_width, .height = self.pixeldata_height };
            }

            pub fn commitPixelBuffer(self: *Window) !void {
                // Case 1: PutPixels
                var wbuf = std.io.bufferedWriter(self.platform.file.writer());
                var writer = wbuf.writer();
                const put_image = PutImageBig{
                    .request_length = 7 + (@intCast(u32, (self.pixeldata.len << 2) + xpad(self.pixeldata.len)) >> 2),
                    .drawable = self.id,
                    .gc = self.gc,
                    .width = self.pixeldata_width,
                    .height = self.pixeldata_height,
                    .dst = [2]u16{ 0, 0 },
                    .left_pad = 0,
                    .depth = 24,
                };
                try writer.writeAll(std.mem.asBytes(&put_image));
                try writer.writeAll(std.mem.sliceAsBytes(self.pixeldata));
                try writer.writeByteNTimes(0, xpad(self.pixeldata.len));
                try wbuf.flush();
            }
        };
    };
}
