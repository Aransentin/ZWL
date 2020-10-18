const std = @import("std");

pub const Display = opaque {};
pub const xcb_connection_t = opaque {};

pub const xcb_keycode_t = u8;
pub const xcb_window_t = u32;
pub const xcb_colormap_t = u32;
pub const xcb_visualid_t = u32;
pub const xcb_void_cookie_t = u32;
pub const xcb_atom_t = u32;
pub const xcb_intern_atom_cookie_t = u32;
pub const xcb_drawable_t = u32;
pub const xcb_gcontext_t = u32;

pub const xcb_auth_info_t = extern struct {
    namelen: i32,
    name: [*]const u8,
    datalen: i32,
    data: [*]const u8,
};

pub const xcb_generic_event_t = extern struct {
    response_type: u8,
    pad0: u8,
    sequence: u16,
    pad1: [7]u32,
    full_sequence: u32,
};

pub const xcb_generic_error_t = extern struct {
    response_type: u8,
    error_code: u8,
    sequence: u16,
    resource_id: u32,
    minor_code: u16,
    major_code: u8,
    pad0: u8,
    pad1: [5]u32,
    full_sequence: u32,
};

pub const xcb_setup_t = extern struct {
    status: u8,
    pad0: u8,
    protocol_major_version: u16,
    protocol_minor_version: u16,
    length: u16,
    release_number: u32,
    resource_id_base: u32,
    resource_id_mask: u32,
    motion_buffer_size: u32,
    vendor_len: u16,
    maximum_request_length: u16,
    roots_len: u8,
    pixmap_formats_len: u8,
    image_byte_order: u8,
    bitmap_format_bit_order: u8,
    bitmap_format_scanline_unit: u8,
    bitmap_format_scanline_pad: u8,
    min_keycode: xcb_keycode_t,
    max_keycode: xcb_keycode_t,
    pad1: [4]u8,
};

pub const xcb_screen_t = extern struct {
    root: xcb_window_t,
    default_colormap: xcb_colormap_t,
    white_pixel: u32,
    black_pixel: u32,
    current_input_masks: u32,
    width_in_pixels: u16,
    height_in_pixels: u16,
    width_in_millimeters: u16,
    height_in_millimeters: u16,
    min_installed_maps: u16,
    max_installed_maps: u16,
    root_visual: xcb_visualid_t,
    backing_stores: u8,
    save_unders: u8,
    root_depth: u8,
    allowed_depths_len: u8,
};

pub const xcb_screen_iterator_t = extern struct {
    data: *xcb_screen_t,
    rem: c_int,
    index: c_int,
};

pub const xcb_size_hints_t = extern struct {
    flags: u32 = 0,
    pos: [2]i32 = [2]i32{ 0, 0 },
    dim: [2]i32 = [2]i32{ 0, 0 },
    min: [2]i32 = [2]i32{ 0, 0 },
    max: [2]i32 = [2]i32{ 0, 0 },
    inc: [2]i32 = [2]i32{ 0, 0 },
    aspect_min: [2]i32 = [2]i32{ 0, 0 },
    aspect_max: [2]i32 = [2]i32{ 0, 0 },
    base: [2]i32 = [2]i32{ 0, 0 },
    win_gravity: u32 = 0,
};

pub const xcb_intern_atom_reply_t = extern struct {
    response_type: u8,
    pad0: u8,
    sequence: u16,
    length: u32,
    atom: xcb_atom_t,
};

pub const xcb_expose_event_t = extern struct {
    response_type: u8,
    pad0: u8,
    sequence: u16,
    window: xcb_window_t,
    x: u16,
    y: u16,
    width: u16,
    height: u16,
    count: u16,
    pad1: [2]u8,
};

pub const xcb_configure_notify_event_t = extern struct {
    response_type: u8,
    pad0: u8,
    sequence: u16,
    event: xcb_window_t,
    window: xcb_window_t,
    above_sibling: xcb_window_t,
    x: i16,
    y: i16,
    width: u16,
    height: u16,
    border_width: u16,
    override_redirect: u8,
    pad1: u8,
};

pub const xcb_destroy_notify_event_t = extern struct {
    response_type: u8,
    pad0: u8,
    sequence: u16,
    event: xcb_window_t,
    window: xcb_window_t,
};

pub const MotifHints = extern struct {
    flags: u32,
    functions: u32,
    decorations: u32,
    input_mode: i32,
    status: u32,
};

