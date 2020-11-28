const std = @import("std");
const builtin = @import("builtin");
const zwl = @import("../zwl.zig");
usingnamespace @import("proto.zig");
const DisplayInfo = @import("display_info.zig").DisplayInfo;
const AuthCookie = @import("auth.zig").AuthCookie;
const util = @import("util.zig");
const shm = @import("shm.zig");

pub fn do(platform: anytype, display_info: DisplayInfo, auth_cookie: ?AuthCookie) !void {
    var reader = platform.rbuf.reader();
    var writer = platform.wbuf.writer();

    try sendClientHandshake(writer, auth_cookie);
    try platform.wbuf.flush();
    const server_handshake = try readServerHandshake(reader);
    platform.xid_next = server_handshake.resource_id_base;

    if (display_info.screen >= server_handshake.roots_len) {
        std.log.scoped(.zwl).err("X11 screen {} does not exist, max is {}", .{ display_info.screen, server_handshake.roots_len });
        return error.InvalidScreen;
    }

    const screen_info = try readScreenInfo(reader, display_info.screen, server_handshake);

    platform.root = screen_info.root;
    platform.root_depth = screen_info.root_depth;
    platform.root_color_bits = screen_info.root_color_bits;
    platform.alpha_compat_visual = screen_info.alpha_compat_visual;

    // Extensions
    try initExtension(platform, writer, "XFIXES", .QueryExtXFixes);
    try initExtension(platform, writer, "BIG-REQUESTS", .QueryExtBigRequests);
    try initExtension(platform, writer, "Generic Event Extension", .QueryExtGenericEvents);
    try initExtension(platform, writer, "Present", .QueryExtPresent);

    if (display_info.unix) {
        try initExtension(platform, writer, "MIT-SHM", .QueryExtMitShm);
    }

    if (@TypeOf(platform.parent).settings.monitors == true) {
        try initExtension(platform, writer, "RANDR", .QueryExtRandr);
    }

    // Atoms
    try writer.writeAll(std.mem.asBytes(&InternAtom{
        .only_if_exists = 0,
        .request_length = @intCast(u16, (8 + "_MOTIF_WM_HINTS".len + util.xpad("_MOTIF_WM_HINTS".len)) >> 2),
        .length_of_name = "_MOTIF_WM_HINTS".len,
    }));
    try writer.writeAll("_MOTIF_WM_HINTS");
    try writer.writeByteNTimes(0, util.xpad("_MOTIF_WM_HINTS".len));
    try platform.replybuf.push(@enumToInt(ReplyId.AtomMotifWmHints));

    try platform.wbuf.flush();
    try handleEvents(platform, reader, writer);

    if (platform.ext_op_present == 0) return error.PresentExtensionNotSupported;
}

fn sendClientHandshake(writer: anytype, auth_cookie: ?AuthCookie) !void {
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
            .mit_magic_cookie_value = cookie.data,
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
            try reader.skipBytes(response.vendor_len + util.xpad(response.vendor_len), .{ .buf_size = 32 });
            return server_handshake;
        },
        else => return error.Protocol,
    }
}

const ScreenInfo = struct {
    root: u32 = 0,
    root_visual: u32 = 0,
    root_depth: u8 = 0,
    root_color_bits: u8 = 0,
    alpha_compat_visual: u32 = 0,
};

fn readScreenInfo(reader: anytype, screen_id: usize, server_handshake: ServerHandshake) !ScreenInfo {
    var screen_info: ScreenInfo = .{};

    var pfi: usize = 0;
    while (pfi < server_handshake.pixmap_formats_len) : (pfi += 1) {
        const format = try reader.readStruct(SetupPixmapFormat);
    }

    var sci: usize = 0;
    while (sci < server_handshake.roots_len) : (sci += 1) {
        const screen = try reader.readStruct(SetupScreen);
        if (sci == screen_id) {
            screen_info.root = screen.root;
        }

        var dpi: usize = 0;
        while (dpi < screen.allowed_depths_len) : (dpi += 1) {
            const depth = try reader.readStruct(SetupDepth);
            var vii: usize = 0;
            while (vii < depth.visual_count) : (vii += 1) {
                const visual = try reader.readStruct(SetupVisual);
                if (sci == screen_id and screen.root_visual_id == visual.id) {
                    screen_info.root_visual = visual.id;
                    screen_info.root_depth = depth.depth;
                    screen_info.root_color_bits = visual.bits_per_rgb;
                }

                if (screen_info.alpha_compat_visual == 0 and visual.class == .TrueColor and depth.depth == 32 and visual.bits_per_rgb == 8) {
                    screen_info.alpha_compat_visual = visual.id;
                }
            }
        }
    }
    return screen_info;
}

