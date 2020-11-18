// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
usingnamespace @import("bits.zig");

pub extern "kernel32" fn AddVectoredExceptionHandler(First: c_ulong, Handler: ?VECTORED_EXCEPTION_HANDLER) callconv(.Stdcall) ?*c_void;
pub extern "kernel32" fn RemoveVectoredExceptionHandler(Handle: HANDLE) callconv(.Stdcall) c_ulong;

pub extern "kernel32" fn CancelIoEx(hFile: HANDLE, lpOverlapped: LPOVERLAPPED) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn CloseHandle(hObject: HANDLE) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn CreateDirectoryW(lpPathName: [*:0]const u16, lpSecurityAttributes: ?*SECURITY_ATTRIBUTES) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn SetEndOfFile(hFile: HANDLE) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn CreateEventExW(
    lpEventAttributes: ?*SECURITY_ATTRIBUTES,
    lpName: [*:0]const u16,
    dwFlags: DWORD,
    dwDesiredAccess: DWORD,
) callconv(.Stdcall) ?HANDLE;

pub extern "kernel32" fn CreateFileW(
    lpFileName: [*:0]const u16,
    dwDesiredAccess: DWORD,
    dwShareMode: DWORD,
    lpSecurityAttributes: ?LPSECURITY_ATTRIBUTES,
    dwCreationDisposition: DWORD,
    dwFlagsAndAttributes: DWORD,
    hTemplateFile: ?HANDLE,
) callconv(.Stdcall) HANDLE;

pub extern "kernel32" fn CreatePipe(
    hReadPipe: *HANDLE,
    hWritePipe: *HANDLE,
    lpPipeAttributes: *const SECURITY_ATTRIBUTES,
    nSize: DWORD,
) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn CreateProcessW(
    lpApplicationName: ?LPWSTR,
    lpCommandLine: LPWSTR,
    lpProcessAttributes: ?*SECURITY_ATTRIBUTES,
    lpThreadAttributes: ?*SECURITY_ATTRIBUTES,
    bInheritHandles: BOOL,
    dwCreationFlags: DWORD,
    lpEnvironment: ?*c_void,
    lpCurrentDirectory: ?LPWSTR,
    lpStartupInfo: *STARTUPINFOW,
    lpProcessInformation: *PROCESS_INFORMATION,
) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn CreateSymbolicLinkW(lpSymlinkFileName: [*:0]const u16, lpTargetFileName: [*:0]const u16, dwFlags: DWORD) callconv(.Stdcall) BOOLEAN;

pub extern "kernel32" fn CreateIoCompletionPort(FileHandle: HANDLE, ExistingCompletionPort: ?HANDLE, CompletionKey: ULONG_PTR, NumberOfConcurrentThreads: DWORD) callconv(.Stdcall) ?HANDLE;

pub extern "kernel32" fn CreateThread(lpThreadAttributes: ?LPSECURITY_ATTRIBUTES, dwStackSize: SIZE_T, lpStartAddress: LPTHREAD_START_ROUTINE, lpParameter: ?LPVOID, dwCreationFlags: DWORD, lpThreadId: ?LPDWORD) callconv(.Stdcall) ?HANDLE;

pub extern "kernel32" fn DeviceIoControl(
    h: HANDLE,
    dwIoControlCode: DWORD,
    lpInBuffer: ?*const c_void,
    nInBufferSize: DWORD,
    lpOutBuffer: ?LPVOID,
    nOutBufferSize: DWORD,
    lpBytesReturned: ?*DWORD,
    lpOverlapped: ?*OVERLAPPED,
) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn DeleteFileW(lpFileName: [*:0]const u16) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn DuplicateHandle(hSourceProcessHandle: HANDLE, hSourceHandle: HANDLE, hTargetProcessHandle: HANDLE, lpTargetHandle: *HANDLE, dwDesiredAccess: DWORD, bInheritHandle: BOOL, dwOptions: DWORD) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn ExitProcess(exit_code: UINT) callconv(.Stdcall) noreturn;

