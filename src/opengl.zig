const std = @import("std");

const WINAPI = std.os.windows.WINAPI;

const GLenum = c_uint;
const GLboolean = u8;
const GLbitfield = c_uint;
const GLbyte = i8;
const GLshort = c_short;
const GLint = c_int;
const GLsizei = c_int;
const GLubyte = u8;
const GLushort = c_ushort;
const GLuint = c_uint;
const GLfloat = f32;
const GLclampf = f32;
const GLdouble = f64;
const GLclampd = f64;
const GLvoid = void;

pub extern "opengl32" fn glGetString(
    name: GLenum,
) callconv(WINAPI) [*:0]const u8;

pub const GL_VENDOR = 0x1F00;
pub const GL_RENDERER = 0x1F01;
pub const GL_VERSION = 0x1F02;
pub const GL_EXTENSIONS = 0x1F03;
pub const GL_COLOR_BUFFER_BIT = 0x00004000;

pub const GL_TRUE = 1;
pub const GL_FALSE = 0;

pub extern "opengl32" fn glClear(mask: GLbitfield) callconv(WINAPI) void;
pub extern "opengl32" fn glClearColor(red: GLclampf, green: GLclampf, blue: GLclampf, alpha: GLclampf) callconv(WINAPI) void;