pub const XCB_CONN_ERROR = 1;
pub const XCB_CONN_CLOSED_EXT_NOTSUPPORTED = 2;
pub const XCB_CONN_CLOSED_MEM_INSUFFICIENT = 3;
pub const XCB_CONN_CLOSED_REQ_LEN_EXCEED = 4;
pub const XCB_CONN_CLOSED_PARSE_ERR = 5;
pub const XCB_CONN_CLOSED_INVALID_SCREEN = 6;
pub const XCB_CONN_CLOSED_FDPASSING_FAILED = 7;

pub const XCB_COPY_FROM_PARENT = 0;
pub const XCB_WINDOW_CLASS_INPUT_OUTPUT = 1;

pub const XCB_IMAGE_FORMAT_Z_PIXMAP = 2;

pub const XCB_PROP_MODE_REPLACE = 0;
pub const XCB_PROP_MODE_PREPEND = 1;
pub const XCB_PROP_MODE_APPEND = 2;

pub const STRING = 31;
pub const WM_NAME = 39;
pub const WM_NORMAL_HINTS = 40;
pub const WM_SIZE_HINTS = 41;

pub const XCB_CW_BACKING_STORE = 0x00000040;
pub const XCB_CW_EVENT_MASK = 0x00000800;

pub const XCB_EVENT_MASK_NO_EVENT = 0;
pub const XCB_EVENT_MASK_KEY_PRESS = 1;
pub const XCB_EVENT_MASK_KEY_RELEASE = 2;
pub const XCB_EVENT_MASK_BUTTON_PRESS = 4;
pub const XCB_EVENT_MASK_BUTTON_RELEASE = 8;
pub const XCB_EVENT_MASK_ENTER_WINDOW = 16;
pub const XCB_EVENT_MASK_LEAVE_WINDOW = 32;
pub const XCB_EVENT_MASK_POINTER_MOTION = 64;
pub const XCB_EVENT_MASK_POINTER_MOTION_HINT = 128;
pub const XCB_EVENT_MASK_BUTTON_1_MOTION = 256;
pub const XCB_EVENT_MASK_BUTTON_2_MOTION = 512;
pub const XCB_EVENT_MASK_BUTTON_3_MOTION = 1024;
pub const XCB_EVENT_MASK_BUTTON_4_MOTION = 2048;
pub const XCB_EVENT_MASK_BUTTON_5_MOTION = 4096;
pub const XCB_EVENT_MASK_BUTTON_MOTION = 8192;
pub const XCB_EVENT_MASK_KEYMAP_STATE = 16384;
pub const XCB_EVENT_MASK_EXPOSURE = 32768;
pub const XCB_EVENT_MASK_VISIBILITY_CHANGE = 65536;
pub const XCB_EVENT_MASK_STRUCTURE_NOTIFY = 131072;
pub const XCB_EVENT_MASK_RESIZE_REDIRECT = 262144;
pub const XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY = 524288;
pub const XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT = 1048576;
pub const XCB_EVENT_MASK_FOCUS_CHANGE = 2097152;
pub const XCB_EVENT_MASK_PROPERTY_CHANGE = 4194304;
pub const XCB_EVENT_MASK_COLOR_MAP_CHANGE = 8388608;
pub const XCB_EVENT_MASK_OWNER_GRAB_BUTTON = 16777216;

pub const XCB_EXPOSE = 12;
pub const XCB_DESTROY_NOTIFY = 17;
pub const XCB_UNMAP_NOTIFY = 18;
pub const XCB_MAP_NOTIFY = 19;
pub const XCB_MAP_REQUEST = 20;
pub const XCB_REPARENT_NOTIFY = 21;
pub const XCB_CONFIGURE_NOTIFY = 22;

// TODO: link?

