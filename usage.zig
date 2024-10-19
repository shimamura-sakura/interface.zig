const std = @import("std");
const in = @import("in.zig");

pub const Stream = struct {
    vtable: *const anyopaque,
    object: *anyopaque,
    pub fn write(self: @This(), buf: []const u8) void {
        if (in.vt(self).write) |f| return f(self.object, buf);
        // write "unreachable;" or default implementation here
    }
};

pub const PosixFd = struct {
    pub const impls = .{Stream};
    fd: std.posix.fd_t,
    pub fn write(self: @This(), buf: []const u8) void {
        _ = std.posix.write(self.fd, buf) catch {};
    }
};

pub fn main() void {
    var stdout = PosixFd{ .fd = 1 };
    var stderr = PosixFd{ .fd = 2 };
    const s1 = in.into(Stream, &stdout);
    const s2 = in.into(Stream, &stderr);
    s1.write("Hello, S1\n");
    s2.write("Hello, S2\n");
    std.debug.assert(in.back(PosixFd, s1) == &stdout);
    std.debug.assert(in.back(PosixFd, s2) == &stderr);
}