pub extern "kernel32" fn FindFirstFileW(lpFileName: [*:0]const u16, lpFindFileData: *WIN32_FIND_DATAW) callconv(.Stdcall) HANDLE;
pub extern "kernel32" fn FindClose(hFindFile: HANDLE) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn FindNextFileW(hFindFile: HANDLE, lpFindFileData: *WIN32_FIND_DATAW) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn FormatMessageW(dwFlags: DWORD, lpSource: ?LPVOID, dwMessageId: Win32Error, dwLanguageId: DWORD, lpBuffer: [*]u16, nSize: DWORD, Arguments: ?*va_list) callconv(.Stdcall) DWORD;

pub extern "kernel32" fn FreeEnvironmentStringsW(penv: [*:0]u16) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn GetCommandLineA() callconv(.Stdcall) LPSTR;
pub extern "kernel32" fn GetCommandLineW() callconv(.Stdcall) LPWSTR;

pub extern "kernel32" fn GetConsoleMode(in_hConsoleHandle: HANDLE, out_lpMode: *DWORD) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn GetConsoleScreenBufferInfo(hConsoleOutput: HANDLE, lpConsoleScreenBufferInfo: *CONSOLE_SCREEN_BUFFER_INFO) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn FillConsoleOutputCharacterA(hConsoleOutput: HANDLE, cCharacter: TCHAR, nLength: DWORD, dwWriteCoord: COORD, lpNumberOfCharsWritten: LPDWORD) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn FillConsoleOutputAttribute(hConsoleOutput: HANDLE, wAttribute: WORD, nLength: DWORD, dwWriteCoord: COORD, lpNumberOfAttrsWritten: LPDWORD) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn SetConsoleCursorPosition(hConsoleOutput: HANDLE, dwCursorPosition: COORD) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn GetCurrentDirectoryW(nBufferLength: DWORD, lpBuffer: ?[*]WCHAR) callconv(.Stdcall) DWORD;

pub extern "kernel32" fn GetCurrentThread() callconv(.Stdcall) HANDLE;
pub extern "kernel32" fn GetCurrentThreadId() callconv(.Stdcall) DWORD;

pub extern "kernel32" fn GetCurrentProcess() callconv(.Stdcall) HANDLE;

pub extern "kernel32" fn GetEnvironmentStringsW() callconv(.Stdcall) ?[*:0]u16;

pub extern "kernel32" fn GetEnvironmentVariableW(lpName: LPWSTR, lpBuffer: [*]u16, nSize: DWORD) callconv(.Stdcall) DWORD;

pub extern "kernel32" fn GetExitCodeProcess(hProcess: HANDLE, lpExitCode: *DWORD) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn GetFileSizeEx(hFile: HANDLE, lpFileSize: *LARGE_INTEGER) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn GetFileAttributesW(lpFileName: [*]const WCHAR) callconv(.Stdcall) DWORD;

pub extern "kernel32" fn GetModuleFileNameW(hModule: ?HMODULE, lpFilename: [*]u16, nSize: DWORD) callconv(.Stdcall) DWORD;

pub extern "kernel32" fn GetModuleHandleW(lpModuleName: ?[*:0]const WCHAR) callconv(.Stdcall) ?HMODULE;

pub extern "kernel32" fn GetLastError() callconv(.Stdcall) Win32Error;

pub extern "kernel32" fn GetFileInformationByHandle(
    hFile: HANDLE,
    lpFileInformation: *BY_HANDLE_FILE_INFORMATION,
) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn GetFileInformationByHandleEx(
    in_hFile: HANDLE,
    in_FileInformationClass: FILE_INFO_BY_HANDLE_CLASS,
    out_lpFileInformation: *c_void,
    in_dwBufferSize: DWORD,
) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn GetFinalPathNameByHandleW(
    hFile: HANDLE,
    lpszFilePath: [*]u16,
    cchFilePath: DWORD,
    dwFlags: DWORD,
) callconv(.Stdcall) DWORD;

