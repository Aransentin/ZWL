const builtin = @import("builtin");

pub const WINDOW = u32;
pub const PIXMAP = u32;
pub const GCONTEXT = u32;
pub const REGION = u32;
pub const CRTC = u32;
pub const SyncFence = u32;
pub const EventID = u32;
pub const DRAWABLE = extern union {
    window: WINDOW,
    pixmap: PIXMAP,
};
pub const ATOM = u32;
pub const VISUALID = u32;
pub const VISUALTYPE = extern enum(u8) {
    StaticGray = 0,
    GrayScale = 1,
    StaticColor = 2,
    PseudoColor = 3,
    TrueColor = 4,
    DirectColor = 5,
};
pub const COLORMAP = u32;
pub const KEYCODE = u8;

pub const BuiltinAtom = enum(u32) {
    PRIMARY = 1,
    SECONDARY = 2,
    ARC = 3,
    ATOM = 4,
    BITMAP = 5,
    CARDINAL = 6,
    COLORMAP = 7,
    CURSOR = 8,
    INTEGER = 19,
    PIXMAP = 20,
    POINT = 21,
    STRING = 31,
    VISUALID = 32,
    WINDOW = 33,
    WM_COMMAND = 34,
    WM_HINTS = 35,
    WM_CLIENT_MACHINE = 36,
    WM_ICON_NAME = 37,
    WM_ICON_SIZE = 38,
    WM_NAME = 39,
    WM_NORMAL_HINTS = 40,
    WM_SIZE_HINTS = 41,
    WM_ZOOM_HINTS = 42,
    WM_CLASS = 67,
    WM_TRANSIENT_FOR = 68,

    // Todo: more
};

// Setup
pub const SetupRequest = extern struct {
    byte_order: u8 = if (builtin.endian == .Little) 0x6c else 0x42,
    pad0: u8 = 0,
    proto_major: u16 = 11,
    proto_minor: u16 = 0,
    auth_proto_name_len: u16 = 0,
    auth_proto_data_len: u16 = 0,
    pad1: u16 = 0,
};

pub const SetupResponseHeader = extern struct {
    status: u8,
    reason_length: u8,
    protocol_major_version: u16,
    protocol_minor_version: u16,
    length: u16,
};

pub const SetupAccepted = extern struct {
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
    min_keycode: u8,
    max_keycode: u8,
    pad0: [4]u8,
};

pub const PixmapFormat = extern struct {
    depth: u8,
    bits_per_pixel: u8,
    scanline_pad: u8,
    pad0: u8,
    pad1: u32,
};

pub const Screen = extern struct {
    root: WINDOW,
    default_colormap: u32,
    white_pixel: u32,
    black_pixel: u32,
    current_input_masks: u32,
    width_in_pixels: u16,
    height_in_pixels: u16,
    width_in_millimeters: u16,
    height_in_millimeters: u16,
    min_installed_maps: u16,
    max_installed_maps: u16,
    root_visual_id: VISUALID,
    backing_stores: u8,
    save_unders: u8,
    root_depth: u8,
    allowed_depths_len: u8,
};

pub const Depth = extern struct {
    depth: u8,
    pad0: u8,
    visual_count: u16,
    pad1: u32,
};

pub const Visual = extern struct {
    id: VISUALID,
    class: VISUALTYPE,
    bits_per_rgb: u8,
    colormap_entries: u16,
    red_mask: u32,
    green_mask: u32,
    blue_mask: u32,
    pad0: u32,
};

// Events

pub const XEventCode = extern enum(u8) {
    Error = 0,
    Reply = 1,
    KeyPress = 2,
    KeyRelease = 3,
    ButtonPress = 4,
    ButtonRelease = 5,
    MotionNotify = 6,
    EnterNotify = 7,
    LeaveNotify = 8,
    FocusIn = 9,
    FocusOut = 10,
    KeymapNotify = 11,
    Expose = 12,
    GraphicsExposure = 13,
    NoExposure = 14,
    VisibilityNotify = 15,
    CreateNotify = 16,
    DestroyNotify = 17,
    UnmapNotify = 18,
    MapNotify = 19,
    MapRequest = 20,
    ReparentNotify = 21,
    ConfigureNotify = 22,
    ConfigureRequest = 23,
    GravityNotify = 24,
    ResizeRequest = 25,
    CirculateNotify = 26,
    CirculateRequest = 27,
    PropertyNotify = 28,
    SelectionClear = 29,
    SelectionRequest = 30,
    SelectionNotify = 31,
    ColormapNotify = 32,
    ClientMessage = 33,
    MappingNotify = 34,
    GenericEvent = 35,
    _,
};

