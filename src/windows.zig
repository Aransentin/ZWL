const std = @import("std");
const builtin = @import("builtin");
const zwl = @import("zwl.zig");
const Allocator = std.mem.Allocator;
const windows = std.os.windows;

const classname = std.unicode.utf8ToUtf16LeStringLiteral("ZWL");

pub fn Platform(comptime Parent: anytype) type {
    return struct {
        const Self = @This();
        parent: Parent,
        instance: windows.HINSTANCE,
        revent: ?Parent.Event = null,

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
            };

            std.log.scoped(.zwl).info("Platform Initialized: Windows", .{});
            return @ptrCast(*Parent, self);
        }

        pub fn deinit(self: *Self) void {
            _ = windows.user32.UnregisterClassW(classname, self.instance);
            self.parent.allocator.destroy(self);
        }

        fn windowProc(hwnd: windows.HWND, uMsg: c_uint, wParam: usize, lParam: ?*c_void) callconv(.Stdcall) ?*c_void {
            switch (uMsg) {
                windows.user32.WM_CLOSE => {
                    _ = windows.user32.DestroyWindow(hwnd);
                },
                windows.user32.WM_DESTROY => {
                    var window_opt = @intToPtr(?*Window, @bitCast(usize, windows.user32.GetWindowLongPtrW(hwnd, 0)));
                    if (window_opt) |window| {
                        var platform = @ptrCast(*Self, window.parent.platform);
                        window.handle = null;
                        platform.revent = Parent.Event{ .WindowDestroyed = @ptrCast(*Parent.Window, window) };
                    }
                },
                windows.user32.WM_SIZE => {
                    var window_opt = @intToPtr(?*Window, @bitCast(usize, windows.user32.GetWindowLongPtrW(hwnd, 0)));
                    if (window_opt) |window| {
                        const dim = @bitCast([2]u16, @intCast(u32, @ptrToInt(lParam)));
                        if (dim[0] != window.width or dim[1] != window.height) {
                            var platform = @ptrCast(*Self, window.parent.platform);
                            window.width = dim[0];
                            window.height = dim[1];
                            platform.revent = Parent.Event{ .WindowResized = @ptrCast(*Parent.Window, window) };
                        }
                    }
                },
                else => {
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
            parent: Parent.Window,
            handle: ?windows.HWND,
            width: u16,
            height: u16,

            pub fn init(self: *Window, platform: *Self, options: zwl.WindowOptions) !void {
                self.* = .{
                    .parent = .{
                        .platform = @ptrCast(*Parent, platform),
                    },
                    .width = options.width orelse 800,
                    .height = options.height orelse 600,
                    .handle = undefined,
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
                const handle = windows.user32.CreateWindowExW(0, classname, title, style, x, y, w, h, null, null, platform.instance, null);
                if (handle == null) return error.CreateWindowFailed;
                self.handle = handle.?;
                _ = windows.user32.SetWindowLongPtrW(self.handle, 0, @bitCast(isize, @ptrToInt(self)));
            }

            pub fn deinit(self: *Window) void {
                if (self.handle != null) {
                    _ = windows.user32.SetWindowLongPtrW(self.handle, 0, 0);
                    _ = windows.user32.DestroyWindow(self.handle);
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

            pub fn mapPixels(self: *Window) !Parent.PixelBuffer {
                var platform = @ptrCast(*Self, self.parent.platform);
                return error.Nope;
                //return Parent.PixelBuffer{ .data = undefined, .width = self.sw.width, .height = self.sw.height };
            }

            pub fn submitPixels(self: *Window) !void {
                // Do
            }
        };
    };
}
