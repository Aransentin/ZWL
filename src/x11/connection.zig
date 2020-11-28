const std = @import("std");
const builtin = @import("builtin");
const DisplayInfo = @import("display_info.zig").DisplayInfo;

pub const Connection = struct {
    file: std.fs.File,
    is_unix: bool,

    pub fn init(display_info: DisplayInfo, comptime unix_only: bool) !Connection {
        if (builtin.os.tag == .windows) _ = try std.os.windows.WSAStartup(2, 2);
        errdefer if (builtin.os.tag == .windows) std.os.windows.WSACleanup() catch unreachable;
        if (unix_only or display_info.unix) return connectUnix(display_info);
        return connectTCP(display_info);
    }

    fn connectUnix(display_info: DisplayInfo) !Connection {
        const opt_non_block = if (std.io.is_async) os.SOCK_NONBLOCK else 0;
        var socket = try std.os.socket(std.os.AF_UNIX, std.os.SOCK_STREAM | std.os.SOCK_CLOEXEC | opt_non_block, 0);
        errdefer std.os.close(socket);
        var addr = std.os.sockaddr_un{ .path = [_]u8{0} ** 108 };
        std.mem.copy(u8, addr.path[0..], "\x00/tmp/.X11-unix/X");
        _ = std.fmt.formatIntBuf(addr.path["\x00/tmp/.X11-unix/X".len..], display_info.display, 10, false, .{});
        const addrlen = 1 + std.mem.lenZ(@ptrCast([*:0]u8, addr.path[1..]));
        try std.os.connect(socket, @ptrCast(*const std.os.sockaddr, &addr), @sizeOf(std.os.sockaddr_un) - @intCast(u32, addr.path.len - addrlen));

        return Connection{
            .file = std.fs.File{ .handle = socket },
            .is_unix = true,
        };
    }

    fn connectTCP(display_info: DisplayInfo) !Connection {
        const hostname = if (std.mem.eql(u8, display_info.host, "")) "127.0.0.1" else display_info.host;
        var tmpmem: [4096]u8 = undefined;
        var tmpalloc = std.heap.FixedBufferAllocator.init(tmpmem[0..]);
        const file = try std.net.tcpConnectToHost(&tmpalloc.allocator, hostname, 6000 + @intCast(u16, display_info.display));
        errdefer file.close();
        // Set TCP_NODELAY? etc.
        return Connection{
            .file = file,
            .is_unix = false,
        };
    }

    pub fn deinit(self: *Connection) void {
        if (builtin.os.tag == .windows) std.os.windows.WSACleanup() catch unreachable;
    }
};
