// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
usingnamespace @import("bits.zig");
const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const windows = @import("../windows.zig").windows;
const unexpectedError = std.os.windows.unexpectedError;
const GetLastError = windows.kernel32.GetLastError;
const SetLastError = windows.kernel32.SetLastError;

fn selectSymbol(comptime function_static: anytype, function_dynamic: @TypeOf(function_static), comptime os: std.Target.Os.WindowsVersion) @TypeOf(function_static) {
    comptime {
        const sym_ok = builtin.Target.current.os.isAtLeast(.windows, os);
        if (sym_ok == true) return function_static;
        if (sym_ok == null) return function_dynamic;
        if (sym_ok == false) @compileError("Target OS range does not support function, at least " ++ @tagName(os) ++ " is required");
    }
}

// === Messages ===

pub const WNDPROC = fn (hwnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(WINAPI) LRESULT;

pub const MSG = extern struct {
    hWnd: ?HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
    lPrivate: DWORD,
};

pub const CREATESTRUCTW = extern struct {
    lpCreateParams: LPVOID,
    hInstance: HINSTANCE,
    hMenu: ?HMENU,
    hwndParent: ?HWND,
    cy: c_int,
    cx: c_int,
    y: c_int,
    x: c_int,
    style: LONG,
    lpszName: LPCWSTR,
    lpszClass: LPCWSTR,
    dwExStyle: DWORD,
};

pub const WM = extern enum(u32) {
    pub const WININICHANGE = @This().SETTINGCHANGE;

    NULL = 0x0000,
    CREATE = 0x0001,
    DESTROY = 0x0002,
    MOVE = 0x0003,
    SIZE = 0x0005,
    ACTIVATE = 0x0006,
    SETFOCUS = 0x0007,
    KILLFOCUS = 0x0008,
    ENABLE = 0x000A,
    SETREDRAW = 0x000B,
    SETTEXT = 0x000C,
    GETTEXT = 0x000D,
    GETTEXTLENGTH = 0x000E,
    PAINT = 0x000F,
    CLOSE = 0x0010,
    QUERYENDSESSION = 0x0011,
    QUERYOPEN = 0x0013,
    ENDSESSION = 0x0016,
    QUIT = 0x0012,
    ERASEBKGND = 0x0014,
    SYSCOLORCHANGE = 0x0015,
    SHOWWINDOW = 0x0018,
    SETTINGCHANGE = 0x001A,
    DEVMODECHANGE = 0x001B,
    ACTIVATEAPP = 0x001C,
    FONTCHANGE = 0x001D,
    TIMECHANGE = 0x001E,
    CANCELMODE = 0x001F,
    SETCURSOR = 0x0020,
    MOUSEACTIVATE = 0x0021,
    CHILDACTIVATE = 0x0022,
    QUEUESYNC = 0x0023,
    GETMINMAXINFO = 0x0024,
    PAINTICON = 0x0026,
    ICONERASEBKGND = 0x0027,
    NEXTDLGCTL = 0x0028,
    SPOOLERSTATUS = 0x002A,
    DRAWITEM = 0x002B,
    MEASUREITEM = 0x002C,
    DELETEITEM = 0x002D,
    VKEYTOITEM = 0x002E,
    CHARTOITEM = 0x002F,
    SETFONT = 0x0030,
    GETFONT = 0x0031,
    SETHOTKEY = 0x0032,
    GETHOTKEY = 0x0033,
    QUERYDRAGICON = 0x0037,
    COMPAREITEM = 0x0039,
    GETOBJECT = 0x003D,
    COMPACTING = 0x0041,
    COMMNOTIFY = 0x0044,
    WINDOWPOSCHANGING = 0x0046,
    WINDOWPOSCHANGED = 0x0047,
    POWER = 0x0048,
    COPYDATA = 0x004A,
    CANCELJOURNAL = 0x004B,
    NOTIFY = 0x004E,
    INPUTLANGCHANGEREQUEST = 0x0050,
    INPUTLANGCHANGE = 0x0051,
    TCARD = 0x0052,
    HELP = 0x0053,
    USERCHANGED = 0x0054,
    NOTIFYFORMAT = 0x0055,
    CONTEXTMENU = 0x007B,
    STYLECHANGING = 0x007C,
    STYLECHANGED = 0x007D,
    DISPLAYCHANGE = 0x007E,
    GETICON = 0x007F,
    SETICON = 0x0080,
    NCCREATE = 0x0081,
    NCDESTROY = 0x0082,
    NCCALCSIZE = 0x0083,
    NCHITTEST = 0x0084,
    NCPAINT = 0x0085,
    NCACTIVATE = 0x0086,
    GETDLGCODE = 0x0087,
    SYNCPAINT = 0x0088,
    NCMOUSEMOVE = 0x00A0,
    NCLBUTTONDOWN = 0x00A1,
    NCLBUTTONUP = 0x00A2,
    NCLBUTTONDBLCLK = 0x00A3,
    NCRBUTTONDOWN = 0x00A4,
    NCRBUTTONUP = 0x00A5,
    NCRBUTTONDBLCLK = 0x00A6,
    NCMBUTTONDOWN = 0x00A7,
    NCMBUTTONUP = 0x00A8,
    NCMBUTTONDBLCLK = 0x00A9,
    NCXBUTTONDOWN = 0x00AB,
    NCXBUTTONUP = 0x00AC,
    NCXBUTTONDBLCLK = 0x00AD,
    INPUT_DEVICE_CHANGE = 0x00fe,
    INPUT = 0x00FF,
    KEYFIRST = 0x0100,
    KEYDOWN = 0x0100,
    KEYUP = 0x0101,
    CHAR = 0x0102,
    DEADCHAR = 0x0103,
    SYSKEYDOWN = 0x0104,
    SYSKEYUP = 0x0105,
    SYSCHAR = 0x0106,
    SYSDEADCHAR = 0x0107,
    // Depends on windows version!
    // UNICHAR = 0x0109,
    // KEYLAST = 0x0109,
    // KEYLAST = 0x0108,
    IME_STARTCOMPOSITION = 0x010D,
    IME_ENDCOMPOSITION = 0x010E,
    IME_COMPOSITION = 0x010F,
    IME_KEYLAST = 0x010F,
    INITDIALOG = 0x0110,
    COMMAND = 0x0111,
    SYSCOMMAND = 0x0112,
    TIMER = 0x0113,
    HSCROLL = 0x0114,
    VSCROLL = 0x0115,
    INITMENU = 0x0116,
    INITMENUPOPUP = 0x0117,
    MENUSELECT = 0x011F,
    GESTURE = 0x0119,
    GESTURENOTIFY = 0x011A,
    MENUCHAR = 0x0120,
    ENTERIDLE = 0x0121,
    MENURBUTTONUP = 0x0122,
    MENUDRAG = 0x0123,
    MENUGETOBJECT = 0x0124,
    UNINITMENUPOPUP = 0x0125,
    MENUCOMMAND = 0x0126,
    CHANGEUISTATE = 0x0127,
    UPDATEUISTATE = 0x0128,
    QUERYUISTATE = 0x0129,
    CTLCOLORMSGBOX = 0x0132,
    CTLCOLOREDIT = 0x0133,
    CTLCOLORLISTBOX = 0x0134,
    CTLCOLORBTN = 0x0135,
    CTLCOLORDLG = 0x0136,
    CTLCOLORSCROLLBAR = 0x0137,
    CTLCOLORSTATIC = 0x0138,
    MOUSEFIRST = 0x0200,
    MOUSEMOVE = 0x0200,
    LBUTTONDOWN = 0x0201,
    LBUTTONUP = 0x0202,
    LBUTTONDBLCLK = 0x0203,
    RBUTTONDOWN = 0x0204,
    RBUTTONUP = 0x0205,
    RBUTTONDBLCLK = 0x0206,
    MBUTTONDOWN = 0x0207,
    MBUTTONUP = 0x0208,
    MBUTTONDBLCLK = 0x0209,
    MOUSEWHEEL = 0x020A,
    XBUTTONDOWN = 0x020B,
    XBUTTONUP = 0x020C,
    XBUTTONDBLCLK = 0x020D,
    MOUSEHWHEEL = 0x020e,
    // MOUSELAST = 0x020e,
    // MOUSELAST = 0x020d,
    // MOUSELAST = 0x020a,
    // MOUSELAST = 0x0209,
    PARENTNOTIFY = 0x0210,
    ENTERMENULOOP = 0x0211,
    EXITMENULOOP = 0x0212,
    NEXTMENU = 0x0213,
    SIZING = 0x0214,
    CAPTURECHANGED = 0x0215,
    MOVING = 0x0216,
    POWERBROADCAST = 0x0218,
    DEVICECHANGE = 0x0219,
    MDICREATE = 0x0220,
    MDIDESTROY = 0x0221,
    MDIACTIVATE = 0x0222,
    MDIRESTORE = 0x0223,
    MDINEXT = 0x0224,
    MDIMAXIMIZE = 0x0225,
    MDITILE = 0x0226,
    MDICASCADE = 0x0227,
    MDIICONARRANGE = 0x0228,
    MDIGETACTIVE = 0x0229,
    MDISETMENU = 0x0230,
    ENTERSIZEMOVE = 0x0231,
    EXITSIZEMOVE = 0x0232,
    DROPFILES = 0x0233,
    MDIREFRESHMENU = 0x0234,
    POINTERDEVICECHANGE = 0x238,
    POINTERDEVICEINRANGE = 0x239,
    POINTERDEVICEOUTOFRANGE = 0x23a,
    TOUCH = 0x0240,
    NCPOINTERUPDATE = 0x0241,
    NCPOINTERDOWN = 0x0242,
    NCPOINTERUP = 0x0243,
    POINTERUPDATE = 0x0245,
    POINTERDOWN = 0x0246,
    POINTERUP = 0x0247,
    POINTERENTER = 0x0249,
    POINTERLEAVE = 0x024a,
    POINTERACTIVATE = 0x024b,
    POINTERCAPTURECHANGED = 0x024c,
    TOUCHHITTESTING = 0x024d,
    POINTERWHEEL = 0x024e,
    POINTERHWHEEL = 0x024f,
    POINTERROUTEDTO = 0x0251,
    POINTERROUTEDAWAY = 0x0252,
    POINTERROUTEDRELEASED = 0x0253,
    IME_SETCONTEXT = 0x0281,
    IME_NOTIFY = 0x0282,
    IME_CONTROL = 0x0283,
    IME_COMPOSITIONFULL = 0x0284,
    IME_SELECT = 0x0285,
    IME_CHAR = 0x0286,
    IME_REQUEST = 0x0288,
    IME_KEYDOWN = 0x0290,
    IME_KEYUP = 0x0291,
    MOUSEHOVER = 0x02A1,
    MOUSELEAVE = 0x02A3,
    NCMOUSEHOVER = 0x02A0,
    NCMOUSELEAVE = 0x02A2,
    WTSSESSION_CHANGE = 0x02B1,
    TABLET_FIRST = 0x02c0,
    TABLET_LAST = 0x02df,
    DPICHANGED = 0x02e0,
    DPICHANGED_BEFOREPARENT = 0x02e2,
    DPICHANGED_AFTERPARENT = 0x02e3,
    GETDPISCALEDSIZE = 0x02e4,
    CUT = 0x0300,
    COPY = 0x0301,
    PASTE = 0x0302,
    CLEAR = 0x0303,
    UNDO = 0x0304,
    RENDERFORMAT = 0x0305,
    RENDERALLFORMATS = 0x0306,
    DESTROYCLIPBOARD = 0x0307,
    DRAWCLIPBOARD = 0x0308,
    PAINTCLIPBOARD = 0x0309,
    VSCROLLCLIPBOARD = 0x030A,
    SIZECLIPBOARD = 0x030B,
    ASKCBFORMATNAME = 0x030C,
    CHANGECBCHAIN = 0x030D,
    HSCROLLCLIPBOARD = 0x030E,
    QUERYNEWPALETTE = 0x030F,
    PALETTEISCHANGING = 0x0310,
    PALETTECHANGED = 0x0311,
    HOTKEY = 0x0312,
    PRINT = 0x0317,
    PRINTCLIENT = 0x0318,
    APPCOMMAND = 0x0319,
    THEMECHANGED = 0x031A,
    CLIPBOARDUPDATE = 0x031d,
    DWMCOMPOSITIONCHANGED = 0x031e,
    DWMNCRENDERINGCHANGED = 0x031f,
    DWMCOLORIZATIONCOLORCHANGED = 0x0320,
    DWMWINDOWMAXIMIZEDCHANGE = 0x0321,
    DWMSENDICONICTHUMBNAIL = 0x0323,
    DWMSENDICONICLIVEPREVIEWBITMAP = 0x0326,
    GETTITLEBARINFOEX = 0x033f,
    HANDHELDFIRST = 0x0358,
    HANDHELDLAST = 0x035F,
    AFXFIRST = 0x0360,
    AFXLAST = 0x037F,
    PENWINFIRST = 0x0380,
    PENWINLAST = 0x038F,
    APP = 0x8000,
    USER = 0x0400,
    _,
};

pub extern "user32" fn GetMessageA(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT) callconv(WINAPI) BOOL;
pub fn getMessageA(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: u32, wMsgFilterMax: u32) !void {
    const r = GetMessageA(lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax);
    if (r == 0) return error.Quit;
    if (r != -1) return;
    switch (GetLastError()) {
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}

pub extern "user32" fn GetMessageW(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT) callconv(WINAPI) BOOL;
pub var pfnGetMessageW: @TypeOf(GetMessageW) = undefined;
pub fn getMessageW(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: u32, wMsgFilterMax: u32) !void {
    const function = selectSymbol(GetMessageW, pfnGetMessageW, .win2k);

    const r = function(lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax);
    if (r == 0) return error.Quit;
    if (r != -1) return;
    switch (GetLastError()) {
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}

pub const PM_NOREMOVE = 0x0000;
pub const PM_REMOVE = 0x0001;
pub const PM_NOYIELD = 0x0002;

pub extern "user32" fn PeekMessageA(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT, wRemoveMsg: UINT) callconv(WINAPI) BOOL;
pub fn peekMessageA(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: u32, wMsgFilterMax: u32, wRemoveMsg: u32) !bool {
    const r = PeekMessageA(lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax, wRemoveMsg);
    if (r == 0) return false;
    if (r != -1) return true;
    switch (GetLastError()) {
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}

pub extern "user32" fn PeekMessageW(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT, wRemoveMsg: UINT) callconv(WINAPI) BOOL;
pub var pfnPeekMessageW: @TypeOf(PeekMessageW) = undefined;
pub fn peekMessageW(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: u32, wMsgFilterMax: u32, wRemoveMsg: u32) !bool {
    const function = selectSymbol(PeekMessageW, pfnPeekMessageW, .win2k);

    const r = function(lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax, wRemoveMsg);
    if (r == 0) return false;
    if (r != -1) return true;
    switch (GetLastError()) {
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}

pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(WINAPI) BOOL;
pub fn translateMessage(lpMsg: *const MSG) bool {
    return if (TranslateMessage(lpMsg) == 0) false else true;
}

pub extern "user32" fn DispatchMessageA(lpMsg: *const MSG) callconv(WINAPI) LRESULT;
pub fn dispatchMessageA(lpMsg: *const MSG) LRESULT {
    return DispatchMessageA(lpMsg);
}

pub extern "user32" fn DispatchMessageW(lpMsg: *const MSG) callconv(WINAPI) LRESULT;
pub var pfnDispatchMessageW: @TypeOf(DispatchMessageW) = undefined;
pub fn dispatchMessageW(lpMsg: *const MSG) LRESULT {
    const function = selectSymbol(DispatchMessageW, pfnDispatchMessageW, .win2k);
    return function(lpMsg);
}

pub extern "user32" fn PostQuitMessage(nExitCode: i32) callconv(WINAPI) void;
pub fn postQuitMessage(nExitCode: i32) void {
    PostQuitMessage(nExitCode);
}

pub extern "user32" fn DefWindowProcA(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(WINAPI) LRESULT;
pub fn defWindowProcA(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) LRESULT {
    return DefWindowProcA(hWnd, Msg, wParam, lParam);
}

pub extern "user32" fn DefWindowProcW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(WINAPI) LRESULT;
pub var pfnDefWindowProcW: @TypeOf(DefWindowProcW) = undefined;
pub fn defWindowProcW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) LRESULT {
    const function = selectSymbol(DefWindowProcW, pfnDefWindowProcW, .win2k);
    return function(hWnd, Msg, wParam, lParam);
}

// === Windows ===

pub const CS_VREDRAW = 0x0001;
pub const CS_HREDRAW = 0x0002;
pub const CS_DBLCLKS = 0x0008;
pub const CS_OWNDC = 0x0020;
pub const CS_CLASSDC = 0x0040;
pub const CS_PARENTDC = 0x0080;
pub const CS_NOCLOSE = 0x0200;
pub const CS_SAVEBITS = 0x0800;
pub const CS_BYTEALIGNCLIENT = 0x1000;
pub const CS_BYTEALIGNWINDOW = 0x2000;
pub const CS_GLOBALCLASS = 0x4000;

pub const WNDCLASSEXA = extern struct {
    cbSize: UINT = @sizeOf(WNDCLASSEXA),
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32 = 0,
    cbWndExtra: i32 = 0,
    hInstance: HINSTANCE,
    hIcon: ?HICON,
    hCursor: ?HCURSOR,
    hbrBackground: ?HBRUSH,
    lpszMenuName: ?[*:0]const u8,
    lpszClassName: [*:0]const u8,
    hIconSm: ?HICON,
};

pub const WNDCLASSEXW = extern struct {
    cbSize: UINT = @sizeOf(WNDCLASSEXW),
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32 = 0,
    cbWndExtra: i32 = 0,
    hInstance: HINSTANCE,
    hIcon: ?HICON,
    hCursor: ?HCURSOR,
    hbrBackground: ?HBRUSH,
    lpszMenuName: ?[*:0]const u16,
    lpszClassName: [*:0]const u16,
    hIconSm: ?HICON,
};

pub extern "user32" fn RegisterClassExA(*const WNDCLASSEXA) callconv(WINAPI) ATOM;
pub fn registerClassExA(window_class: *const WNDCLASSEXA) !ATOM {
    const atom = RegisterClassExA(window_class);
    if (atom != 0) return atom;
    switch (GetLastError()) {
        .CLASS_ALREADY_EXISTS => return error.AlreadyExists,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}

pub extern "user32" fn RegisterClassExW(*const WNDCLASSEXW) callconv(WINAPI) ATOM;
pub var pfnRegisterClassExW: @TypeOf(RegisterClassExW) = undefined;
pub fn registerClassExW(window_class: *const WNDCLASSEXW) !ATOM {
    const function = selectSymbol(RegisterClassExW, pfnRegisterClassExW, .win2k);
    const atom = function(window_class);
    if (atom != 0) return atom;
    switch (GetLastError()) {
        .CLASS_ALREADY_EXISTS => return error.AlreadyExists,
        .CALL_NOT_IMPLEMENTED => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}

pub extern "user32" fn UnregisterClassA(lpClassName: [*:0]const u8, hInstance: HINSTANCE) callconv(WINAPI) BOOL;
pub fn unregisterClassA(lpClassName: [*:0]const u8, hInstance: HINSTANCE) !void {
    if (UnregisterClassA(lpClassName, hInstance) == 0) {
        switch (GetLastError()) {
            .CLASS_DOES_NOT_EXIST => return error.ClassDoesNotExist,
            else => |err| return unexpectedError(err),
        }
    }
}

pub extern "user32" fn UnregisterClassW(lpClassName: [*:0]const u16, hInstance: HINSTANCE) callconv(WINAPI) BOOL;
pub var pfnUnregisterClassW: @TypeOf(UnregisterClassW) = undefined;
pub fn unregisterClassW(lpClassName: [*:0]const u16, hInstance: HINSTANCE) !void {
    const function = selectSymbol(UnregisterClassW, pfnUnregisterClassW, .win2k);
    if (function(lpClassName, hInstance) == 0) {
        switch (GetLastError()) {
            .CLASS_DOES_NOT_EXIST => return error.ClassDoesNotExist,
            else => |err| return unexpectedError(err),
        }
    }
}

pub const WS_OVERLAPPED = 0x00000000;
pub const WS_POPUP = 0x80000000;
pub const WS_CHILD = 0x40000000;
pub const WS_MINIMIZE = 0x20000000;
pub const WS_VISIBLE = 0x10000000;
pub const WS_DISABLED = 0x08000000;
pub const WS_CLIPSIBLINGS = 0x04000000;
pub const WS_CLIPCHILDREN = 0x02000000;
pub const WS_MAXIMIZE = 0x01000000;
pub const WS_CAPTION = WS_BORDER | WS_DLGFRAME;
pub const WS_BORDER = 0x00800000;
pub const WS_DLGFRAME = 0x00400000;
pub const WS_VSCROLL = 0x00200000;
pub const WS_HSCROLL = 0x00100000;
pub const WS_SYSMENU = 0x00080000;
pub const WS_THICKFRAME = 0x00040000;
pub const WS_GROUP = 0x00020000;
pub const WS_TABSTOP = 0x00010000;
pub const WS_MINIMIZEBOX = 0x00020000;
pub const WS_MAXIMIZEBOX = 0x00010000;
pub const WS_TILED = WS_OVERLAPPED;
pub const WS_ICONIC = WS_MINIMIZE;
pub const WS_SIZEBOX = WS_THICKFRAME;
pub const WS_TILEDWINDOW = WS_OVERLAPPEDWINDOW;
pub const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
pub const WS_POPUPWINDOW = WS_POPUP | WS_BORDER | WS_SYSMENU;
pub const WS_CHILDWINDOW = WS_CHILD;

pub const WS_EX_DLGMODALFRAME = 0x00000001;
pub const WS_EX_NOPARENTNOTIFY = 0x00000004;
pub const WS_EX_TOPMOST = 0x00000008;
pub const WS_EX_ACCEPTFILES = 0x00000010;
pub const WS_EX_TRANSPARENT = 0x00000020;
pub const WS_EX_MDICHILD = 0x00000040;
pub const WS_EX_TOOLWINDOW = 0x00000080;
pub const WS_EX_WINDOWEDGE = 0x00000100;
pub const WS_EX_CLIENTEDGE = 0x00000200;
pub const WS_EX_CONTEXTHELP = 0x00000400;
pub const WS_EX_RIGHT = 0x00001000;
pub const WS_EX_LEFT = 0x00000000;
pub const WS_EX_RTLREADING = 0x00002000;
pub const WS_EX_LTRREADING = 0x00000000;
pub const WS_EX_LEFTSCROLLBAR = 0x00004000;
pub const WS_EX_RIGHTSCROLLBAR = 0x00000000;
pub const WS_EX_CONTROLPARENT = 0x00010000;
pub const WS_EX_STATICEDGE = 0x00020000;
pub const WS_EX_APPWINDOW = 0x00040000;
pub const WS_EX_LAYERED = 0x00080000;
pub const WS_EX_OVERLAPPEDWINDOW = WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE;
pub const WS_EX_PALETTEWINDOW = WS_EX_WINDOWEDGE | WS_EX_TOOLWINDOW | WS_EX_TOPMOST;

pub const CW_USEDEFAULT = @bitCast(i32, @as(u32, 0x80000000));

pub extern "user32" fn CreateWindowExA(dwExStyle: DWORD, lpClassName: [*:0]const u8, lpWindowName: [*:0]const u8, dwStyle: DWORD, X: i32, Y: i32, nWidth: i32, nHeight: i32, hWindParent: ?HWND, hMenu: ?HMENU, hInstance: HINSTANCE, lpParam: ?LPVOID) callconv(WINAPI) ?HWND;
pub fn createWindowExA(dwExStyle: u32, lpClassName: [*:0]const u8, lpWindowName: [*:0]const u8, dwStyle: u32, X: i32, Y: i32, nWidth: i32, nHeight: i32, hWindParent: ?HWND, hMenu: ?HMENU, hInstance: HINSTANCE, lpParam: ?*c_void) !HWND {
    const window = CreateWindowExA(dwExStyle, lpClassName, lpWindowName, dwStyle, X, Y, nWidth, nHeight, hWindParent, hMenu, hInstance, lpParam);
    if (window) |win| return win;

    switch (GetLastError()) {
        .CLASS_DOES_NOT_EXIST => return error.ClassDoesNotExist,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}

pub extern "user32" fn CreateWindowExW(dwExStyle: DWORD, lpClassName: [*:0]const u16, lpWindowName: [*:0]const u16, dwStyle: DWORD, X: i32, Y: i32, nWidth: i32, nHeight: i32, hWindParent: ?HWND, hMenu: ?HMENU, hInstance: HINSTANCE, lpParam: ?LPVOID) callconv(WINAPI) ?HWND;
pub var pfnCreateWindowExW: @TypeOf(RegisterClassExW) = undefined;
pub fn createWindowExW(dwExStyle: u32, lpClassName: [*:0]const u16, lpWindowName: [*:0]const u16, dwStyle: u32, X: i32, Y: i32, nWidth: i32, nHeight: i32, hWindParent: ?HWND, hMenu: ?HMENU, hInstance: HINSTANCE, lpParam: ?*c_void) !HWND {
    const function = selectSymbol(CreateWindowExW, pfnCreateWindowExW, .win2k);
    const window = function(dwExStyle, lpClassName, lpWindowName, dwStyle, X, Y, nWidth, nHeight, hWindParent, hMenu, hInstance, lpParam);
    if (window) |win| return win;

    switch (GetLastError()) {
        .CLASS_DOES_NOT_EXIST => return error.ClassDoesNotExist,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}

pub extern "user32" fn DestroyWindow(hWnd: HWND) callconv(WINAPI) BOOL;
pub fn destroyWindow(hWnd: HWND) !void {
    if (DestroyWindow(hWnd) == 0) {
        switch (GetLastError()) {
            .INVALID_WINDOW_HANDLE => unreachable,
            .INVALID_PARAMETER => unreachable,
            else => |err| return unexpectedError(err),
        }
    }
}

pub const SW_HIDE = 0;
pub const SW_SHOWNORMAL = 1;
pub const SW_NORMAL = 1;
pub const SW_SHOWMINIMIZED = 2;
pub const SW_SHOWMAXIMIZED = 3;
pub const SW_MAXIMIZE = 3;
pub const SW_SHOWNOACTIVATE = 4;
pub const SW_SHOW = 5;
pub const SW_MINIMIZE = 6;
pub const SW_SHOWMINNOACTIVE = 7;
pub const SW_SHOWNA = 8;
pub const SW_RESTORE = 9;
pub const SW_SHOWDEFAULT = 10;
pub const SW_FORCEMINIMIZE = 11;
pub const SW_MAX = 11;

pub extern "user32" fn ShowWindow(hWnd: HWND, nCmdShow: i32) callconv(WINAPI) BOOL;
pub fn showWindow(hWnd: HWND, nCmdShow: i32) bool {
    return (ShowWindow(hWnd, nCmdShow) == TRUE);
}

pub extern "user32" fn UpdateWindow(hWnd: HWND) callconv(WINAPI) BOOL;
pub fn updateWindow(hWnd: HWND) !void {
    if (ShowWindow(hWnd, nCmdShow) == 0) {
        switch (GetLastError()) {
            .INVALID_WINDOW_HANDLE => unreachable,
            .INVALID_PARAMETER => unreachable,
            else => |err| return unexpectedError(err),
        }
    }
}

pub extern "user32" fn AdjustWindowRectEx(lpRect: *RECT, dwStyle: DWORD, bMenu: BOOL, dwExStyle: DWORD) callconv(WINAPI) BOOL;
pub fn adjustWindowRectEx(lpRect: *RECT, dwStyle: u32, bMenu: bool, dwExStyle: u32) !void {
    assert(dwStyle & WS_OVERLAPPED == 0);

    if (AdjustWindowRectEx(lpRect, dwStyle, bMenu, dwExStyle) == 0) {
        switch (GetLastError()) {
            .INVALID_PARAMETER => unreachable,
            else => |err| return unexpectedError(err),
        }
    }
}

pub const GWL_WNDPROC = -4;
pub const GWL_HINSTANCE = -6;
pub const GWL_HWNDPARENT = -8;
pub const GWL_STYLE = -16;
pub const GWL_EXSTYLE = -20;
pub const GWL_USERDATA = -21;
pub const GWL_ID = -12;

pub extern "user32" fn GetWindowLongA(hWnd: HWND, nIndex: i32) callconv(WINAPI) LONG;
pub fn getWindowLongA(hWnd: HWND, nIndex: i32) !i32 {
    const value = GetWindowLongA(hWnd, nIndex);
    if (value != 0) return value;

    switch (GetLastError()) {
        .SUCCESS => return 0,
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}

pub extern "user32" fn GetWindowLongW(hWnd: HWND, nIndex: i32) callconv(WINAPI) LONG;
pub var pfnGetWindowLongW: @TypeOf(GetWindowLongW) = undefined;
pub fn getWindowLongW(hWnd: HWND, nIndex: i32) !i32 {
    const function = selectSymbol(GetWindowLongW, pfnGetWindowLongW, .win2k);

    const value = function(hWnd, nIndex);
    if (value != 0) return value;

    switch (GetLastError()) {
        .SUCCESS => return 0,
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}

pub extern "user32" fn GetWindowLongPtrA(hWnd: HWND, nIndex: i32) callconv(WINAPI) LONG_PTR;
pub fn getWindowLongPtrA(hWnd: HWND, nIndex: i32) !isize {
    // "When compiling for 32-bit Windows, GetWindowLongPtr is defined as a call to the GetWindowLong function."
    // https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getwindowlongptrw
    if (@sizeOf(LONG_PTR) == 4) return getWindowLongA(hWnd, nIndex);

    const value = GetWindowLongPtrA(hWnd, nIndex);
    if (value != 0) return value;

    switch (GetLastError()) {
        .SUCCESS => return 0,
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}

pub extern "user32" fn GetWindowLongPtrW(hWnd: HWND, nIndex: i32) callconv(WINAPI) LONG_PTR;
pub var pfnGetWindowLongPtrW: @TypeOf(GetWindowLongPtrW) = undefined;
pub fn getWindowLongPtrW(hWnd: HWND, nIndex: i32) !isize {
    if (@sizeOf(LONG_PTR) == 4) return getWindowLongW(hWnd, nIndex);
    const function = selectSymbol(GetWindowLongPtrW, pfnGetWindowLongPtrW, .win2k);

    const value = function(hWnd, nIndex);
    if (value != 0) return value;

    switch (GetLastError()) {
        .SUCCESS => return 0,
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}

pub extern "user32" fn SetWindowLongA(hWnd: HWND, nIndex: i32, dwNewLong: LONG) callconv(WINAPI) LONG;
pub fn setWindowLongA(hWnd: HWND, nIndex: i32, dwNewLong: i32) !i32 {
    // [...] you should clear the last error information by calling SetLastError with 0 before calling SetWindowLong.
    // https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowlonga
    SetLastError(.SUCCESS);

    const value = SetWindowLongA(hWnd, nIndex, dwNewLong);
    if (value != 0) return value;

    switch (GetLastError()) {
        .SUCCESS => return 0,
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}

pub extern "user32" fn SetWindowLongW(hWnd: HWND, nIndex: i32, dwNewLong: LONG) callconv(WINAPI) LONG;
pub var pfnSetWindowLongW: @TypeOf(SetWindowLongW) = undefined;
pub fn setWindowLongW(hWnd: HWND, nIndex: i32, dwNewLong: i32) !i32 {
    const function = selectSymbol(SetWindowLongW, pfnSetWindowLongW, .win2k);

    SetLastError(.SUCCESS);
    const value = function(hWnd, nIndex, dwNewLong);
    if (value != 0) return value;

    switch (GetLastError()) {
        .SUCCESS => return 0,
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}

pub extern "user32" fn SetWindowLongPtrA(hWnd: HWND, nIndex: i32, dwNewLong: LONG_PTR) callconv(WINAPI) LONG_PTR;
pub fn setWindowLongPtrA(hWnd: HWND, nIndex: i32, dwNewLong: isize) !isize {
    // "When compiling for 32-bit Windows, GetWindowLongPtr is defined as a call to the GetWindowLong function."
    // https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getwindowlongptrw
    if (@sizeOf(LONG_PTR) == 4) return setWindowLongA(hWnd, nIndex, dwNewLong);

    SetLastError(.SUCCESS);
    const value = SetWindowLongPtrA(hWnd, nIndex, dwNewLong);
    if (value != 0) return value;

    switch (GetLastError()) {
        .SUCCESS => return 0,
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}

pub extern "user32" fn SetWindowLongPtrW(hWnd: HWND, nIndex: i32, dwNewLong: LONG_PTR) callconv(WINAPI) LONG_PTR;
pub var pfnSetWindowLongPtrW: @TypeOf(SetWindowLongPtrW) = undefined;
pub fn setWindowLongPtrW(hWnd: HWND, nIndex: i32, dwNewLong: isize) !isize {
    if (@sizeOf(LONG_PTR) == 4) return setWindowLongW(hWnd, nIndex, dwNewLong);
    const function = selectSymbol(SetWindowLongPtrW, pfnSetWindowLongPtrW, .win2k);

    SetLastError(.SUCCESS);
    const value = function(hWnd, nIndex, dwNewLong);
    if (value != 0) return value;

    switch (GetLastError()) {
        .SUCCESS => return 0,
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}

pub extern "user32" fn GetDC(hWnd: ?HWND) callconv(WINAPI) ?HDC;
pub fn getDC(hWnd: ?HWND) !HDC {
    const hdc = GetDC(hWnd);
    if (hdc) |h| return h;

    switch (GetLastError()) {
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return std.os.windows.unexpectedError(err),
    }
}

pub extern "user32" fn ReleaseDC(hWnd: ?HWND, hDC: HDC) callconv(WINAPI) i32;
pub fn releaseDC(hWnd: ?HWND, hDC: HDC) bool {
    return if (ReleaseDC(hWnd, hDC) == 1) true else false;
}

// === Modal dialogue boxes ===

pub const MB_OK = 0x00000000;
pub const MB_OKCANCEL = 0x00000001;
pub const MB_ABORTRETRYIGNORE = 0x00000002;
pub const MB_YESNOCANCEL = 0x00000003;
pub const MB_YESNO = 0x00000004;
pub const MB_RETRYCANCEL = 0x00000005;
pub const MB_CANCELTRYCONTINUE = 0x00000006;
pub const MB_ICONHAND = 0x00000010;
pub const MB_ICONQUESTION = 0x00000020;
pub const MB_ICONEXCLAMATION = 0x00000030;
pub const MB_ICONASTERISK = 0x00000040;
pub const MB_USERICON = 0x00000080;
pub const MB_ICONWARNING = MB_ICONEXCLAMATION;
pub const MB_ICONERROR = MB_ICONHAND;
pub const MB_ICONINFORMATION = MB_ICONASTERISK;
pub const MB_ICONSTOP = MB_ICONHAND;
pub const MB_DEFBUTTON1 = 0x00000000;
pub const MB_DEFBUTTON2 = 0x00000100;
pub const MB_DEFBUTTON3 = 0x00000200;
pub const MB_DEFBUTTON4 = 0x00000300;
pub const MB_APPLMODAL = 0x00000000;
pub const MB_SYSTEMMODAL = 0x00001000;
pub const MB_TASKMODAL = 0x00002000;
pub const MB_HELP = 0x00004000;
pub const MB_NOFOCUS = 0x00008000;
pub const MB_SETFOREGROUND = 0x00010000;
pub const MB_DEFAULT_DESKTOP_ONLY = 0x00020000;
pub const MB_TOPMOST = 0x00040000;
pub const MB_RIGHT = 0x00080000;
pub const MB_RTLREADING = 0x00100000;
pub const MB_TYPEMASK = 0x0000000F;
pub const MB_ICONMASK = 0x000000F0;
pub const MB_DEFMASK = 0x00000F00;
pub const MB_MODEMASK = 0x00003000;
pub const MB_MISCMASK = 0x0000C000;

pub const MK_CONTROL = 0x0008;
pub const MK_LBUTTON = 0x0001;
pub const MK_MBUTTON = 0x0010;
pub const MK_RBUTTON = 0x0002;
pub const MK_SHIFT = 0x0004;
pub const MK_XBUTTON1 = 0x0020;
pub const MK_XBUTTON2 = 0x0040;

pub const IDOK = 1;
pub const IDCANCEL = 2;
pub const IDABORT = 3;
pub const IDRETRY = 4;
pub const IDIGNORE = 5;
pub const IDYES = 6;
pub const IDNO = 7;
pub const IDCLOSE = 8;
pub const IDHELP = 9;
pub const IDTRYAGAIN = 10;
pub const IDCONTINUE = 11;

pub extern "user32" fn MessageBoxA(hWnd: ?HWND, lpText: [*:0]const u8, lpCaption: [*:0]const u8, uType: UINT) callconv(WINAPI) i32;
pub fn messageBoxA(hWnd: ?HWND, lpText: [*:0]const u8, lpCaption: [*:0]const u8, uType: u32) !i32 {
    const value = MessageBoxA(hWnd, lpText, lpCaption, uType);
    if (value != 0) return value;
    switch (GetLastError()) {
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}

pub extern "user32" fn MessageBoxW(hWnd: ?HWND, lpText: [*:0]const u16, lpCaption: ?[*:0]const u16, uType: UINT) callconv(WINAPI) i32;
pub var pfnMessageBoxW: @TypeOf(MessageBoxW) = undefined;
pub fn messageBoxW(hWnd: ?HWND, lpText: [*:0]const u16, lpCaption: [*:0]const u16, uType: u32) !i32 {
    const function = selectSymbol(pfnMessageBoxW, MessageBoxW, .win2k);
    const value = function(hWnd, lpText, lpCaption, uType);
    if (value != 0) return value;
    switch (GetLastError()) {
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}

pub const PAINTSTRUCT = extern struct {
    hdc: ?HDC,
    fErase: BOOL,
    rcPaint: RECT,
    fRestore: BOOL,
    fIncUpdate: BOOL,
    rgbReserved: [32]BYTE,
};

pub extern "user32" fn BeginPaint(
    hWnd: HWND,
    lpPaint: *PAINTSTRUCT,
) callconv(WINAPI) ?HDC;

pub extern "user32" fn EndPaint(
    hWnd: HWND,
    lpPaint: *const PAINTSTRUCT,
) callconv(WINAPI) BOOL;

pub extern "user32" fn InvalidateRect(
    hWnd: HWND, // handle to window
    lpRect: ?*const RECT, // rectangle coordinates
    bErase: BOOL, // erase state
) callconv(WINAPI) BOOL;

pub extern "user32" fn GetClientRect(hWnd: ?HWND, lpRect: *RECT) callconv(WINAPI) BOOL;
pub fn getClientRect(hWnd: ?HWND, lpRect: *RECT) !BOOL {
    const value = GetClientRect(hWnd, lpRect);
    if (value != 0) return value;
    switch (GetLastError()) {
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}
