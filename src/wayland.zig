const std = @import("std");
const builtin = @import("builtin");
const zwl = @import("zwl.zig");
const Allocator = std.mem.Allocator;

pub fn Platform(comptime Parent: anytype) type {
    return struct {
        const Self = @This();
        parent: Parent,
        file: std.fs.File,

        pub fn init(allocator: *Allocator, options: zwl.PlatformOptions) !*Parent {
            const file = try displayConnect();
            errdefer file.close();

            var self = try allocator.create(Self);
            errdefer allocator.destroy(self);

            self.* = .{
                .parent = .{
                    .allocator = allocator,
                    .type = .Wayland,
                    .window = undefined,
                    .windows = if (!Parent.settings.single_window) &[0]*Parent.Window{} else undefined,
                },
                .file = file,
            };

            std.log.scoped(.zwl).info("Platform Initialized: Wayland", .{});
            return @ptrCast(*Parent, self);
        }

        pub fn deinit(self: *Self) void {
            self.file.close();
            self.parent.allocator.destroy(self);
        }

        pub fn waitForEvent(self: *Self) !Parent.Event {
            return error.Unimplemented;
        }

        pub fn createWindow(self: *Self, options: zwl.WindowOptions) !*Parent.Window {
            var window = try self.parent.allocator.create(Window);
            errdefer self.parent.allocator.destroy(window);

            var wbuf = std.io.bufferedWriter(self.file.writer());
            var writer = wbuf.writer();
            try window.init(self, options, writer);
            // Extra settings and shit
            try wbuf.flush();

            return @ptrCast(*Parent.Window, window);
        }

        pub const Window = struct {
            parent: Parent.Window,
            width: u16,
            height: u16,

            pub fn init(self: *Window, parent: *Self, options: zwl.WindowOptions, writer: anytype) !void {
                self.* = .{
                    .parent = .{
                        .platform = @ptrCast(*Parent, parent),
                    },
                    .width = options.width orelse 800,
                    .height = options.height orelse 600,
                };
            }
            pub fn deinit(self: *Window) void {
                // Do
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
    };
}

fn displayConnect() !std.fs.File {
    const XDG_RUNTIME_DIR = if (std.os.getenv("XDG_RUNTIME_DIR")) |val| val else return error.NoXDGRuntimeDirSpecified;
    const WAYLAND_DISPLAY = if (std.os.getenv("WAYLAND_DISPLAY")) |val| val else "wayland-0";

    var membuf: [256]u8 = undefined;
    var allocator = std.heap.FixedBufferAllocator.init(&membuf);
    const path = try std.mem.join(&allocator.allocator, "/", &[_][]const u8{ XDG_RUNTIME_DIR, WAYLAND_DISPLAY });

    const opt_non_block = if (std.io.is_async) os.SOCK_NONBLOCK else 0;
    var socket = try std.os.socket(std.os.AF_UNIX, std.os.SOCK_STREAM | std.os.SOCK_CLOEXEC | opt_non_block, 0);
    errdefer std.os.close(socket);

    var addr = std.os.sockaddr_un{ .path = [_]u8{0} ** 108 };
    std.mem.copy(u8, addr.path[0..], path);
    try std.os.connect(socket, @ptrCast(*const std.os.sockaddr, &addr), @sizeOf(std.os.sockaddr_un) - @intCast(u32, addr.path.len - path.len));
    return std.fs.File{ .handle = socket };
}