pub extern "kernel32" fn GetOverlappedResult(hFile: HANDLE, lpOverlapped: *OVERLAPPED, lpNumberOfBytesTransferred: *DWORD, bWait: BOOL) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn GetProcessHeap() callconv(.Stdcall) ?HANDLE;
pub extern "kernel32" fn GetQueuedCompletionStatus(CompletionPort: HANDLE, lpNumberOfBytesTransferred: LPDWORD, lpCompletionKey: *ULONG_PTR, lpOverlapped: *?*OVERLAPPED, dwMilliseconds: DWORD) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn GetSystemInfo(lpSystemInfo: *SYSTEM_INFO) callconv(.Stdcall) void;
pub extern "kernel32" fn GetSystemTimeAsFileTime(*FILETIME) callconv(.Stdcall) void;

pub extern "kernel32" fn HeapCreate(flOptions: DWORD, dwInitialSize: SIZE_T, dwMaximumSize: SIZE_T) callconv(.Stdcall) ?HANDLE;
pub extern "kernel32" fn HeapDestroy(hHeap: HANDLE) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn HeapReAlloc(hHeap: HANDLE, dwFlags: DWORD, lpMem: *c_void, dwBytes: SIZE_T) callconv(.Stdcall) ?*c_void;
pub extern "kernel32" fn HeapSize(hHeap: HANDLE, dwFlags: DWORD, lpMem: *const c_void) callconv(.Stdcall) SIZE_T;
pub extern "kernel32" fn HeapCompact(hHeap: HANDLE, dwFlags: DWORD) callconv(.Stdcall) SIZE_T;
pub extern "kernel32" fn HeapSummary(hHeap: HANDLE, dwFlags: DWORD, lpSummary: LPHEAP_SUMMARY) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn GetStdHandle(in_nStdHandle: DWORD) callconv(.Stdcall) ?HANDLE;

pub extern "kernel32" fn HeapAlloc(hHeap: HANDLE, dwFlags: DWORD, dwBytes: SIZE_T) callconv(.Stdcall) ?*c_void;

pub extern "kernel32" fn HeapFree(hHeap: HANDLE, dwFlags: DWORD, lpMem: *c_void) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn HeapValidate(hHeap: HANDLE, dwFlags: DWORD, lpMem: ?*const c_void) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn VirtualAlloc(lpAddress: ?LPVOID, dwSize: SIZE_T, flAllocationType: DWORD, flProtect: DWORD) callconv(.Stdcall) ?LPVOID;
pub extern "kernel32" fn VirtualFree(lpAddress: ?LPVOID, dwSize: SIZE_T, dwFreeType: DWORD) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn MoveFileExW(
    lpExistingFileName: [*:0]const u16,
    lpNewFileName: [*:0]const u16,
    dwFlags: DWORD,
) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn PostQueuedCompletionStatus(CompletionPort: HANDLE, dwNumberOfBytesTransferred: DWORD, dwCompletionKey: ULONG_PTR, lpOverlapped: ?*OVERLAPPED) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn QueryPerformanceCounter(lpPerformanceCount: *LARGE_INTEGER) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn QueryPerformanceFrequency(lpFrequency: *LARGE_INTEGER) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn ReadDirectoryChangesW(
    hDirectory: HANDLE,
    lpBuffer: [*]align(@alignOf(FILE_NOTIFY_INFORMATION)) u8,
    nBufferLength: DWORD,
    bWatchSubtree: BOOL,
    dwNotifyFilter: DWORD,
    lpBytesReturned: ?*DWORD,
    lpOverlapped: ?*OVERLAPPED,
    lpCompletionRoutine: LPOVERLAPPED_COMPLETION_ROUTINE,
) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn ReadFile(
    in_hFile: HANDLE,
    out_lpBuffer: [*]u8,
    in_nNumberOfBytesToRead: DWORD,
    out_lpNumberOfBytesRead: ?*DWORD,
    in_out_lpOverlapped: ?*OVERLAPPED,
) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn RemoveDirectoryW(lpPathName: [*:0]const u16) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn SetConsoleTextAttribute(hConsoleOutput: HANDLE, wAttributes: WORD) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn SetFilePointerEx(
    in_fFile: HANDLE,
    in_liDistanceToMove: LARGE_INTEGER,
    out_opt_ldNewFilePointer: ?*LARGE_INTEGER,
    in_dwMoveMethod: DWORD,
) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn SetFileTime(
    hFile: HANDLE,
    lpCreationTime: ?*const FILETIME,
    lpLastAccessTime: ?*const FILETIME,
    lpLastWriteTime: ?*const FILETIME,
) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn SetHandleInformation(hObject: HANDLE, dwMask: DWORD, dwFlags: DWORD) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn Sleep(dwMilliseconds: DWORD) callconv(.Stdcall) void;

