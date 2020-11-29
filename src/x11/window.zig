const std = @import("std");
const builtin = @import("builtin");
const zwl = @import("../zwl.zig");
usingnamespace @import("proto.zig");
const util = @import("util.zig");

pub fn Window(comptime PPlatform: anytype) type {
    return struct {
        const Self = @This();
        parent: PPlatform.Window,
        handle: WINDOW,
        colormap: COLORMAP,
        gc: GCONTEXT,
        region: REGION,
        pixmap: PIXMAP,
        shm_segment: ShmSeg,
        shm_fd: i32,
        shm_fd_data: []align(4096) u8,
        pixmap_data: []align(16) u32,
        pixmap_format: zwl.BufferFormat,
        pixmap_width: u16,
        pixmap_height: u16,
        width: u16,
        height: u16,
        present_event: EventID,
        frame_id: u32 = 0,

        pub fn init(self: *Self, options: zwl.WindowOptions) !void {
            var platform = @ptrCast(*PPlatform.PlatformX11, self.parent.platform);
            var writer = platform.wbuf.writer();

            self.handle = platform.genXId();
            self.gc = platform.genXId();
            self.region = platform.genXId();
            self.present_event = platform.genXId();
            self.colormap = 0;
            self.pixmap = 0;
            self.shm_segment = 0;
            self.shm_fd = 0;
            self.shm_fd_data = &[0]u8{};
            self.pixmap_width = 0;
            self.frame_id = 0;
            self.pixmap_height = 0;
            self.pixmap_format = if (platform.root_color_bits == 10) zwl.BufferFormat.BGR10 else zwl.BufferFormat.BGR8;
            self.pixmap_data = &[0]u32{};
            self.width = options.width;
            self.height = options.height;

            // A colormap is needed to make non-native VISUALs for e.g. transparency or non-HDR windows
            const use_compat_visual = (PPlatform.settings.hdr == false or options.transparent == true);
            if (use_compat_visual) {
                self.pixmap_format = .BGRA8;
                self.colormap = platform.genXId();
                const create_colormap = CreateColormap{
                    .mid = self.colormap,
                    .window = platform.root,
                    .visual = platform.alpha_compat_visual,
                };
                try writer.writeAll(std.mem.asBytes(&create_colormap));
                platform.replybuf.ignoreEvent();
            }

            // Create the window itself
            var values_n: u16 = 0;
            var value_mask: u32 = 0;
            var values: [8]u32 = undefined;
            values[values_n] = 0;
            value_mask |= CwBackgroundPixel;
            values_n += 1;

            values[values_n] = 0;
            value_mask |= CwBorderPixel;
            values_n += 1;

            values[values_n] = EventStructureNotify;
            values[values_n] |= if (options.track_damage == true) @as(u32, EventExposure) else 0;
            value_mask |= CwEventMask;
            values_n += 1;

            values[values_n] = self.colormap;
            value_mask |= CwColormap;
            values_n += 1;

            const create_window = CreateWindow{
                .id = self.handle,
                .depth = if (use_compat_visual) 32 else 0,
                .x = 0,
                .y = 0,
                .parent = platform.root,
                .request_length = (@sizeOf(CreateWindow) >> 2) + values_n,
                .width = self.width,
                .height = self.height,
                .visual = if (use_compat_visual) platform.alpha_compat_visual else 0,
                .mask = value_mask,
            };
            try writer.writeAll(std.mem.asBytes(&create_window));
            try writer.writeAll(std.mem.sliceAsBytes(values[0..values_n]));
            platform.replybuf.ignoreEvent();

            // Create GC
            const create_gc = CreateGC{
                .request_length = 4,
                .cid = self.gc,
                .drawable = .{ .window = self.handle },
                .bitmask = 0,
            };
            try writer.writeAll(std.mem.asBytes(&create_gc));
            platform.replybuf.ignoreEvent();

            const create_region = CreateRegion{
                .opcode = platform.ext_op_xfixes,
                .request_length = 2,
                .region = self.region,
            };
            try writer.writeAll(std.mem.asBytes(&create_region));
            platform.replybuf.ignoreEvent();

            if (options.track_vblank) {
                const select_input = PresentSelectInput{
                    .opcode = platform.ext_op_present,
                    .event_id = self.present_event,
                    .window = self.handle,
                    .mask = 4,
                };
                try writer.writeAll(std.mem.asBytes(&select_input));
                platform.replybuf.ignoreEvent();
            }

            if (options.track_keyboard or options.track_mouse) {
                const select_events = XISelectEvents{
                    .opcode = platform.ext_op_xinput,
                    .request_length = 5,
                    .window = self.handle,
                    .num_masks = 1,
                    .pad0 = 0,
                };
                try writer.writeAll(std.mem.asBytes(&select_events));
                try writer.writeAll(std.mem.asBytes(&XIEventMask{ .device_id = 0x01, .mask_len = 1 }));
                var evmask: u32 = 0;
                if (options.track_keyboard) {
                    evmask += 1 << @enumToInt(XinputEventType.KeyPress);
                    evmask += 1 << @enumToInt(XinputEventType.KeyRelease);
                }
                if (options.track_mouse) {
                    // Do
                }
                try writer.writeAll(std.mem.asBytes(&evmask));
                platform.replybuf.ignoreEvent();
            }

            // We do not allocate a pixmap just yet, do that when the pixel buffer is requested instead.
            // Some WMs (e.g. tiled ones) will instantly resize the window you
            // just created, forcing us to recreate the backing buffer anyway.

            if (options.title) |title| try self.setTitle(title);
            // mode
            if (options.decorations == false) try self.setDecorations(false);
            if (options.resizeable == false) try self.setResizeable(false);
            if (options.visible == true) try self.setVisibility(true);
        }

        pub fn deinit(self: *Self) void {
            var platform = @ptrCast(*PPlatform.PlatformX11, self.parent.platform);
            var writer = platform.wbuf.writer();

            if (self.pixmap != 0) {
                writer.writeAll(std.mem.asBytes(&FreePixmap{ .pixmap = self.pixmap })) catch return;
                platform.replybuf.ignoreEvent();
            }

            if (self.shm_fd != 0) {
                if (builtin.os.tag == .windows) unreachable;
                std.os.munmap(self.shm_fd_data);
                std.os.close(self.shm_fd);
            }

            const destroy_region = DestroyRegion{
                .opcode = platform.ext_op_xfixes,
                .region = self.region,
            };
            writer.writeAll(std.mem.asBytes(&destroy_region)) catch return;
            platform.replybuf.ignoreEvent();

            const free_gc = FreeGC{ .gc = self.gc };
            writer.writeAll(std.mem.asBytes(&free_gc)) catch return;
            platform.replybuf.ignoreEvent();

            // Check if the handle exists - it could have been destroyed by an event
            if (self.handle != 0) {
                const destroy_window = DestroyWindow{ .window = self.handle };
                writer.writeAll(std.mem.asBytes(&destroy_window)) catch return;
                platform.replybuf.ignoreEvent();
            }

            if (self.colormap != 0) {
                const free_colormap = FreeColormap{ .cmap = self.colormap };
                writer.writeAll(std.mem.asBytes(&free_colormap)) catch return;
                platform.replybuf.ignoreEvent();
            }

            platform.parent.allocator.free(self.pixmap_data);
            platform.parent.allocator.destroy(self);
        }

        pub fn getSize(self: *Self) [2]u16 {
            return [2]u16{ self.width, self.height };
        }

        pub fn setTitle(self: *Self, title: ?[]const u8) !void {
            var platform = @ptrCast(*PPlatform.PlatformX11, self.parent.platform);
            var writer = platform.wbuf.writer();

            if (title) |t| {
                const change_property = ChangeProperty{
                    .window = self.handle,
                    .request_length = @intCast(u16, (@sizeOf(ChangeProperty) + t.len + util.xpad(t.len)) >> 2),
                    .property = @enumToInt(BuiltinAtom.WM_NAME),
                    .property_type = @enumToInt(BuiltinAtom.STRING),
                    .format = 8,
                    .length = @intCast(u32, t.len),
                };
                try writer.writeAll(std.mem.asBytes(&change_property));
                try writer.writeAll(t);
                try writer.writeByteNTimes(0, util.xpad(t.len));
                platform.replybuf.ignoreEvent();
            } else {
                const delete_property = DeleteProperty{
                    .window = self.handle,
                    .property = @enumToInt(BuiltinAtom.WM_NAME),
                };
                try writer.writeAll(std.mem.asBytes(&delete_property));
                platform.replybuf.ignoreEvent();
            }
        }

        pub fn setVisibility(self: *Self, state: bool) !void {
            var platform = @ptrCast(*PPlatform.PlatformX11, self.parent.platform);
            var writer = platform.wbuf.writer();

            if (state == true) {
                try writer.writeAll(std.mem.asBytes(&MapWindow{ .window = self.handle }));
                platform.replybuf.ignoreEvent();
            } else {
                try writer.writeAll(std.mem.asBytes(&UnmapWindow{ .window = self.handle }));
                platform.replybuf.ignoreEvent();
            }
        }

        pub fn setResizeable(self: *Self, state: bool) !void {
            var platform = @ptrCast(*PPlatform.PlatformX11, self.parent.platform);
            var writer = platform.wbuf.writer();

            if (state == false) {
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
                platform.replybuf.ignoreEvent();
            } else {
                const size_hints_request = DeleteProperty{
                    .window = self.handle,
                    .property = @enumToInt(BuiltinAtom.WM_NORMAL_HINTS),
                };
                try writer.writeAll(std.mem.asBytes(&size_hints_request));
                platform.replybuf.ignoreEvent();
            }
        }

        pub fn setDecorations(self: *Self, state: bool) !void {
            var platform = @ptrCast(*PPlatform.PlatformX11, self.parent.platform);
            var writer = platform.wbuf.writer();

            if (state == false) {
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
                platform.replybuf.ignoreEvent();
            } else {
                const size_hints_request = DeleteProperty{
                    .window = self.handle,
                    .property = platform.atom_motif_wm_hints,
                };
                try writer.writeAll(std.mem.asBytes(&size_hints_request));
                platform.replybuf.ignoreEvent();
            }
        }

        pub fn setConfiguration(self: *Self, x: i16, y: i16, width: u16, height: u16) !void {
            var platform = @ptrCast(*PPlatform.PlatformX11, self.parent.platform);
            var writer = platform.wbuf.writer();

            self.width = width;
            self.height = height;
            const configure_window = ConfigureWindow{
                .request_length = 3 + 4,
                .window = self.handle,
                .mask = 15,
            };
            try writer.writeAll(std.mem.asBytes(&configure_window));
            const values = [4]i32{ x, y, width, height };
            try writer.writeAll(std.mem.asBytes(&values));
            platform.replybuf.ignoreEvent();
        }

        pub fn setVblankTracking(self: *Self, state: bool) !void {
            var platform = @ptrCast(*PPlatform.PlatformX11, self.parent.platform);
            var writer = platform.wbuf.writer();
            if (state == true) {
                const select_input = PresentSelectInput{
                    .opcode = platform.ext_op_present,
                    .event_id = self.present_event,
                    .window = self.handle,
                    .mask = 2,
                };
                try writer.writeAll(std.mem.asBytes(&select_input));
                platform.replybuf.ignoreEvent();
            } else {
                const select_input = PresentSelectInput{
                    .opcode = platform.ext_op_present,
                    .event_id = self.present_event,
                    .window = self.handle,
                    .mask = 0,
                };
                try writer.writeAll(std.mem.asBytes(&select_input));
                platform.replybuf.ignoreEvent();
            }
        }

        pub fn setMode(self: *Self, mode: zwl.WindowMode) !void {
            // TODO
        }

        pub fn mapPixels(self: *Self) !zwl.PixelBuffer {
            var platform = @ptrCast(*PPlatform.PlatformX11, self.parent.platform);
            var writer = platform.wbuf.writer();

            if (self.pixmap == 0 or self.pixmap_width != self.width or self.pixmap_height != self.height) {
                if (self.pixmap != 0) {
                    try writer.writeAll(std.mem.asBytes(&FreePixmap{ .pixmap = self.pixmap }));
                    platform.replybuf.ignoreEvent();
                }

                self.pixmap = platform.genXId();
                self.pixmap_width = self.width;
                self.pixmap_height = self.height;

                const depth: u8 = switch (self.pixmap_format) {
                    .BGR8 => 24,
                    .BGRA8 => 32,
                    .BGR10 => 30,
                };

                if (platform.connection.is_unix) {
                    if (builtin.os.tag == .windows) unreachable;
                    self.shm_segment = platform.genXId();

                    // Have to pre-flush the request buffer as we are sending a file descriptor though
                    try platform.wbuf.flush();

                    // Generate a SHM fd if needed, then resize it to the proper dimension
                    if (self.shm_fd == 0) {
                        self.shm_fd = try std.os.memfd_create("ZWL", std.os.MFD_CLOEXEC);
                    }
                    const shm_size: u32 = @sizeOf(u32) * @intCast(u32, self.pixmap_width) * @intCast(u32, self.pixmap_height);
                    try std.os.ftruncate(self.shm_fd, shm_size);

                    // If we've never mapped it, do so. Else remap.
                    if (self.shm_fd_data.len == 0) {
                        self.shm_fd_data = try std.os.mmap(null, shm_size, std.os.PROT_WRITE, std.os.MAP_SHARED, self.shm_fd, 0);
                    } else {
                        // TODO: Use mremap when that's available in the stdlib
                        std.os.munmap(self.shm_fd_data);
                        self.shm_fd_data = try std.os.mmap(null, shm_size, std.os.PROT_WRITE, std.os.MAP_SHARED, self.shm_fd, 0);
                    }

                    // Yeet the fd over the socket. Should be replaced by stdlib types when available.
                    var cmsg: extern struct {
                        len: usize = 12 + @sizeOf(usize),
                        level: i32 = std.os.SOL_SOCKET,
                        type: i32 = 1, // SCM_RIGHTS
                        fd: isize,
                    } = .{
                        .fd = self.shm_fd,
                    };
                    var shm_attach_fd = ShmAttachFd{
                        .opcode = platform.ext_op_mitshm,
                        .shmseg = self.shm_segment,
                        .readOnly = 0,
                    };
                    var iov = std.os.iovec_const{
                        .iov_base = std.mem.asBytes(&shm_attach_fd),
                        .iov_len = @sizeOf(ShmAttachFd),
                    };
                    var msg = std.os.linux.msghdr_const{
                        .msg_name = null,
                        .msg_namelen = 0,
                        .msg_iov = @ptrCast([*]std.os.iovec_const, &iov),
                        .msg_iovlen = 1,
                        .msg_controllen = @sizeOf(@TypeOf(cmsg)),
                        .msg_control = &cmsg,
                        .__pad1 = 0,
                        .__pad2 = 0,
                        .msg_flags = 0,
                    };
                    _ = std.os.linux.sendmsg(platform.connection.file.handle, &msg, 0);
                    platform.replybuf.ignoreEvent();

                    const create_pixmap = ShmCreatePixmap{
                        .opcode = platform.ext_op_mitshm,
                        .pixmap = self.pixmap,
                        .drawable = .{ .window = self.handle },
                        .width = self.pixmap_width,
                        .height = self.pixmap_height,
                        .depth = depth,
                        .shm_segment = self.shm_segment,
                        .offset = 0,
                    };
                    try writer.writeAll(std.mem.asBytes(&create_pixmap));
                    platform.replybuf.ignoreEvent();
                } else {
                    const create_pixmap = CreatePixmap{
                        .depth = depth,
                        .pid = self.pixmap,
                        .drawable = .{ .window = self.handle },
                        .width = self.pixmap_width,
                        .height = self.pixmap_height,
                    };
                    try writer.writeAll(std.mem.asBytes(&create_pixmap));
                    platform.replybuf.ignoreEvent();
                    self.pixmap_data = try platform.parent.allocator.realloc(self.pixmap_data, @intCast(usize, self.pixmap_width) * @intCast(usize, self.pixmap_height));
                }
            }

            return zwl.PixelBuffer{
                .data = if (platform.connection.is_unix) @ptrCast([*]align(16) u32, self.shm_fd_data.ptr) else self.pixmap_data.ptr,
                .format = self.pixmap_format,
                .width = self.pixmap_width,
                .height = self.pixmap_height,
            };
        }

        pub fn submitPixels(self: *Self, updates: []const zwl.UpdateArea) !void {
            var platform = @ptrCast(*PPlatform.PlatformX11, self.parent.platform);
            var writer = platform.wbuf.writer();

            if (platform.connection.is_unix) {
                // MIT-SHM, so do nothing :)
            } else {
                // The old-fashioned shitty network way...
                for (updates) |update| {
                    const pixels_n = @as(u32, update.w) * @as(u32, update.h);
                    const depth: u8 = switch (self.pixmap_format) {
                        .BGR8 => 24,
                        .BGRA8 => 32,
                        .BGR10 => 30,
                    };
                    const put_image = PutImageBig{
                        .request_length = 7 + pixels_n,
                        .drawable = .{ .pixmap = self.pixmap },
                        .gc = self.gc,
                        .width = update.w,
                        .height = update.h,
                        .dst_x = @intCast(i16, update.x),
                        .dst_y = @intCast(i16, update.y),
                        .left_pad = 0,
                        .depth = depth,
                    };
                    try writer.writeAll(std.mem.asBytes(&put_image));

                    if (update.w == self.width) {
                        const offset = @as(u32, update.w) * @as(u32, update.y);
                        try writer.writeAll(std.mem.sliceAsBytes(self.pixmap_data[offset .. offset + pixels_n]));
                    } else {
                        var ri: u16 = 0;
                        while (ri < update.h) : (ri += 1) {
                            const row_pixels_n = @as(u32, update.w);
                            const row_pixels_offset = (@as(u32, self.width) * @as(u32, update.y + ri)) + @as(u32, update.x);
                            try writer.writeAll(std.mem.sliceAsBytes(self.pixmap_data[row_pixels_offset .. row_pixels_offset + row_pixels_n]));
                        }
                    }
                    platform.replybuf.ignoreEvent();
                }
            }

            const set_region = SetRegion{
                .opcode = platform.ext_op_xfixes,
                .request_length = 2 + @intCast(u16, updates.len * 2),
                .region = self.region,
            };
            try writer.writeAll(std.mem.asBytes(&set_region));
            for (updates) |update| {
                const rect = [4]u16{ update.x, update.y, update.w, update.h };
                try writer.writeAll(std.mem.asBytes(&rect));
            }
            platform.replybuf.ignoreEvent();

            const present_pixmap = PresentPixmap{
                .length = 18,
                .opcode = platform.ext_op_present,
                .window = self.handle,
                .pixmap = self.pixmap,
                .serial = self.frame_id,
                .valid_area = self.region,
                .update_area = self.region,
                .crtc = 0,
                .wait_fence = 0,
                .idle_fence = 0,
                .options = 0,
                .target_msc = 0,
                .divisor = 0,
                .remainder = 0,
            };
            try writer.writeAll(std.mem.asBytes(&present_pixmap));
            platform.replybuf.ignoreEvent();
        }
    };
}