pub const XErrorCode = extern enum(u8) {
    Request = 1,
    Value = 2,
    Window = 3,
    Pixmap = 4,
    Atom = 5,
    Cursor = 6,
    Font = 7,
    Match = 8,
    Drawable = 9,
    Access = 10,
    Alloc = 11,
    Colormap = 12,
    GContext = 13,
    IDChoice = 14,
    Name = 15,
    Length = 16,
    Implementation = 17,
    _,
};

pub const XEventError = extern struct {
    type: u8,
    code: XErrorCode,
    seqence_number: u16,
    resource_id: u32,
    minor_code: u16,
    major_code: u8,
    pad0: u8,
    pad1: [5]u32,
};

pub const ConfigureNotify = extern struct {
    code: u8,
    pad0: u8,
    seqnum: u16,
    event_window: WINDOW,
    window: WINDOW,
    above_sibling: u32,
    x: u16,
    y: u16,
    width: u16,
    height: u16,
    border_width: u16,
    override_redirect: u8,
    pad1: [5]u8,
};

pub const DestroyNotify = extern struct {
    code: u8,
    pad0: u8,
    seqnum: u16,
    event_window: WINDOW,
    window: WINDOW,
    pad1: [20]u8,
};

pub const Expose = extern struct {
    code: u8,
    pad0: u8,
    seqnum: u16,
    window: WINDOW,
    x: u16,
    y: u16,
    width: u16,
    height: u16,
    pad1: [14]u8,
};

// Requests / Replies

pub const QueryExtensionRequest = extern struct {
    opcode: u8 = 98,
    pad0: u8 = 0,
    length_request: u16,
    length_name: u16,
    pad1: u16 = 0,
    // + name
};

pub const QueryExtensionReply = extern struct {
    opcode: u8,
    pad0: u8,
    seqence_number: u16,
    reply_length: u32,
    present: u8,
    major_opcode: u8,
    first_event: u8,
    first_error: u8,
    pad1: [20]u8,
};

pub const CreateWindow = extern struct {
    opcode: u8 = 1,
    depth: u8,
    request_length: u16,
    id: WINDOW,
    parent: WINDOW,
    x: u16,
    y: u16,
    width: u16,
    height: u16,
    border_width: u16 = 0,
    class: u16 = 1,
    visual: VISUALID,
    mask: u32,
};

pub const CWBackgroundPixmap: u32 = 0x00000001;
pub const CWBackgroundPixel: u32 = 0x00000002;
pub const CWBorderPixmap: u32 = 0x00000004;
pub const CWBorderPixel: u32 = 0x00000008;
pub const CWBitGravity: u32 = 0x00000010;
pub const CWWinGravity: u32 = 0x00000020;
pub const CWBackingStores: u32 = 0x00000040;
pub const CWBackingPlanes: u32 = 0x00000080;
pub const CWBackingPixel: u32 = 0x00000100;
pub const CWOverrideRedirect: u32 = 0x00000200;
pub const CWSaveUnder: u32 = 0x00000400;
pub const CWEventMask: u32 = 0x00000800;
pub const CWDoNotPropagateMask: u32 = 0x00001000;
pub const CWColormap: u32 = 0x00002000;
pub const CWCursor: u32 = 0x00004000;

pub const EventKeyPress: u32 = 0x00000001;
pub const EventKeyRelease: u32 = 0x00000002;
pub const EventButtonPress: u32 = 0x00000004;
pub const EventButtonRelease: u32 = 0x00000008;
pub const EventEnterWindow: u32 = 0x00000010;
pub const EventLeaveWindow: u32 = 0x00000020;
pub const EventPointerMotion: u32 = 0x00000040;
pub const EventPointerMotionHint: u32 = 0x00000080;
pub const EventButton1Motion: u32 = 0x00000100;
pub const EventButton2Motion: u32 = 0x00000200;
pub const EventButton3Motion: u32 = 0x00000400;
pub const EventButton4Motion: u32 = 0x00000800;
pub const EventButton5Motion: u32 = 0x00001000;
pub const EventButtonMotion: u32 = 0x00002000;
pub const EventKeymapState: u32 = 0x00004000;
pub const EventExposure: u32 = 0x00008000;
pub const EventVisibilityChange: u32 = 0x00010000;
pub const EventStructureNotify: u32 = 0x00020000;
pub const EventResizeRedirect: u32 = 0x00040000;
pub const EventSubstructureNotify: u32 = 0x00080000;
pub const EventSubstructureRedirect: u32 = 0x00100000;
pub const EventFocusChange: u32 = 0x00200000;
pub const EventPropertyChange: u32 = 0x00400000;
pub const EventColormapChange: u32 = 0x00800000;
pub const EventOwnerGrabButton: u32 = 0x01000000;