pub extern "kernel32" fn SwitchToThread() callconv(.Stdcall) BOOL;

pub extern "kernel32" fn TerminateProcess(hProcess: HANDLE, uExitCode: UINT) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn TlsAlloc() callconv(.Stdcall) DWORD;

pub extern "kernel32" fn TlsFree(dwTlsIndex: DWORD) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn WaitForSingleObject(hHandle: HANDLE, dwMilliseconds: DWORD) callconv(.Stdcall) DWORD;

pub extern "kernel32" fn WaitForSingleObjectEx(hHandle: HANDLE, dwMilliseconds: DWORD, bAlertable: BOOL) callconv(.Stdcall) DWORD;

pub extern "kernel32" fn WaitForMultipleObjects(nCount: DWORD, lpHandle: [*]const HANDLE, bWaitAll: BOOL, dwMilliseconds: DWORD) callconv(.Stdcall) DWORD;

pub extern "kernel32" fn WaitForMultipleObjectsEx(
    nCount: DWORD,
    lpHandle: [*]const HANDLE,
    bWaitAll: BOOL,
    dwMilliseconds: DWORD,
    bAlertable: BOOL,
) callconv(.Stdcall) DWORD;

pub extern "kernel32" fn WriteFile(
    in_hFile: HANDLE,
    in_lpBuffer: [*]const u8,
    in_nNumberOfBytesToWrite: DWORD,
    out_lpNumberOfBytesWritten: ?*DWORD,
    in_out_lpOverlapped: ?*OVERLAPPED,
) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn WriteFileEx(hFile: HANDLE, lpBuffer: [*]const u8, nNumberOfBytesToWrite: DWORD, lpOverlapped: LPOVERLAPPED, lpCompletionRoutine: LPOVERLAPPED_COMPLETION_ROUTINE) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn LoadLibraryW(lpLibFileName: [*:0]const u16) callconv(.Stdcall) ?HMODULE;

pub extern "kernel32" fn GetProcAddress(hModule: HMODULE, lpProcName: [*]const u8) callconv(.Stdcall) ?FARPROC;

pub extern "kernel32" fn FreeLibrary(hModule: HMODULE) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn InitializeCriticalSection(lpCriticalSection: *CRITICAL_SECTION) callconv(.Stdcall) void;
pub extern "kernel32" fn EnterCriticalSection(lpCriticalSection: *CRITICAL_SECTION) callconv(.Stdcall) void;
pub extern "kernel32" fn LeaveCriticalSection(lpCriticalSection: *CRITICAL_SECTION) callconv(.Stdcall) void;
pub extern "kernel32" fn DeleteCriticalSection(lpCriticalSection: *CRITICAL_SECTION) callconv(.Stdcall) void;

