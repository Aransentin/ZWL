const std = @import("std");
const builtin = @import("builtin");
const zwl = @import("zwl.zig");
const log = std.log.scoped(.zwl);
const Allocator = std.mem.Allocator;

const gl = @import("opengl.zig");

pub const windows = @import("win32").everything;

const classname = std.unicode.utf8ToUtf16LeStringLiteral("ZWL");

pub fn Platform(comptime Parent: anytype) type {
    return struct {
        const Self = @This();

        parent: Parent,
        instance: windows.HINSTANCE,
        revent: ?Parent.Event = null,
        libgl: ?windows.HMODULE,

        pub fn init(allocator: Allocator, options: zwl.PlatformOptions) !*Parent {
            _ = options;
            var self = try allocator.create(Self);
            errdefer allocator.destroy(self);

            const module_handle = windows.GetModuleHandleW(null) orelse unreachable;

            const window_class_info = windows.WNDCLASSEXW{
                .style = windows.CS_OWNDC | windows.CS_HREDRAW | windows.CS_VREDRAW,
                .lpfnWndProc = windowProc,
                .cbClsExtra = 0,
                .cbWndExtra = @sizeOf(usize),
                .hInstance = @ptrCast(windows.HINSTANCE, module_handle),
                .hIcon = null,
                .hCursor = null,
                .hbrBackground = null,
                .lpszMenuName = null,
                .lpszClassName = classname,
                .hIconSm = null,
            };
            if (windows.RegisterClassExW(&window_class_info) == 0) {
                return error.RegisterClassFailed;
            }

            self.* = .{
                .parent = .{
                    .allocator = allocator,
                    .type = .Windows,
                    .window = undefined,
                    .windows = if (!Parent.settings.single_window) &[0]*Parent.Window{} else undefined,
                },
                .instance = @ptrCast(windows.HINSTANCE, module_handle),
                .libgl = null,
            };

            if (Parent.settings.backends_enabled.opengl) {
                self.libgl = windows.LoadLibraryA("opengl32.dll") orelse return error.MissingOpenGL;
            }

            log.info("Platform Initialized: Windows", .{});
            return @ptrCast(*Parent, self);
        }

        pub fn deinit(self: *Self) void {
            if (self.libgl) |libgl| {
                _ = windows.FreeLibrary(libgl);
            }
            _ = windows.UnregisterClassW(classname, self.instance);
            self.parent.allocator.destroy(self);
        }

        pub fn getOpenGlProcAddress(self: *Self, entry_point: [:0]const u8) ?*anyopaque {
            // std.debug.print("lookup {} with ", .{
            //     std.mem.span(entry_point),
            // });
            if (self.libgl) |libgl| {
                const T = fn (entry_point: [*:0]const u8) ?*anyopaque;

                if (windows.GetProcAddress(libgl, "wglGetProcAddress")) |wglGetProcAddress| {
                    if (@ptrCast(T, wglGetProcAddress)(entry_point.ptr)) |ptr| {
                        // std.debug.print("dynamic wglGetProcAddress: {}\n", .{ptr});
                        return @ptrCast(*anyopaque, ptr);
                    }
                }

                if (windows.GetProcAddress(libgl, entry_point.ptr)) |ptr| {
                    // std.debug.print("GetProcAddress: {}\n", .{ptr});
                    return @ptrCast(*anyopaque, ptr);
                }
            }

            if (windows.wglGetProcAddress(entry_point.ptr)) |ptr| {
                // std.debug.print("wglGetProcAddress: {}\n", .{ptr});
                return ptr;
            }

            // std.debug.print("none.\n", .{});
            return null;
        }

        fn windowProc(hwnd: windows.HWND, uMsg: c_uint, wParam: usize, lParam: ?*anyopaque) callconv(windows.WINAPI) ?*anyopaque {
            const msg = @intToEnum(windows.WM, uMsg);
            switch (msg) {
                .CLOSE => {
                    _ = windows.DestroyWindow(hwnd);
                },
                .DESTROY => {
                    var window_opt = @intToPtr(?*Window, @bitCast(usize, windows.GetWindowLongPtrW(hwnd, 0)));
                    if (window_opt) |window| {
                        var platform = @ptrCast(*Self, window.parent.platform);
                        window.handle = null;
                        platform.revent = Parent.Event{ .WindowDestroyed = @ptrCast(*Parent.Window, window) };
                    } else {
                        log.emerg("Received message {} for unknown window {}", .{ msg, hwnd });
                    }
                },
                .CREATE => {
                    const create_info_opt = @ptrCast(?*windows.CREATESTRUCTW, @alignCast(@alignOf(windows.CREATESTRUCTW), lParam));
                    if (create_info_opt) |create_info| {
                        _ = windows.SetWindowLongPtrW(hwnd, 0, @bitCast(isize, @ptrToInt(create_info.lpCreateParams)));
                    } else {
                        return @intToPtr(windows.LRESULT, @bitCast(usize, @as(isize, -1)));
                    }
                },
                .SIZE => {
                    var window_opt = @intToPtr(?*Window, @bitCast(usize, windows.GetWindowLongPtrW(hwnd, 0)));
                    if (window_opt) |window| {
                        const dim = @bitCast([2]u16, @intCast(u32, @ptrToInt(lParam)));
                        if (dim[0] != window.width or dim[1] != window.height) {
                            var platform = @ptrCast(*Self, window.parent.platform);
                            window.width = dim[0];
                            window.height = dim[1];

                            if (window.backend == .software) {
                                if (window.backend.software.createBitmap(window.width, window.height)) |new_bmp| {
                                    window.backend.software.bitmap.destroy();
                                    window.backend.software.bitmap = new_bmp;
                                } else |err| {
                                    log.emerg("failed to recreate software framebuffer: {}", .{err});
                                }
                            }

                            platform.revent = Parent.Event{ .WindowResized = @ptrCast(*Parent.Window, window) };
                        }
                    } else {
                        log.emerg("Received message {} for unknown window {}", .{ msg, hwnd });
                    }
                },
                .PAINT => {
                    var window_opt = @intToPtr(?*Window, @bitCast(usize, windows.GetWindowLongPtrW(hwnd, 0)));
                    if (window_opt) |window| {
                        var platform = @ptrCast(*Self, window.parent.platform);

                        var ps = std.mem.zeroes(windows.PAINTSTRUCT);
                        if (windows.BeginPaint(hwnd, &ps)) |hDC| {
                            defer _ = windows.EndPaint(hwnd, &ps);
                            if (window.backend == .software) {
                                const render_context = &window.backend.software;

                                const hOldBmp = windows.SelectObject(
                                    render_context.memory_dc,
                                    render_context.bitmap.handle.toGdiObject(),
                                );
                                defer _ = windows.SelectObject(render_context.memory_dc, hOldBmp);

                                _ = windows.BitBlt(
                                    hDC,
                                    0,
                                    0,
                                    render_context.bitmap.width,
                                    render_context.bitmap.height,
                                    render_context.memory_dc,
                                    0,
                                    0,
                                    @enumToInt(windows.TernaryRasterOperation.SRCCOPY),
                                );
                            }
                        }

                        platform.revent = Parent.Event{ .WindowVBlank = @ptrCast(*Parent.Window, window) };
                    } else {
                        log.emerg("Received message {} for unknown window {}", .{ msg, hwnd });
                    }
                },

                // https://docs.microsoft.com/en-us/windows/win32/inputdev/wm-mousemove
                .MOUSEMOVE => {
                    var window_opt = @intToPtr(?*Window, @bitCast(usize, windows.GetWindowLongPtrW(hwnd, 0)));
                    if (window_opt) |window| {
                        var platform = @ptrCast(*Self, window.parent.platform);

                        const pos = @bitCast([2]u16, @intCast(u32, @ptrToInt(lParam)));

                        platform.revent = Parent.Event{
                            .MouseMotion = .{
                                .x = @intCast(i16, pos[0]),
                                .y = @intCast(i16, pos[1]),
                            },
                        };
                    } else {
                        log.emerg("Received message {} for unknown window {}", .{ msg, hwnd });
                    }
                },
                .LBUTTONDOWN, // https://docs.microsoft.com/en-us/windows/win32/inputdev/wm-lbuttondown
                .LBUTTONUP, // https://docs.microsoft.com/en-us/windows/win32/inputdev/wm-lbuttonup
                .RBUTTONDOWN, // https://docs.microsoft.com/en-us/windows/win32/inputdev/wm-rbuttondown
                .RBUTTONUP, // https://docs.microsoft.com/en-us/windows/win32/inputdev/wm-rbuttonup
                .MBUTTONDOWN, // https://docs.microsoft.com/en-us/windows/win32/inputdev/wm-mbuttondown
                .MBUTTONUP, // https://docs.microsoft.com/en-us/windows/win32/inputdev/wm-mbuttonup
                => {
                    var window_opt = @intToPtr(?*Window, @bitCast(usize, windows.GetWindowLongPtrW(hwnd, 0)));
                    if (window_opt) |window| {
                        var platform = @ptrCast(*Self, window.parent.platform);

                        const pos = @bitCast([2]u16, @intCast(u32, @ptrToInt(lParam)));

                        var data = zwl.MouseButtonEvent{
                            .x = @intCast(i16, pos[0]),
                            .y = @intCast(i16, pos[1]),
                            .button = switch (msg) {
                                .LBUTTONDOWN, .LBUTTONUP => .left,
                                .MBUTTONDOWN, .MBUTTONUP => .middle,
                                .RBUTTONDOWN, .RBUTTONUP => .right,
                                else => unreachable,
                            },
                        };

                        platform.revent = if ((msg == .LBUTTONDOWN) or (msg == .MBUTTONDOWN) or (msg == .RBUTTONDOWN))
                            Parent.Event{ .MouseButtonDown = data }
                        else
                            Parent.Event{ .MouseButtonUp = data };
                    } else {
                        log.emerg("Received message {} for unknown window {}", .{ msg, hwnd });
                    }
                },
                .KEYDOWN, // https://docs.microsoft.com/en-us/windows/win32/inputdev/wm-keydown
                .KEYUP, // https://docs.microsoft.com/en-us/windows/win32/inputdev/wm-keydown
                => {
                    var window_opt = @intToPtr(?*Window, @bitCast(usize, windows.GetWindowLongPtrW(hwnd, 0)));
                    if (window_opt) |window| {
                        var platform = @ptrCast(*Self, window.parent.platform);

                        var kevent = zwl.KeyEvent{
                            .scancode = @truncate(u8, @ptrToInt(lParam) >> 16), // 16-23 is the OEM scancode
                        };

                        platform.revent = if (msg == .KEYDOWN)
                            Parent.Event{ .KeyDown = kevent }
                        else
                            Parent.Event{ .KeyUp = kevent };
                    } else {
                        log.emerg("Received message {} for unknown window {}", .{ msg, hwnd });
                    }
                },
                else => {
                    // log.debug("default windows message: 0x{X:0>4}", .{uMsg});
                    return windows.DefWindowProcW(hwnd, uMsg, wParam, lParam);
                },
            }
            return null;
        }

        pub fn waitForEvent(self: *Self) !Parent.Event {
            var msg: windows.MSG = undefined;
            while (true) {
                if (self.revent) |rev| {
                    self.revent = null;
                    return rev;
                }
                const ret = windows.GetMessageW(&msg, null, 0, 0);
                if (ret == -1) unreachable;
                if (ret == 0) return Parent.Event{ .ApplicationTerminated = undefined };
                _ = windows.TranslateMessage(&msg);
                _ = windows.DispatchMessageW(&msg);
            }
        }

        pub fn createWindow(self: *Self, options: zwl.WindowOptions) !*Parent.Window {
            var window = try self.parent.allocator.create(Window);
            errdefer self.parent.allocator.destroy(window);
            try window.init(self, options);
            return @ptrCast(*Parent.Window, window);
        }

        pub const Window = struct {
            const Backend = union(enum) {
                none,
                software: RenderContext,
                opengl: windows.HGLRC,
            };

            parent: Parent.Window,
            handle: ?windows.HWND,
            width: u16,
            height: u16,
            backend: Backend,

            pub fn init(self: *Window, platform: *Self, options: zwl.WindowOptions) !void {
                self.* = .{
                    .parent = .{
                        .platform = @ptrCast(*Parent, platform),
                    },
                    .width = options.width orelse 800,
                    .height = options.height orelse 600,
                    .handle = undefined,
                    .backend = .none,
                };

                var namebuf: [512]u8 = undefined;
                var name_allocator = std.heap.FixedBufferAllocator.init(&namebuf);
                const title = try std.unicode.utf8ToUtf16LeWithNull(&name_allocator.allocator, options.title orelse "");
                var style: u32 = 0;
                style += if (options.visible == true) @as(u32, windows.WS_VISIBLE) else 0;
                style += if (options.decorations == true) @as(u32, windows.WS_CAPTION | windows.WS_MAXIMIZEBOX | windows.WS_MINIMIZEBOX | windows.WS_SYSMENU) else 0;
                style += if (options.resizeable == true) @as(u32, windows.WS_SIZEBOX) else 0;

                // mode, transparent...
                // CLIENT_RECT stuff... GetClientRect, GetWindowRect

                var rect = windows.RECT{ .left = 0, .top = 0, .right = self.width, .bottom = self.height };
                _ = windows.AdjustWindowRectEx(&rect, style, 0, 0);
                const x = windows.CW_USEDEFAULT;
                const y = windows.CW_USEDEFAULT;
                const w = rect.right - rect.left;
                const h = rect.bottom - rect.top;

                const handle = windows.CreateWindowExW(0, classname, title, style, x, y, w, h, null, null, platform.instance, self) orelse
                    return error.CreateWindowFailed;

                self.handle = handle;

                self.backend = switch (options.backend) {
                    .software => blk: {
                        const hDC = windows.getDC(handle) catch return error.CreateWindowFailed;
                        defer _ = windows.releaseDC(handle, hDC);

                        var render_context = RenderContext{
                            .memory_dc = undefined,
                            .bitmap = undefined,
                        };
                        render_context.memory_dc = windows.CreateCompatibleDC(hDC) orelse return error.CreateWindowFailed;
                        errdefer _ = windows.DeleteDC(render_context.memory_dc);

                        render_context.bitmap = render_context.createBitmap(self.width, self.height) catch return error.CreateWindowFailed;
                        errdefer render_context.bitmap.destroy();

                        break :blk Backend{ .software = render_context };
                    },
                    .opengl => |requested_gl| blk: {
                        if (Parent.settings.backends_enabled.opengl) {
                            const pfd = windows.PIXELFORMATDESCRIPTOR{
                                .nVersion = 1,
                                .dwFlags = windows.PFD_DRAW_TO_WINDOW | windows.PFD_SUPPORT_OPENGL | windows.PFD_DOUBLEBUFFER,
                                .iPixelType = windows.PFD_TYPE_RGBA,
                                .cColorBits = 32,
                                .cRedBits = 0,
                                .cRedShift = 0,
                                .cGreenBits = 0,
                                .cGreenShift = 0,
                                .cBlueBits = 0,
                                .cBlueShift = 0,
                                .cAlphaBits = 0,
                                .cAlphaShift = 0,
                                .cAccumBits = 0,
                                .cAccumRedBits = 0,
                                .cAccumGreenBits = 0,
                                .cAccumBlueBits = 0,
                                .cAccumAlphaBits = 0,
                                .cDepthBits = 24,
                                .cStencilBits = 8,
                                .cAuxBuffers = 0,
                                .iLayerType = windows.PFD_MAIN_PLANE,
                                .bReserved = 0,
                                .dwLayerMask = 0,
                                .dwVisibleMask = 0,
                                .dwDamageMask = 0,
                            };

                            const hDC = windows.GetDC(handle) orelse @panic("couldn't get DC!");
                            defer _ = windows.ReleaseDC(handle, hDC);

                            const dummy_pixel_format = windows.ChoosePixelFormat(hDC, &pfd);
                            _ = windows.SetPixelFormat(hDC, dummy_pixel_format, &pfd);

                            const dummy_gl_context = windows.wglCreateContext(hDC) orelse @panic("Couldn't create OpenGL context");
                            _ = windows.wglMakeCurrent(hDC, dummy_gl_context);
                            // defer _ = windows.wglMakeCurrent(hDC, null);
                            errdefer _ = windows.wglDeleteContext(dummy_gl_context);

                            const wglChoosePixelFormatARB = @ptrCast(
                                fn (
                                    hdc: windows.HDC,
                                    piAttribIList: ?[*:0]const c_int,
                                    pfAttribFList: ?[*:0]const f32,
                                    nMaxFormats: c_uint,
                                    piFormats: [*]c_int,
                                    nNumFormats: *c_uint,
                                ) callconv(windows.WINAPI) windows.BOOL,
                                windows.wglGetProcAddress("wglChoosePixelFormatARB") orelse return error.InvalidOpenGL,
                            );

                            const wglCreateContextAttribsARB = @ptrCast(
                                fn (
                                    hDC: windows.HDC,
                                    hshareContext: ?windows.HGLRC,
                                    attribList: ?[*:0]const c_int,
                                ) callconv(windows.WINAPI) ?windows.HGLRC,
                                windows.wglGetProcAddress("wglCreateContextAttribsARB") orelse return error.InvalidOpenGL,
                            );

                            const pf_attributes = [_:0]c_int{
                                windows.WGL_DRAW_TO_WINDOW_ARB, gl.GL_TRUE,
                                windows.WGL_SUPPORT_OPENGL_ARB, gl.GL_TRUE,
                                windows.WGL_DOUBLE_BUFFER_ARB,  gl.GL_TRUE,
                                windows.WGL_PIXEL_TYPE_ARB,     windows.WGL_TYPE_RGBA_ARB,
                                windows.WGL_COLOR_BITS_ARB,     32,
                                windows.WGL_DEPTH_BITS_ARB,     24,
                                windows.WGL_STENCIL_BITS_ARB,   8,
                                0, // End
                            };

                            var pixelFormat: c_int = undefined;
                            var numFormats: c_uint = undefined;

                            if (wglChoosePixelFormatARB(hDC, &pf_attributes, null, 1, @ptrCast([*]c_int, &pixelFormat), &numFormats) == windows.FALSE)
                                return error.InvalidOpenGL;
                            if (numFormats == 0) // AMD driver may return numFormats > nMaxFormats, see issue #14
                                return error.InvalidOpenGL;

                            if (dummy_pixel_format != pixelFormat)
                                @panic("This case is not implemented yet: Recreation of the window is required here!");

                            const ctx_attributes = [_:0]c_int{
                                windows.WGL_CONTEXT_MAJOR_VERSION_ARB, requested_gl.major,
                                windows.WGL_CONTEXT_MINOR_VERSION_ARB, requested_gl.minor,
                                windows.WGL_CONTEXT_FLAGS_ARB,         windows.WGL_CONTEXT_DEBUG_BIT_ARB,
                                windows.WGL_CONTEXT_PROFILE_MASK_ARB,  if (requested_gl.core) windows.WGL_CONTEXT_CORE_PROFILE_BIT_ARB else windows.WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
                                0,
                            };

                            const gl_context = wglCreateContextAttribsARB(
                                hDC,
                                null,
                                &ctx_attributes,
                            ) orelse return error.InvalidOpenGL;
                            errdefer _ = windows.wglDeleteContext(gl_context);

                            if (windows.wglMakeCurrent(hDC, gl_context) == windows.FALSE)
                                return error.InvalidOpenGL;

                            break :blk Backend{ .opengl = gl_context };
                        } else {
                            @panic("OpenGL support not enabled");
                        }
                    },
                    else => .none,
                };
            }

            pub fn deinit(self: *Window) void {
                switch (self.backend) {
                    .none => {},
                    .software => |*render_context| {
                        render_context.bitmap.destroy();
                        _ = windows.DeleteDC(render_context.memory_dc);
                    },
                    .opengl => |gl_context| {
                        if (Parent.settings.backends_enabled.opengl) {
                            const hDC = windows.GetDC(self.handle) orelse @panic("couldn't get DC!");
                            defer _ = windows.ReleaseDC(self.handle, hDC);

                            _ = windows.wglMakeCurrent(hDC, gl_context);
                            _ = windows.wglDeleteContext(gl_context);
                        } else {
                            unreachable;
                        }
                    },
                }

                if (self.handle) |handle| {
                    _ = windows.SetWindowLongPtrW(handle, 0, 0);
                    _ = windows.DestroyWindow(handle);
                }
                var platform = @ptrCast(*Self, self.parent.platform);
                platform.parent.allocator.destroy(self);
            }

            pub fn configure(self: *Window, options: zwl.WindowOptions) !void {
                _ = self;
                _ = options;
                return error.Unimplemented;
            }

            pub fn getSize(self: *Window) [2]u16 {
                return [2]u16{ self.width, self.height };
            }

            pub fn present(self: *Window) !void {
                switch (self.backend) {
                    .none => {},
                    .software => return error.InvalidRenderBackend,
                    .opengl => {
                        if (self.handle) |handle| {
                            const hDC = windows.GetDC(handle) orelse @panic("couldn't get DC!");
                            defer _ = windows.ReleaseDC(handle, hDC);

                            _ = windows.SwapBuffers(hDC);

                            _ = windows.InvalidateRect(
                                handle,
                                null,
                                windows.FALSE, // We paint over *everything*
                            );
                        }
                    },
                }
            }

            pub fn mapPixels(self: *Window) !zwl.PixelBuffer {
                switch (self.backend) {
                    .software => |render_ctx| {
                        // var platform = @ptrCast(*Self, self.parent.platform);

                        return zwl.PixelBuffer{
                            .data = render_ctx.bitmap.pixels,
                            .width = render_ctx.bitmap.width,
                            .height = render_ctx.bitmap.height,
                        };
                    },
                    else => return error.InvalidRenderBackend,
                }
            }

            pub fn submitPixels(self: *Window, updates: []const zwl.UpdateArea) !void {
                _ = updates;
                if (self.backend != .software)
                    return error.InvalidRenderBackend;
                if (self.handle) |handle| {
                    _ = windows.InvalidateRect(
                        handle,
                        null,
                        windows.FALSE, // We paint over *everything*
                    );
                }
            }

            const RenderContext = struct {
                const Bitmap = struct {
                    handle: windows.HBITMAP,
                    pixels: [*]u32,
                    width: u16,
                    height: u16,

                    fn destroy(self: *@This()) void {
                        _ = windows.DeleteObject(self.handle.toGdiObject());
                        self.* = undefined;
                    }
                };

                memory_dc: windows.HDC,
                bitmap: Bitmap,

                fn createBitmap(self: @This(), width: u16, height: u16) !Bitmap {
                    var bmi = std.mem.zeroes(windows.BITMAPINFO);
                    bmi.bmiHeader.biSize = @sizeOf(windows.BITMAPINFOHEADER);
                    bmi.bmiHeader.biWidth = width;
                    bmi.bmiHeader.biHeight = -@as(i32, height);
                    bmi.bmiHeader.biPlanes = 1;
                    bmi.bmiHeader.biBitCount = 32;
                    bmi.bmiHeader.biCompression = @enumToInt(windows.Compression.BI_RGB);

                    var bmp = Bitmap{
                        .width = width,
                        .height = height,
                        .handle = undefined,
                        .pixels = undefined,
                    };

                    bmp.handle = windows.CreateDIBSection(
                        self.memory_dc,
                        &bmi,
                        @enumToInt(windows.DIBColors.DIB_RGB_COLORS),
                        @ptrCast(**anyopaque, &bmp.pixels),
                        null,
                        0,
                    ) orelse return error.CreateBitmapError;

                    return bmp;
                }
            };
        };
    };
}