pub const DestroyWindow = extern struct {
    request_type: u8 = 4,
    pad0: u8 = 0,
    length: u16 = 8 >> 2,
    id: WINDOW,
};

pub const MapWindow = extern struct {
    request_type: u8 = 8,
    pad0: u8 = 0,
    length: u16 = 8 >> 2,
    id: WINDOW,
};

pub const UnmapWindow = extern struct {
    request_type: u8 = 10,
    pad0: u8 = 0,
    length: u16 = 8 >> 2,
    id: WINDOW,
};

pub const ChangeProperty = extern struct {
    request_type: u8 = 18,
    mode: u8 = 0,
    request_length: u16,
    window: WINDOW,
    property: u32,
    property_type: u32,
    format: u8,
    pad0: [3]u8 = [3]u8{ 0, 0, 0 },
    length: u32,
};

pub const DeleteProperty = extern struct {
    request_type: u8 = 19,
    pad0: u8 = 0,
    request_length: u16 = 3,
    window: u32,
    property: u32,
};

pub const SizeHints = extern struct {
    flags: u32 = 0,
    pad0: [4]u32 = [_]u32{0} ** 4,
    min: [2]u32 = [2]u32{ 0, 0 },
    max: [2]u32 = [2]u32{ 0, 0 },
    inc: [2]u32 = [2]u32{ 0, 0 },
    aspect_min: [2]u32 = [2]u32{ 0, 0 },
    aspect_max: [2]u32 = [2]u32{ 0, 0 },
    base: [2]u32 = [2]u32{ 0, 0 },
    win_gravity: u32 = 0,
};

pub const MotifHints = extern struct {
    flags: u32,
    functions: u32,
    decorations: u32,
    input_mode: i32,
    status: u32,
};

pub const CreatePixmap = extern struct {
    request_type: u8 = 53,
    depth: u8,
    request_length: u16 = 4,
    pid: PIXMAP,
    drawable: DRAWABLE,
    width: u16,
    height: u16,
};

pub const FreePixmap = extern struct {
    request_type: u8 = 54,
    pad0: u8 = 0,
    request_length: u16 = 2,
    pixmap: u32,
};

pub const CreateGC = extern struct {
    request_type: u8 = 55,
    unsued: u8 = 0,
    request_length: u16,
    cid: GCONTEXT,
    drawable: DRAWABLE,
    bitmask: u32,
};

pub const FreeGC = extern struct {
    request_type: u8 = 60,
    unsued: u8 = 0,
    request_length: u16 = 2,
    gc: GCONTEXT,
};

pub const CopyArea = extern struct {
    request_type: u8 = 62,
    pad0: u8 = 0,
    request_length: u16 = 7,
    src_drawable: DRAWABLE,
    dst_drawable: DRAWABLE,
    gc: GCONTEXT,
    src_x: u16,
    src_y: u16,
    dst_x: u16,
    dst_y: u16,
    width: u16,
    height: u16,
};

pub const PutImage = extern struct {
    request_type: u8 = 72,
    format: u8 = 2,
    request_length: u16,
    drawable: DRAWABLE,
    gc: u32,
    width: u16,
    height: u16,
    dst: [2]u16,
    left_pad: u8 = 0,
    depth: u8 = 24,
    pad0: [2]u8 = [2]u8{ 0, 0 },
};

pub const PutImageBig = extern struct {
    request_type: u8 = 72,
    format: u8 = 2,
    request_length_tag: u16 = 0,
    request_length: u32,
    drawable: DRAWABLE,
    gc: u32,
    width: u16,
    height: u16,
    dst: [2]u16,
    left_pad: u8 = 0,
    depth: u8 = 24,
    pad0: [2]u8 = [2]u8{ 0, 0 },
};

pub const InternAtom = extern struct {
    request_type: u8 = 16,
    if_exists: u8,
    request_length: u16,
    name_length: u16,
    pad0: u16 = 0,
};

pub const InternAtomReply = extern struct {
    reply: u8,
    pad0: u8,
    seqence_number: u16,
    reply_length: u32,
    atom: u32,
    pad1: [20]u8,
};

// BigRequests

pub const BigReqEnable = extern struct {
    opcode: u8,
    pad0: u8 = 0,
    length_request: u16 = 1,
};