const pfn_xcb_connect = fn (display_name: ?[*:0]const u8, screenp: ?*c_int) callconv(.C) *xcb_connection_t;
pub var xcb_connect: pfn_xcb_connect = undefined;
const pfn_xcb_connection_has_error = fn (c: *xcb_connection_t) callconv(.C) c_int;
pub var xcb_connection_has_error: pfn_xcb_connection_has_error = undefined;
const pfn_xcb_disconnect = fn (c: *xcb_connection_t) callconv(.C) void;
pub var xcb_disconnect: pfn_xcb_disconnect = undefined;
const pfn_xcb_generate_id = fn (c: *xcb_connection_t) callconv(.C) u32;
pub var xcb_generate_id: pfn_xcb_generate_id = undefined;
const pfn_xcb_get_setup = fn (c: *xcb_connection_t) callconv(.C) *xcb_setup_t;
pub var xcb_get_setup: pfn_xcb_get_setup = undefined;
const pfn_xcb_setup_roots_iterator = fn (R: *const xcb_setup_t) callconv(.C) xcb_screen_iterator_t;
pub var xcb_setup_roots_iterator: pfn_xcb_setup_roots_iterator = undefined;
const pfn_xcb_screen_next = fn (i: *xcb_screen_iterator_t) callconv(.C) void;
pub var xcb_screen_next: pfn_xcb_screen_next = undefined;
const pfn_xcb_wait_for_event = fn (c: *xcb_connection_t) callconv(.C) ?*xcb_generic_event_t;
pub var xcb_wait_for_event: pfn_xcb_wait_for_event = undefined;
const pfn_xcb_create_window = fn (conn: *xcb_connection_t, depth: u8, wid: xcb_window_t, parent: xcb_window_t, x: u16, y: u16, width: u16, height: u16, border_width: u16, _class: u16, visual: xcb_visualid_t, value_mask: u32, value_list: ?[*]const u32) callconv(.C) xcb_void_cookie_t;
pub var xcb_create_window: pfn_xcb_create_window = undefined;
const pfn_xcb_destroy_window = fn (conn: *xcb_connection_t, window: xcb_window_t) callconv(.C) xcb_void_cookie_t;
pub var xcb_destroy_window: pfn_xcb_destroy_window = undefined;
const pfn_xcb_flush = fn (c: *xcb_connection_t) callconv(.C) c_int;
pub var xcb_flush: pfn_xcb_flush = undefined;
const pfn_xcb_map_window = fn (conn: *xcb_connection_t, window: xcb_window_t) callconv(.C) xcb_void_cookie_t;
pub var xcb_map_window: pfn_xcb_map_window = undefined;
const pfn_xcb_unmap_window = fn (conn: *xcb_connection_t, window: xcb_window_t) callconv(.C) xcb_void_cookie_t;
pub var xcb_unmap_window: pfn_xcb_unmap_window = undefined;
const pfn_xcb_change_property = fn (conn: *xcb_connection_t, mode: u8, window: xcb_window_t, property: xcb_atom_t, type: xcb_atom_t, format: u8, data_len: u32, data: *const c_void) callconv(.C) xcb_void_cookie_t;
pub var xcb_change_property: pfn_xcb_change_property = undefined;
const pfn_xcb_intern_atom = fn (conn: *xcb_connection_t, only_if_exists: u8, name_len: u16, name: [*:0]const u8) callconv(.C) xcb_intern_atom_cookie_t;
pub var xcb_intern_atom: pfn_xcb_intern_atom = undefined;
const pfn_xcb_intern_atom_reply = fn (conn: *xcb_connection_t, cookie: xcb_intern_atom_cookie_t, e: ?**xcb_generic_error_t) callconv(.C) *xcb_intern_atom_reply_t;
pub var xcb_intern_atom_reply: pfn_xcb_intern_atom_reply = undefined;
const pfn_xcb_put_image = fn (conn: *xcb_connection_t, format: u8, drawable: xcb_drawable_t, gc: xcb_gcontext_t, width: u16, height: u16, dst_x: i16, dst_y: i16, left_pad: u8, depth: u8, data_len: u32, data: [*]const u8) callconv(.C) xcb_void_cookie_t;
pub var xcb_put_image: pfn_xcb_put_image = undefined;
const pfn_xcb_create_gc = fn (conn: *xcb_connection_t, cid: xcb_gcontext_t, drawable: xcb_drawable_t, value_mask: u32, value_list: ?[*]const u32) callconv(.C) xcb_void_cookie_t;
pub var xcb_create_gc: pfn_xcb_create_gc = undefined;

