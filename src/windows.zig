const std = @import("std");
const builtin = @import("builtin");
const zwl = @import("zwl.zig");
const log = std.log.scoped(.zwl);
const Allocator = std.mem.Allocator;

const gl = @import("opengl.zig");

pub const windows = struct {
    pub const kernel32 = @import("windows/kernel32.zig");
    pub const user32 = @import("windows/user32.zig");
    pub const gdi32 = @import("windows/gdi32.zig");
    usingnamespace @import("windows/bits.zig");
};

const classname = std.unicode.utf8ToUtf16LeStringLiteral("ZWL");

pub fn Platform(comptime Parent: anytype) type {
    return struct {
        const Self = @This();

        parent: Parent,
        instance: windows.HINSTANCE,
        revent: ?Parent.Event = null,
        libgl: ?windows.HMODULE,

        pub fn init(allocator: *Allocator, options: zwl.PlatformOptions) !*Parent {
            var self = try allocator.create(Self);
            errdefer allocator.destroy(self);

            const module_handle = windows.kernel32.GetModuleHandleW(null) orelse unreachable;

            const window_class_info = windows.user32.WNDCLASSEXW{
                .style = windows.user32.CS_OWNDC | windows.user32.CS_HREDRAW | windows.user32.CS_VREDRAW,
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
            if (windows.user32.RegisterClassExW(&window_class_info) == 0) {
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
                self.libgl = windows.kernel32.LoadLibraryA("opengl32.dll") orelse return error.MissingOpenGL;
            }

            log.info("Platform Initialized: Windows", .{});
            return @ptrCast(*Parent, self);
        }

        pub fn deinit(self: *Self) void {
            if (self.libgl) |libgl| {
                _ = windows.kernel32.FreeLibrary(libgl);
            }
            _ = windows.user32.UnregisterClassW(classname, self.instance);
            self.parent.allocator.destroy(self);
        }

        pub fn getOpenGlProcAddress(self: *Self, entry_point: [:0]const u8) ?*c_void {
            // std.debug.print("lookup {} with ", .{
            //     std.mem.span(entry_point),
            // });
            if (self.libgl) |libgl| {
                const T = fn (entry_point: [*:0]const u8) ?*c_void;

                if (windows.kernel32.GetProcAddress(libgl, "wglGetProcAddress")) |wglGetProcAddress| {
                    if (@ptrCast(T, wglGetProcAddress)(entry_point.ptr)) |ptr| {
                        // std.debug.print("dynamic wglGetProcAddress: {}\n", .{ptr});
                        return @ptrCast(*c_void, ptr);
                    }
                }

                if (windows.kernel32.GetProcAddress(libgl, entry_point.ptr)) |ptr| {
                    // std.debug.print("GetProcAddress: {}\n", .{ptr});
                    return @ptrCast(*c_void, ptr);
                }
            }

            if (windows.gdi32.wglGetProcAddress(entry_point.ptr)) |ptr| {
                // std.debug.print("wglGetProcAddress: {}\n", .{ptr});
                return ptr;
            }

            // std.debug.print("none.\n", .{});
            return null;
        }

        fn windowProc(hwnd: windows.HWND, uMsg: c_uint, wParam: usize, lParam: ?*c_void) callconv(std.os.windows.WINAPI) ?*c_void {
            const msg = @intToEnum(windows.user32.WM, uMsg);
            switch (msg) {
                .CLOSE => {
                    _ = windows.user32.DestroyWindow(hwnd);
                },
                .DESTROY => {
                    var window_opt = @intToPtr(?*Window, @bitCast(usize, windows.user32.GetWindowLongPtrW(hwnd, 0)));
                    if (window_opt) |window| {
                        var platform = @ptrCast(*Self, window.parent.platform);
                        window.handle = null;
                        platform.revent = Parent.Event{ .WindowDestroyed = @ptrCast(*Parent.Window, window) };
                    } else {
                        log.emerg("Received message {} for unknown window {}", .{ msg, hwnd });
                    }
                },
                .CREATE => {
                    const create_info_opt = @ptrCast(?*windows.user32.CREATESTRUCTW, @alignCast(@alignOf(windows.user32.CREATESTRUCTW), lParam));
                    if (create_info_opt) |create_info| {
                        _ = windows.user32.SetWindowLongPtrW(hwnd, 0, @bitCast(isize, @ptrToInt(create_info.lpCreateParams)));
                    } else {
                        return @intToPtr(windows.LRESULT, @bitCast(usize, @as(isize, -1)));
                    }
                },
                .SIZE => {
                    var window_opt = @intToPtr(?*Window, @bitCast(usize, windows.user32.GetWindowLongPtrW(hwnd, 0)));
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
                    var window_opt = @intToPtr(?*Window, @bitCast(usize, windows.user32.GetWindowLongPtrW(hwnd, 0)));
                    if (window_opt) |window| {
                        var platform = @ptrCast(*Self, window.parent.platform);

                        var ps = std.mem.zeroes(windows.user32.PAINTSTRUCT);
                        if (windows.user32.BeginPaint(hwnd, &ps)) |hDC| {
                            defer _ = windows.user32.EndPaint(hwnd, &ps);
                            if (window.backend == .software) {
                                const render_context = &window.backend.software;

                                const hOldBmp = windows.gdi32.SelectObject(
                                    render_context.memory_dc,
                                    render_context.bitmap.handle.toGdiObject(),
                                );
                                defer _ = windows.gdi32.SelectObject(render_context.memory_dc, hOldBmp);

                                _ = windows.gdi32.BitBlt(
                                    hDC,
                                    0,
                                    0,
                                    render_context.bitmap.width,
                                    render_context.bitmap.height,
                                    render_context.memory_dc,
                                    0,
                                    0,
                                    @enumToInt(windows.gdi32.TernaryRasterOperation.SRCCOPY),
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
                    var window_opt = @intToPtr(?*Window, @bitCast(usize, windows.user32.GetWindowLongPtrW(hwnd, 0)));
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
                    var window_opt = @intToPtr(?*Window, @bitCast(usize, windows.user32.GetWindowLongPtrW(hwnd, 0)));
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
                    var window_opt = @intToPtr(?*Window, @bitCast(usize, windows.user32.GetWindowLongPtrW(hwnd, 0)));
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
                    return windows.user32.DefWindowProcW(hwnd, uMsg, wParam, lParam);
                },
            }
            return null;
        }

        pub fn waitForEvent(self: *Self) !Parent.Event {
            var msg: windows.user32.MSG = undefined;
            while (true) {
                if (self.revent) |rev| {
                    self.revent = null;
                    return rev;
                }
                const ret = windows.user32.GetMessageW(&msg, null, 0, 0);
                if (ret == -1) unreachable;
                if (ret == 0) return Parent.Event{ .ApplicationTerminated = undefined };
                _ = windows.user32.TranslateMessage(&msg);
                _ = windows.user32.DispatchMessageW(&msg);
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
                opengl: windows.gdi32.HGLRC,
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
                style += if (options.visible == true) @as(u32, windows.user32.WS_VISIBLE) else 0;
                style += if (options.decorations == true) @as(u32, windows.user32.WS_CAPTION | windows.user32.WS_MAXIMIZEBOX | windows.user32.WS_MINIMIZEBOX | windows.user32.WS_SYSMENU) else 0;
                style += if (options.resizeable == true) @as(u32, windows.user32.WS_SIZEBOX) else 0;

                // mode, transparent...
                // CLIENT_RECT stuff... GetClientRect, GetWindowRect

                var rect = windows.user32.RECT{ .left = 0, .top = 0, .right = self.width, .bottom = self.height };
                _ = windows.user32.AdjustWindowRectEx(&rect, style, 0, 0);
                const x = windows.user32.CW_USEDEFAULT;
                const y = windows.user32.CW_USEDEFAULT;
                const w = rect.right - rect.left;
                const h = rect.bottom - rect.top;

                const handle = windows.user32.CreateWindowExW(0, classname, title, style, x, y, w, h, null, null, platform.instance, self) orelse
                    return error.CreateWindowFailed;

                self.handle = handle;

                self.backend = switch (options.backend) {
                    .software => blk: {
                        const hDC = windows.user32.getDC(handle) catch return error.CreateWindowFailed;
                        defer _ = windows.user32.releaseDC(handle, hDC);

                        var render_context = RenderContext{
                            .memory_dc = undefined,
                            .bitmap = undefined,
                        };
                        render_context.memory_dc = windows.gdi32.CreateCompatibleDC(hDC) orelse return error.CreateWindowFailed;
                        errdefer _ = windows.gdi32.DeleteDC(render_context.memory_dc);

                        render_context.bitmap = render_context.createBitmap(self.width, self.height) catch return error.CreateWindowFailed;
                        errdefer render_context.bitmap.destroy();

                        break :blk Backend{ .software = render_context };
                    },
                    .opengl => |requested_gl| blk: {
                        if (Parent.settings.backends_enabled.opengl) {
                            const pfd = windows.gdi32.PIXELFORMATDESCRIPTOR{
                                .nVersion = 1,
                                .dwFlags = windows.gdi32.PFD_DRAW_TO_WINDOW | windows.gdi32.PFD_SUPPORT_OPENGL | windows.gdi32.PFD_DOUBLEBUFFER,
                                .iPixelType = windows.gdi32.PFD_TYPE_RGBA,
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
                                .iLayerType = windows.gdi32.PFD_MAIN_PLANE,
                                .bReserved = 0,
                                .dwLayerMask = 0,
                                .dwVisibleMask = 0,
                                .dwDamageMask = 0,
                            };

                            const hDC = windows.user32.GetDC(handle) orelse @panic("couldn't get DC!");
                            defer _ = windows.user32.ReleaseDC(handle, hDC);

                            const dummy_pixel_format = windows.gdi32.ChoosePixelFormat(hDC, &pfd);
                            _ = windows.gdi32.SetPixelFormat(hDC, dummy_pixel_format, &pfd);

                            const dummy_gl_context = windows.gdi32.wglCreateContext(hDC) orelse @panic("Couldn't create OpenGL context");
                            _ = windows.gdi32.wglMakeCurrent(hDC, dummy_gl_context);
                            // defer _ = windows.gdi32.wglMakeCurrent(hDC, null);
                            errdefer _ = windows.gdi32.wglDeleteContext(dummy_gl_context);

                            const wglChoosePixelFormatARB = @ptrCast(
                                fn (
                                    hdc: windows.user32.HDC,
                                    piAttribIList: ?[*:0]const c_int,
                                    pfAttribFList: ?[*:0]const f32,
                                    nMaxFormats: c_uint,
                                    piFormats: [*]c_int,
                                    nNumFormats: *c_uint,
                                ) callconv(windows.WINAPI) windows.BOOL,
                                windows.gdi32.wglGetProcAddress("wglChoosePixelFormatARB") orelse return error.InvalidOpenGL,
                            );

                            const wglCreateContextAttribsARB = @ptrCast(
                                fn (
                                    hDC: windows.user32.HDC,
                                    hshareContext: ?windows.user32.HGLRC,
                                    attribList: ?[*:0]const c_int,
                                ) callconv(windows.WINAPI) ?windows.user32.HGLRC,
                                windows.gdi32.wglGetProcAddress("wglCreateContextAttribsARB") orelse return error.InvalidOpenGL,
                            );

                            const pf_attributes = [_:0]c_int{
                                windows.gdi32.WGL_DRAW_TO_WINDOW_ARB, gl.GL_TRUE,
                                windows.gdi32.WGL_SUPPORT_OPENGL_ARB, gl.GL_TRUE,
                                windows.gdi32.WGL_DOUBLE_BUFFER_ARB,  gl.GL_TRUE,
                                windows.gdi32.WGL_PIXEL_TYPE_ARB,     windows.gdi32.WGL_TYPE_RGBA_ARB,
                                windows.gdi32.WGL_COLOR_BITS_ARB,     32,
                                windows.gdi32.WGL_DEPTH_BITS_ARB,     24,
                                windows.gdi32.WGL_STENCIL_BITS_ARB,   8,
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
                                windows.gdi32.WGL_CONTEXT_MAJOR_VERSION_ARB, requested_gl.major,
                                windows.gdi32.WGL_CONTEXT_MINOR_VERSION_ARB, requested_gl.minor,
                                windows.gdi32.WGL_CONTEXT_FLAGS_ARB,         windows.gdi32.WGL_CONTEXT_DEBUG_BIT_ARB,
                                windows.gdi32.WGL_CONTEXT_PROFILE_MASK_ARB,  if (requested_gl.core) windows.gdi32.WGL_CONTEXT_CORE_PROFILE_BIT_ARB else windows.gdi32.WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
                                0,
                            };

                            const gl_context = wglCreateContextAttribsARB(
                                hDC,
                                null,
                                &ctx_attributes,
                            ) orelse return error.InvalidOpenGL;
                            errdefer _ = windows.gdi32.wglDeleteContext(gl_context);

                            if (windows.gdi32.wglMakeCurrent(hDC, gl_context) == windows.FALSE)
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
                        _ = windows.gdi32.DeleteDC(render_context.memory_dc);
                    },
                    .opengl => |gl_context| {
                        if (Parent.settings.backends_enabled.opengl) {
                            const hDC = windows.user32.GetDC(self.handle) orelse @panic("couldn't get DC!");
                            defer _ = windows.user32.ReleaseDC(self.handle, hDC);

                            _ = windows.gdi32.wglMakeCurrent(hDC, gl_context);
                            _ = windows.gdi32.wglDeleteContext(gl_context);
                        } else {
                            unreachable;
                        }
                    },
                }

                if (self.handle) |handle| {
                    _ = windows.user32.SetWindowLongPtrW(handle, 0, 0);
                    _ = windows.user32.DestroyWindow(handle);
                }
                var platform = @ptrCast(*Self, self.parent.platform);
                platform.parent.allocator.destroy(self);
            }

            pub fn configure(self: *Window, options: zwl.WindowOptions) !void {
                return error.Unimplemented;
            }

            pub fn getSize(self: *Window) [2]u16 {
                return [2]u16{ self.width, self.height };
            }

            pub fn present(self: *Window) !void {
                switch (self.backend) {
                    .none => {},
                    .software => return error.InvalidRenderBackend,
                    .opengl => |hglrc| {
                        if (self.handle) |handle| {
                            const hDC = windows.user32.GetDC(handle) orelse @panic("couldn't get DC!");
                            defer _ = windows.user32.ReleaseDC(handle, hDC);

                            _ = windows.gdi32.SwapBuffers(hDC);

                            _ = windows.user32.InvalidateRect(
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
                        var platform = @ptrCast(*Self, self.parent.platform);

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
                if (self.backend != .software)
                    return error.InvalidRenderBackend;
                if (self.handle) |handle| {
                    _ = windows.user32.InvalidateRect(
                        handle,
                        null,
                        windows.FALSE, // We paint over *everything*
                    );
                }
            }

            const RenderContext = struct {
                const Bitmap = struct {
                    handle: windows.gdi32.HBITMAP,
                    pixels: [*]u32,
                    width: u16,
                    height: u16,

                    fn destroy(self: *@This()) void {
                        _ = windows.gdi32.DeleteObject(self.handle.toGdiObject());
                        self.* = undefined;
                    }
                };

                memory_dc: windows.user32.HDC,
                bitmap: Bitmap,

                fn createBitmap(self: @This(), width: u16, height: u16) !Bitmap {
                    var bmi = std.mem.zeroes(windows.gdi32.BITMAPINFO);
                    bmi.bmiHeader.biSize = @sizeOf(windows.gdi32.BITMAPINFOHEADER);
                    bmi.bmiHeader.biWidth = width;
                    bmi.bmiHeader.biHeight = -@as(i32, height);
                    bmi.bmiHeader.biPlanes = 1;
                    bmi.bmiHeader.biBitCount = 32;
                    bmi.bmiHeader.biCompression = @enumToInt(windows.gdi32.Compression.BI_RGB);

                    var bmp = Bitmap{
                        .width = width,
                        .height = height,
                        .handle = undefined,
                        .pixels = undefined,
                    };

                    bmp.handle = windows.gdi32.CreateDIBSection(
                        self.memory_dc,
                        &bmi,
                        @enumToInt(windows.gdi32.DIBColors.DIB_RGB_COLORS),
                        @ptrCast(**c_void, &bmp.pixels),
                        null,
                        0,
                    ) orelse return error.CreateBitmapError;

                    return bmp;
                }
            };
        };
    };
}