pub const BigReqEnableReply = extern struct {
    opcode: u8,
    pad0: u8,
    seqence_number: u16,
    reply_length: u32,
    max_req_len: u32,
    pad1: u16,
};

// RandR

pub const RRQueryVersion = extern struct {
    opcode: u8,
    minor: u8 = 0,
    length_request: u16 = 3,
    version_major: u32,
    version_minor: u32,
};

pub const RRQueryVersionReply = extern struct {
    opcode: u8,
    pad0: u8,
    seqence_number: u16,
    reply_length: u32,
    version_major: u32,
    version_minor: u32,
};

pub const RRGetScreenResources = extern struct {
    opcode: u8,
    minor: u8 = 8,
    length_request: u16 = 2,
    window: u32,
};

pub const RRGetScreenResourcesCurrent = extern struct {
    opcode: u8,
    minor: u8 = 25,
    length_request: u16 = 2,
    window: u32,
};

pub const RRGetScreenResourcesReply = extern struct {
    opcode: u8,
    pad0: u8,
    seqence_number: u16,
    reply_length: u32,
    timestamp: u32,
    config_timestamp: u32,
    crtcs: u16,
    outputs: u16,
    modes: u16,
    names: u16,
};

pub const ModeInfo = extern struct {
    id: u32,
    width: u16,
    height: u16,
    dot_clock: u32,
    hsync_start: u16,
    hsync_end: u16,
    htotal: u16,
    hscew: u16,
    vsync_start: u16,
    vsync_end: u16,
    vtotal: u16,
    name_len: u16,
    flags: u32,
};

// XFixes

pub const XFixesQueryVersion = extern struct {
    opcode: u8,
    minor: u8 = 0,
    length_request: u16 = 3,
    version_major: u32,
    version_minor: u32,
};

pub const XFixesQueryVersionReply = extern struct {
    opcode: u8,
    pad0: u8,
    seqence_number: u16,
    reply_length: u32,
    version_major: u32,
    version_minor: u32,
};

pub const CreateRegion = extern struct {
    opcode: u8,
    minor: u8 = 5,
    length_request: u16,
    region: REGION,
};

pub const DestroyRegion = extern struct {
    opcode: u8,
    minor: u8 = 10,
    length_request: u16 = 2,
    region: REGION,
};

pub const SetRegion = extern struct {
    opcode: u8,
    minor: u8 = 11,
    length_request: u16,
    region: REGION,
};

// Present

pub const PresentQueryVersion = extern struct {
    opcode: u8,
    minor: u8 = 0,
    length_request: u16 = 3,
    version_major: u32,
    version_minor: u32,
};

pub const PresentPixmap = extern struct {
    opcode: u8,
    minor: u8 = 1,
    length: u16 = 18,
    window: WINDOW,
    pixmap: PIXMAP,
    serial: u32,
    valid_area: REGION,
    update_area: REGION,
    offset_x: i16 = 0,
    offset_y: i16 = 0,
    crtc: CRTC,
    wait_fence: SyncFence,
    idle_fence: SyncFence,
    options: u32,
    unused: u32 = 0,
    target_msc: u64,
    divisor: u64,
    remainder: u64,
};

pub const PresentNotify = extern struct {
    window: WINDOW,
    serial: u32,
};

pub const PresentSelectInput = extern struct {
    opcode: u8,
    minor: u8 = 3,
    length: u16 = 4,
    event_id: EventID,
    window: WINDOW,
    mask: u32,
};

pub const PresentCompleteNotify = extern struct {
    type: u8 = 35,
    extension: u8,
    seqnum: u16,
    length: u32,
    evtype: u16 = 1,
    kind: u8,
    mode: u8,
    event_id: u32,
    window: u32,
    serial: u32,
    ust: u64,
    msc: u64,
};

// MIT-SHM

pub const MitShmQueryVersion = extern struct {
    opcode: u8,
    minor: u8 = 0,
    length_request: u16 = 1,
};

// Generic Event

pub const GenericEvent = extern struct {
    type: u8 = 35,
    extension: u8,
    seqnum: u16,
    length: u32,
    evtype: u16,
    pad0: u16,
    pad1: [5]u32,
};

/// Event generated when a key/button is pressed/released
/// or when the input device moves
pub const InputDeviceEvent = extern struct {
    type: u8,
    detail: KEYCODE,
    sequence: u16,
    time: u32,
    root: WINDOW,
    event: WINDOW,
    child: WINDOW,
    root_x: i16,
    root_y: i16,
    event_x: i16,
    event_y: i16,
    state: u16,
    same_screen: u8,
    pad: u8,
};