pub var xcb: std.DynLib = undefined;
pub fn initXCB() !void {
    xcb = try std.DynLib.openZ("libxcb.so");
    errdefer xcb.close();

    xcb_connect = xcb.lookup(pfn_xcb_connect, "xcb_connect") orelse return error.SymbolNotFound;
    xcb_connection_has_error = xcb.lookup(pfn_xcb_connection_has_error, "xcb_connection_has_error") orelse return error.SymbolNotFound;
    xcb_disconnect = xcb.lookup(pfn_xcb_disconnect, "xcb_disconnect") orelse return error.SymbolNotFound;
    xcb_generate_id = xcb.lookup(pfn_xcb_generate_id, "xcb_generate_id") orelse return error.SymbolNotFound;
    xcb_get_setup = xcb.lookup(pfn_xcb_get_setup, "xcb_get_setup") orelse return error.SymbolNotFound;
    xcb_setup_roots_iterator = xcb.lookup(pfn_xcb_setup_roots_iterator, "xcb_setup_roots_iterator") orelse return error.SymbolNotFound;
    xcb_screen_next = xcb.lookup(pfn_xcb_screen_next, "xcb_screen_next") orelse return error.SymbolNotFound;
    xcb_wait_for_event = xcb.lookup(pfn_xcb_wait_for_event, "xcb_wait_for_event") orelse return error.SymbolNotFound;
    xcb_create_window = xcb.lookup(pfn_xcb_create_window, "xcb_create_window") orelse return error.SymbolNotFound;
    xcb_destroy_window = xcb.lookup(pfn_xcb_destroy_window, "xcb_destroy_window") orelse return error.SymbolNotFound;
    xcb_flush = xcb.lookup(pfn_xcb_flush, "xcb_flush") orelse return error.SymbolNotFound;
    xcb_map_window = xcb.lookup(pfn_xcb_map_window, "xcb_map_window") orelse return error.SymbolNotFound;
    xcb_unmap_window = xcb.lookup(pfn_xcb_unmap_window, "xcb_unmap_window") orelse return error.SymbolNotFound;
    xcb_change_property = xcb.lookup(pfn_xcb_change_property, "xcb_change_property") orelse return error.SymbolNotFound;
    xcb_intern_atom = xcb.lookup(pfn_xcb_intern_atom, "xcb_intern_atom") orelse return error.SymbolNotFound;
    xcb_intern_atom_reply = xcb.lookup(pfn_xcb_intern_atom_reply, "xcb_intern_atom_reply") orelse return error.SymbolNotFound;
    xcb_put_image = xcb.lookup(pfn_xcb_put_image, "xcb_put_image") orelse return error.SymbolNotFound;
    xcb_create_gc = xcb.lookup(pfn_xcb_create_gc, "xcb_create_gc") orelse return error.SymbolNotFound;
}

pub fn deinitXCB() void {
    xcb.close();
}

const pfn_XOpenDisplay = fn (display_name: ?[*:0]const u8) callconv(.C) ?*Display;
pub var XOpenDisplay: pfn_XOpenDisplay = undefined;
const pfn_XCloseDisplay = fn (display: *Display) callconv(.C) c_int;
pub var XCloseDisplay: pfn_XCloseDisplay = undefined;
const pfn_XGetXCBConnection = fn (display: *Display) callconv(.C) *xcb_connection_t;
pub var XGetXCBConnection: pfn_XGetXCBConnection = undefined;

pub var xlib: std.DynLib = undefined;
pub var xlib_xcb: std.DynLib = undefined;
pub fn initXlib() !void {
    xlib = try std.DynLib.openZ("libX11.so");
    errdefer xlib.close();

    xlib_xcb = try std.DynLib.openZ("libX11-xcb.so");
    errdefer xlib_xcb.close();

    XOpenDisplay = xlib.lookup(pfn_XOpenDisplay, "XOpenDisplay") orelse return error.SymbolNotFound;
    XCloseDisplay = xlib.lookup(pfn_XCloseDisplay, "XCloseDisplay") orelse return error.SymbolNotFound;
    XGetXCBConnection = xlib_xcb.lookup(pfn_XGetXCBConnection, "XGetXCBConnection") orelse return error.SymbolNotFound;

    try initXCB();
    errdefer deinitXCB();
}

pub fn deinitXlib() void {
    deinitXCB();
    xlib_xcb.close();
    xlib.close();
}

pub fn xcbConnectionHasError(connection: *xcb_connection_t) !void {
    switch (xcb_connection_has_error(connection)) {
        0 => {},
        XCB_CONN_ERROR => return error.SocketError,
        XCB_CONN_CLOSED_EXT_NOTSUPPORTED => return error.ExtensionUnsupported,
        XCB_CONN_CLOSED_MEM_INSUFFICIENT => return error.OutOfMemory,
        XCB_CONN_CLOSED_REQ_LEN_EXCEED => return error.RequestLengthExceeded,
        XCB_CONN_CLOSED_PARSE_ERR => return error.DisplayStringParsingFailed,
        XCB_CONN_CLOSED_INVALID_SCREEN => return error.InvalidScreen,
        else => return error.UnknownXCBError,
    }
}

pub fn xcbFlush(connection: *xcb_connection_t) !void {
    const ret = xcb_flush(connection);
    if (ret <= 0) return error.XCBFlushFailed;
}
