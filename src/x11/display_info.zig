const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

pub const DisplayInfo = struct {
    unix: bool,
    host: []const u8,
    display: u6,
    screen: u8,

    pub fn init(allocator: *Allocator, host_override: ?[]const u8, display_override: ?u6, screen_override: ?u8) !DisplayInfo {

        // If everything is fixed, just return it verbatim without bothering with reading DISPLAY
        if (host_override != null and display_override != null and screen_override != null) {
            return DisplayInfo{
                .unix = if (@hasDecl(std.os, "sockaddr_un") and (std.mem.eql(u8, "localhost", host_override.?) or host_override.?.len == 0)) true else false,
                .host = host_override.?,
                .display = display_override.?,
                .screen = screen_override.?,
            };
        }

        // Get the DISPLAY env variable
        const DISPLAY = blk: {
            if (builtin.os.tag == .windows) {
                const display_w = std.os.getenvW(std.unicode.utf8ToUtf16LeStringLiteral("DISPLAY")) orelse break :blk ":0";
                break :blk std.unicode.utf16leToUtf8Alloc(allocator, display_w[0..]) catch break :blk ":0";
            } else {
                if (std.os.getenv("DISPLAY")) |d|
                    break :blk d;
            }
            break :blk ":0";
        };

        // Parse the host, display, and screen
        const colon = std.mem.indexOfScalar(u8, DISPLAY, ':') orelse return error.MalformedDisplay;
        const host = if (host_override != null) host_override.? else DISPLAY[0..colon];
        const unix = if (builtin.os.tag != .windows and @hasDecl(std.os, "sockaddr_un") and (std.mem.eql(u8, "localhost", host) or host.len == 0)) true else false;
        const dot = std.mem.indexOfScalar(u8, DISPLAY[colon..], '.');
        if (dot != null and dot.? == 1) return error.MalformedDisplay;
        const display = if (display_override != null) display_override.? else if (dot != null) try std.fmt.parseUnsigned(u6, DISPLAY[colon + 1 .. colon + dot.?], 10) else try std.fmt.parseUnsigned(u6, DISPLAY[colon + 1 ..], 10);
        const screen = if (screen_override != null) screen_override.? else if (dot != null) try std.fmt.parseUnsigned(u8, DISPLAY[colon + dot.? + 1 ..], 10) else 0;

        var self = DisplayInfo{
            .unix = unix,
            .host = host,
            .display = display,
            .screen = screen,
        };
        return self;
    }
};