pub extern "kernel32" fn InitOnceExecuteOnce(InitOnce: *INIT_ONCE, InitFn: INIT_ONCE_FN, Parameter: ?*c_void, Context: ?*c_void) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn K32EmptyWorkingSet(hProcess: HANDLE) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn K32EnumDeviceDrivers(lpImageBase: [*]LPVOID, cb: DWORD, lpcbNeeded: LPDWORD) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn K32EnumPageFilesA(pCallBackRoutine: PENUM_PAGE_FILE_CALLBACKA, pContext: LPVOID) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn K32EnumPageFilesW(pCallBackRoutine: PENUM_PAGE_FILE_CALLBACKW, pContext: LPVOID) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn K32EnumProcessModules(hProcess: HANDLE, lphModule: [*]HMODULE, cb: DWORD, lpcbNeeded: LPDWORD) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn K32EnumProcessModulesEx(hProcess: HANDLE, lphModule: [*]HMODULE, cb: DWORD, lpcbNeeded: LPDWORD, dwFilterFlag: DWORD) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn K32EnumProcesses(lpidProcess: [*]DWORD, cb: DWORD, cbNeeded: LPDWORD) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn K32GetDeviceDriverBaseNameA(ImageBase: LPVOID, lpBaseName: LPSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "kernel32" fn K32GetDeviceDriverBaseNameW(ImageBase: LPVOID, lpBaseName: LPWSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "kernel32" fn K32GetDeviceDriverFileNameA(ImageBase: LPVOID, lpFilename: LPSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "kernel32" fn K32GetDeviceDriverFileNameW(ImageBase: LPVOID, lpFilename: LPWSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "kernel32" fn K32GetMappedFileNameA(hProcess: HANDLE, lpv: ?LPVOID, lpFilename: LPSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "kernel32" fn K32GetMappedFileNameW(hProcess: HANDLE, lpv: ?LPVOID, lpFilename: LPWSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "kernel32" fn K32GetModuleBaseNameA(hProcess: HANDLE, hModule: ?HMODULE, lpBaseName: LPSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "kernel32" fn K32GetModuleBaseNameW(hProcess: HANDLE, hModule: ?HMODULE, lpBaseName: LPWSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "kernel32" fn K32GetModuleFileNameExA(hProcess: HANDLE, hModule: ?HMODULE, lpFilename: LPSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "kernel32" fn K32GetModuleFileNameExW(hProcess: HANDLE, hModule: ?HMODULE, lpFilename: LPWSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "kernel32" fn K32GetModuleInformation(hProcess: HANDLE, hModule: HMODULE, lpmodinfo: LPMODULEINFO, cb: DWORD) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn K32GetPerformanceInfo(pPerformanceInformation: PPERFORMACE_INFORMATION, cb: DWORD) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn K32GetProcessImageFileNameA(hProcess: HANDLE, lpImageFileName: LPSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "kernel32" fn K32GetProcessImageFileNameW(hProcess: HANDLE, lpImageFileName: LPWSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "kernel32" fn K32GetProcessMemoryInfo(Process: HANDLE, ppsmemCounters: PPROCESS_MEMORY_COUNTERS, cb: DWORD) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn K32GetWsChanges(hProcess: HANDLE, lpWatchInfo: PPSAPI_WS_WATCH_INFORMATION, cb: DWORD) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn K32GetWsChangesEx(hProcess: HANDLE, lpWatchInfoEx: PPSAPI_WS_WATCH_INFORMATION_EX, cb: DWORD) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn K32InitializeProcessForWsWatch(hProcess: HANDLE) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn K32QueryWorkingSet(hProcess: HANDLE, pv: PVOID, cb: DWORD) callconv(.Stdcall) BOOL;
pub extern "kernel32" fn K32QueryWorkingSetEx(hProcess: HANDLE, pv: PVOID, cb: DWORD) callconv(.Stdcall) BOOL;

pub extern "kernel32" fn FlushFileBuffers(hFile: HANDLE) callconv(.Stdcall) BOOL;
