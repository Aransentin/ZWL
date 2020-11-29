const std = @import("std");
const builtin = @import("builtin");

pub const BITMASK = u32;
pub const WINDOW = u32;
pub const PIXMAP = u32;
pub const CURSOR = u32;
pub const GCONTEXT = u32;
pub const DRAWABLE = extern union { window: WINDOW, pixmap: PIXMAP };
pub const ATOM = u32;
pub const COLORMAP = u32;
pub const VISUALID = u32;
pub const TIMESTAMP = u32;
pub const BOOL = u8;
pub const KEYSYM = u32;
pub const KEYCODE = u8;
pub const BUTTON = u8;
pub const POINT = extern struct { x: i16, y: i16 };
pub const RECTANGLE = extern struct { x: i16, y: i16, width: u16, height: u16 };
pub const REGION = u32;
pub const ShmSeg = u32;
pub const EventID = u32;
pub const CRTC = u32;
pub const SyncFence = u32;

pub const VisualType = extern enum(u8) {
    StaticGray = 0,
    GrayScale = 1,
    StaticColor = 2,
    PseudoColor = 3,
    TrueColor = 4,
    DirectColor = 5,
};

pub const XError = extern enum(u8) {
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

pub const XEvent = extern enum(u8) {
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

pub const XinputEventType = enum(u5) {
    DeviceChanged = 1,
    KeyPress = 2,
    KeyRelease = 3,
    ButtonPress = 4,
    ButtonRelease = 5,
    Motion = 6,
    Enter = 7,
    Leave = 8,
    FocusIn = 9,
    FocusOut = 10,
    HierarchyChanged = 11,
    PropertyEvent = 12,
    RawKeyPress = 13,
    RawKeyRelease = 14,
    RawButtonPress = 15,
    RawButtonRelease = 16,
    RawMotion = 17,
    TouchBegin = 18,
    TouchUpdate = 19,
    TouchEnd = 20,
    TouchOwnership = 21,
    RawTouchBegin = 22,
    RawTouchUpdate = 23,
    RawTouchEnd = 24,
    BarrierHit = 25,
    BarrierLeave = 26,
};

// === Setup ===

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

pub const SetupPixmapFormat = extern struct {
    depth: u8,
    bits_per_pixel: u8,
    scanline_pad: u8,
    pad0: u8,
    pad1: u32,
};

pub const SetupScreen = extern struct {
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

pub const SetupDepth = extern struct {
    depth: u8,
    pad0: u8,
    visual_count: u16,
    pad1: u32,
};

pub const SetupVisual = extern struct {
    id: VISUALID,
    class: VisualType,
    bits_per_rgb: u8,
    colormap_entries: u16,
    red_mask: u32,
    green_mask: u32,
    blue_mask: u32,
    pad0: u32,
};

// === Events ===

pub const ErrorEvent = extern struct {
    type: u8 = 0,
    code: XError,
    seqence_number: u16,
    resource_id: u32,
    minor_code: u16,
    major_code: u8,
    pad0: u8,
    pad1: [5]u32,
};

pub const ExposeEvent = extern struct {
    code: u8 = 12,
    pad0: u8,
    seqence_number: u16,
    window: WINDOW,
    x: u16,
    y: u16,
    width: u16,
    height: u16,
    pad1: [14]u8,
};

pub const DestroyNotify = extern struct {
    code: u8 = 17,
    pad0: u8,
    seqence_number: u16,
    event_window: WINDOW,
    window: WINDOW,
    pad1: [20]u8,
};

pub const ConfigureNotify = extern struct {
    code: u8 = 22,
    pad0: u8,
    seqence_number: u16,
    event_window: WINDOW,
    window: WINDOW,
    above_sibling: WINDOW,
    x: i16,
    y: i16,
    width: u16,
    height: u16,
    border_width: u16,
    override_redirect: BOOL,
    pad1: [5]u8,
};

pub const GenericEvent = extern struct {
    code: u8 = 35,
    extension: u8,
    seqnum: u16,
    length: u32,
    evtype: u16,
    pad0: u16,
    pad1: [5]u32,
};

// === Requests ===

pub const CreateWindow = extern struct {
    opcode: u8 = 1,
    depth: u8,
    request_length: u16,
    id: WINDOW,
    parent: WINDOW,
    x: i16,
    y: i16,
    width: u16,
    height: u16,
    border_width: u16 = 0,
    class: u16 = 1,
    visual: VISUALID,
    mask: u32,
};

pub const CwBackgroundPixmap: u32 = 0x00000001;
pub const CwBackgroundPixel: u32 = 0x00000002;
pub const CwBorderPixmap: u32 = 0x00000004;
pub const CwBorderPixel: u32 = 0x00000008;
pub const CwBitGravity: u32 = 0x00000010;
pub const CwWinGravity: u32 = 0x00000020;
pub const CwBackingStores: u32 = 0x00000040;
pub const CwBackingPlanes: u32 = 0x00000080;
pub const CwBackingPixel: u32 = 0x00000100;
pub const CwOverrideRedirect: u32 = 0x00000200;
pub const CwSaveUnder: u32 = 0x00000400;
pub const CwEventMask: u32 = 0x00000800;
pub const CwDoNotPropagateMask: u32 = 0x00001000;
pub const CwColormap: u32 = 0x00002000;
pub const CwCursor: u32 = 0x00004000;

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

pub const ChangeWindowAttributes = extern struct {
    opcode: u8 = 2,
    pad0: u8 = 0,
    request_length: u16,
    window: WINDOW,
    mask: u32,
};

pub const DestroyWindow = extern struct {
    opcode: u8 = 4,
    pad0: u8 = 0,
    request_length: u16 = 2,
    window: WINDOW,
};

pub const MapWindow = extern struct {
    opcode: u8 = 8,
    pad0: u8 = 0,
    request_length: u16 = 2,
    window: WINDOW,
};

pub const UnmapWindow = extern struct {
    opcode: u8 = 10,
    pad0: u8 = 0,
    request_length: u16 = 2,
    window: WINDOW,
};

pub const ConfigureWindow = extern struct {
    opcode: u8 = 12,
    pad0: u8 = 0,
    request_length: u16,
    window: WINDOW,
    mask: u16,
    pad1: u16 = 0,
};

pub const InternAtom = extern struct {
    opcode: u8 = 16,
    only_if_exists: u8,
    request_length: u16,
    length_of_name: u16,
    pad0: u16 = 0,
};

pub const InternAtomReply = extern struct {
    reply: u8,
    pad0: u8,
    seqence_number: u16,
    reply_length: u32,
    atom: ATOM,
    pad1: [20]u8,
};

pub const ChangeProperty = extern struct {
    opcode: u8 = 18,
    mode: u8 = 0,
    request_length: u16,
    window: WINDOW,
    property: ATOM,
    property_type: ATOM,
    format: u8,
    pad0: [3]u8 = [3]u8{ 0, 0, 0 },
    length: u32,
};

pub const DeleteProperty = extern struct {
    opcode: u8 = 19,
    pad0: u8 = 0,
    request_length: u16 = 3,
    window: WINDOW,
    property: ATOM,
};

pub const SendEvent = extern struct {
    opcode: u8 = 25,
    propagate: BOOL,
    request_length: u16 = 11,
    destination: WINDOW,
    mask: u32,
    event: [32]u8,
};

pub const CreatePixmap = extern struct {
    opcode: u8 = 53,
    depth: u8,
    request_length: u16 = 4,
    pid: PIXMAP,
    drawable: DRAWABLE,
    width: u16,
    height: u16,
};

pub const FreePixmap = extern struct {
    opcode: u8 = 54,
    pad0: u8 = 0,
    request_length: u16 = 2,
    pixmap: PIXMAP,
};

pub const CreateGC = extern struct {
    opcode: u8 = 55,
    pad0: u8 = 0,
    request_length: u16,
    cid: GCONTEXT,
    drawable: DRAWABLE,
    bitmask: u32,
};

pub const ChangeGC = extern struct {
    opcode: u8 = 56,
    pad0: u8 = 0,
    request_length: u16,
    cid: GCONTEXT,
    bitmask: u32,
};

pub const FreeGC = extern struct {
    opcode: u8 = 60,
    pad0: u8 = 0,
    request_length: u16 = 2,
    gc: GCONTEXT,
};

pub const PutImageBig = extern struct {
    opcode: u8 = 72,
    format: u8 = 2,
    request_length_tag: u16 = 0,
    request_length: u32,
    drawable: DRAWABLE,
    gc: GCONTEXT,
    width: u16,
    height: u16,
    dst_x: i16,
    dst_y: i16,
    left_pad: u8 = 0,
    depth: u8,
    pad0: [2]u8 = [2]u8{ 0, 0 },
};

pub const CreateColormap = extern struct {
    opcode: u8 = 78,
    alloc: u8 = 0,
    request_length: u16 = 4,
    mid: COLORMAP,
    window: WINDOW,
    visual: VISUALID,
};

pub const FreeColormap = extern struct {
    opcode: u8 = 79,
    pad0: u8 = 0,
    request_length: u16 = 2,
    cmap: COLORMAP,
};

pub const QueryExtension = extern struct {
    opcode: u8 = 98,
    pad0: u8 = 0,
    request_length: u16,
    length_of_name: u16,
    pad1: u16 = 0,
    // name
};

pub const QueryExtensionReply = extern struct {
    reply: u8,
    pad0: u8,
    seqence_number: u16,
    reply_length: u32,
    present: u8,
    major_opcode: u8,
    first_event: u8,
    first_error: u8,
    pad1: [20]u8,
};

// === Extensions ===

pub const XFixesQueryVersion = extern struct {
    opcode: u8,
    minor: u8 = 0,
    request_length: u16 = 3,
    version_major: u32,
    version_minor: u32,
};

pub const CreateRegion = extern struct {
    opcode: u8,
    minor: u8 = 5,
    request_length: u16,
    region: REGION,
};

pub const DestroyRegion = extern struct {
    opcode: u8,
    minor: u8 = 10,
    request_length: u16 = 2,
    region: REGION,
};

pub const SetRegion = extern struct {
    opcode: u8,
    minor: u8 = 11,
    request_length: u16,
    region: REGION,
};

pub const BigReqEnable = extern struct {
    opcode: u8,
    pad0: u8 = 0,
    request_length: u16 = 1,
};

pub const GEQueryVersion = extern struct {
    opcode: u8,
    minor: u8 = 0,
    request_length: u16 = 2,
    version_major: u16,
    version_minor: u16,
};

pub const PresentQueryVersion = extern struct {
    opcode: u8,
    minor: u8 = 0,
    request_length: u16 = 3,
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

pub const PresentSelectInput = extern struct {
    opcode: u8,
    minor: u8 = 3,
    length: u16 = 4,
    event_id: EventID,
    window: WINDOW,
    mask: u32,
};

pub const PresentCompleteNotify = extern struct {
    XGE: u8 = 35,
    extension: u8,
    sequence_number: u16,
    length: u32 = 2,
    evtype: u16 = 1,
    kind: u8,
    mode: u8,
    event_id: u32,
    window: u32,
    serial: u32,
    ust: u64,
    msc: u64,
};

pub const PresentIdleNotify = extern struct {
    XGE: u8 = 35,
    extension: u8,
    sequence_number: u16,
    length: u32 = 0,
    evtype: u16 = 2,
    pad0: u16,
    event_id: u32,
    window: WINDOW,
    serial: u32,
    pixmap: PIXMAP,
    idle_fence: SyncFence,
};

pub const ShmQueryVersion = extern struct {
    opcode: u8,
    minor: u8 = 0,
    request_length: u16 = 1,
};

pub const ShmCreatePixmap = extern struct {
    opcode: u8,
    minor: u8 = 5,
    length: u16 = 7,
    pixmap: PIXMAP,
    drawable: DRAWABLE,
    width: u16,
    height: u16,
    depth: u8,
    pad0: u8 = 0,
    pad1: u8 = 0,
    pad2: u8 = 0,
    shm_segment: ShmSeg,
    offset: u32,
};

pub const ShmAttachFd = extern struct {
    opcode: u8,
    minor: u8 = 6,
    request_length: u16 = 3,
    shmseg: u32,
    readOnly: BOOL,
    pad0: u8 = 0,
    pad1: u16 = 0,
};

pub const XISelectEvents = extern struct {
    opcode: u8,
    minor: u8 = 46,
    request_length: u16,
    window: WINDOW,
    num_masks: u16,
    pad0: u16,
};

pub const XIQueryVersion = extern struct {
    opcode: u8,
    minor: u8 = 47,
    request_length: u16 = 2,
    version_major: u16,
    version_minor: u16,
};

pub const XIEventMask = extern struct {
    device_id: u16,
    mask_len: u16,
};

pub const XIKeyPress = extern struct {
    code: u8 = 35,
    extension: u8,
    seqnum: u16,
    length: u32,
    evtype: u16,
    device_id: u16,
    timestamp: u32,
    detail: u32,
    root: WINDOW,
    event: WINDOW,
    child: WINDOW,
    root_x0: u16,
    root_x1: u16,
    root_y0: u16,
    root_y1: u16,
    event_x0: u16,
    event_x1: u16,
    event_y0: u16,
    event_y1: u16,
    buttons_len: u16,
    valuators_len: u16,
    source_id: u16,
    pad0: u16,
    flags: u32,
    mods_base: u32,
    mods_latched: u32,
    mods_locked: u32,
    mods_effective: u32,
    group_base: u8,
    group_latched: u8,
    group_locked: u8,
    group_effective: u8,
};