const ReplyId = enum(u32) {
    QueryExtXFixes,
    QueryExtBigRequests,
    QueryExtGenericEvents,
    QueryExtPresent,
    QueryExtMitShm,
    QueryExtRandr,
    AtomMotifWmHints,
    Ignore,
};

fn initExtension(platform: anytype, writer: anytype, name: []const u8, reply_id: ReplyId) !void {
    try writer.writeAll(std.mem.asBytes(&QueryExtension{ .request_length = 2 + (@intCast(u16, name.len) + 3) / 4, .length_of_name = @intCast(u16, name.len) }));
    try writer.writeAll(name);
    try writer.writeByteNTimes(0, util.xpad(name.len));
    try platform.replybuf.push(@enumToInt(reply_id));
}

fn handleEvents(platform: anytype, reader: anytype, writer: anytype) !void {
    while (platform.replybuf.len() > 0) {
        var evdata: [32]u8 align(8) = undefined;
        _ = try reader.readAll(evdata[0..]);
        const evtype = evdata[0] & 0x7F;
        const seq = std.mem.readIntNative(u16, evdata[2..4]);
        const extlen = std.mem.readIntNative(u32, evdata[4..8]) * 4;

        if (evtype == @enumToInt(XEvent.Error)) {
            unreachable; // We will never make mistakes during init :)
        } else if (evtype != @enumToInt(XEvent.Reply)) {
            continue; // Odd, but we don't really care at this state
        }

        switch (@intToEnum(ReplyId, platform.replybuf.get(seq) orelse unreachable)) {
            .QueryExtXFixes => {
                const qreply = @ptrCast(*const QueryExtensionReply, &evdata);
                if (qreply.present != 0) {
                    platform.ext_op_xfixes = qreply.major_opcode;
                    try writer.writeAll(std.mem.asBytes(&XFixesQueryVersion{ .opcode = qreply.major_opcode, .version_major = 5, .version_minor = 0 }));
                    try platform.replybuf.push(@enumToInt(ReplyId.Ignore));
                }
            },
            .QueryExtBigRequests => {
                const qreply = @ptrCast(*const QueryExtensionReply, &evdata);
                if (qreply.present != 0) {
                    try writer.writeAll(std.mem.asBytes(&BigReqEnable{ .opcode = qreply.major_opcode }));
                    try platform.replybuf.push(@enumToInt(ReplyId.Ignore));
                }
            },
            .QueryExtGenericEvents => {
                const qreply = @ptrCast(*const QueryExtensionReply, &evdata);
                if (qreply.present != 0) {
                    try writer.writeAll(std.mem.asBytes(&GEQueryVersion{ .opcode = qreply.major_opcode, .version_major = 1, .version_minor = 0 }));
                    try platform.replybuf.push(@enumToInt(ReplyId.Ignore));
                }
            },
            .QueryExtPresent => {
                const qreply = @ptrCast(*const QueryExtensionReply, &evdata);
                if (qreply.present != 0) {
                    platform.ext_op_present = qreply.major_opcode;
                    platform.ext_ev_present = qreply.first_event;
                    try writer.writeAll(std.mem.asBytes(&PresentQueryVersion{ .opcode = qreply.major_opcode, .version_major = 1, .version_minor = 0 }));
                    try platform.replybuf.push(@enumToInt(ReplyId.Ignore));
                }
            },
            .QueryExtMitShm => {
                const qreply = @ptrCast(*const QueryExtensionReply, &evdata);
                platform.ext_op_mitshm = qreply.major_opcode;
                if (qreply.present != 0) {
                    platform.ext_op_mitshm = qreply.major_opcode;
                    try writer.writeAll(std.mem.asBytes(&ShmQueryVersion{ .opcode = qreply.major_opcode }));
                    try platform.replybuf.push(@enumToInt(ReplyId.Ignore));
                }
            },
            .QueryExtRandr => {
                const qreply = @ptrCast(*const QueryExtensionReply, &evdata);
                platform.ext_op_randr = qreply.major_opcode;
                // hmm do it maybe
            },
            .AtomMotifWmHints => {
                const qreply = @ptrCast(*const InternAtomReply, &evdata);
                platform.atom_motif_wm_hints = qreply.atom;
            },
            .Ignore => {},
        }
        if (platform.rbuf.fifo.readableLength() == 0) {
            try platform.wbuf.flush();
        }
    }
}
