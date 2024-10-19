const std = @import("std");
const bui = std.builtin;

/// into(IntfType, &implObj)
pub fn into(comptime I: type, t: anytype) I {
    mustImpl(@TypeOf(t.*), I);
    return .{ .vtable = vtable(I, @TypeOf(t.*)), .object = @ptrCast(t) };
}

/// back(ImplType, intfObj)
pub fn back(comptime T: type, i: anytype) ?*T {
    mustImpl(T, @TypeOf(i));
    return if (vtable(@TypeOf(i), T) == i.vtable) @alignCast(@ptrCast(i.object)) else null;
}

/// if (vt(self).func_name) |f| return f(self.object, args);
pub fn vt(i: anytype) *const VTable(@TypeOf(i)) {
    return @alignCast(@ptrCast(i.vtable));
}

fn mustImpl(comptime T: type, comptime I: type) void {
    inline for (T.impls) |i| if (i == I) return;
    @compileError(std.fmt.comptimePrint("type {} doesn't implement {}", .{ T, I }));
}

// convert decls into fields
// call on interface type
fn VTable(comptime I: type) type {
    const decls = @typeInfo(I).@"struct".decls;
    comptime var fields: [decls.len]bui.Type.StructField = undefined;
    for (decls, &fields) |d, *f| f.* = .{
        .name = d.name,
        .type = ?*const VTableEntry(@TypeOf(@field(I, d.name))),
        .default_value = null,
        .is_comptime = false,
        .alignment = @alignOf(*const anyopaque),
    };
    return @Type(.{ .@"struct" = .{
        .layout = .auto,
        .fields = &fields,
        .decls = &.{},
        .is_tuple = false,
    } });
}

// replace first argument with *anyopaque
// call both with interface fn and impl fn
fn VTableEntry(comptime F: type) type {
    comptime var f = @typeInfo(F).@"fn";
    if (f.params.len == 0) @compileError("member function must have at least 1 arg");
    comptime var params = f.params[0..].*;
    if (params[0].type) |*t| t.* = *anyopaque else @compileError("first argument cannot be anytype");
    for (params) |p| if (p.type == null) @compileError("member function cannot have anytype arguments");
    f.params = &params;
    return @Type(.{ .@"fn" = f });
}

// compute vtable of impl T into interface I
fn vtable(comptime I: type, comptime T: type) *const anyopaque {
    mustImpl(T, I);
    comptime var t: VTable(I) = undefined;
    inline for (@typeInfo(I).@"struct".decls) |d| @field(t, d.name) =
        comptime if (@hasDecl(T, d.name)) vtableEntry(T, @field(T, d.name)) else null;
    const v = t; // is this ok ?
    return @ptrCast(&v);
}

// convert self function into *anyopaque function, and take pointer
// call with impl type and impl func
fn vtableEntry(comptime Self: type, comptime f: anytype) *const VTableEntry(@TypeOf(f)) {
    const fun = @typeInfo(@TypeOf(f)).@"fn";
    const Ret = fun.return_type.?;
    comptime var P: [fun.params.len]type = undefined;
    inline for (&P, fun.params) |*p, q| p.* = q.type.?;
    if (P[0] == *Self or P[0] == *const Self) return @ptrCast(&f); // pointer, no wrapper
    if (P[0] != Self) @compileError("first argument may only be *Self, *const Self or Self");
    switch (fun.params.len) {
        1 => return @ptrCast(&(struct {
            fn x(self: *Self) Ret {
                return f(self.*);
            }
        }.x)),
        2 => return @ptrCast(&(struct {
            fn x(self: *Self, a: P[1]) Ret {
                return f(self.*, a);
            }
        }.x)),
        3 => return @ptrCast(&(struct {
            fn x(self: *Self, a: P[1], b: P[2]) Ret {
                return f(self.*, a, b);
            }
        }.x)),
        4 => return @ptrCast(&(struct {
            fn x(self: *Self, a: P[1], b: P[2], c: P[3]) Ret {
                return f(self.*, a, b, c);
            }
        }.x)),
        5 => return @ptrCast(&(struct {
            fn x(self: *Self, a: P[1], b: P[2], c: P[3], d: P[4]) Ret {
                return f(self.*, a, b, c, d);
            }
        }.x)),
        6 => return @ptrCast(&(struct {
            fn x(self: *Self, a: P[1], b: P[2], c: P[3], d: P[4], e: P[5]) Ret {
                return f(self.*, a, b, c, d, e);
            }
        }.x)),
        else => @compileError("not implemented: argument count not handled"),
    }
}
