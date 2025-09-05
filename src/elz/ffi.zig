//! This module provides the Foreign Function Interface (FFI) for Element 0.
//! It allows Zig functions to be called from Element 0 code.

const std = @import("std");
const core = @import("core.zig");
const ElzError = @import("errors.zig").ElzError;

/// A generic type for casting Element 0 values to Zig types.
/// This is a helper for the FFI.
///
/// - `T`: The Zig type to cast to.
pub fn Caster(comptime T: type) type {
    return struct {
        /// Casts a `core.Value` to the specified Zig type `T`.
        ///
        /// - `v`: The `core.Value` to cast.
        /// - `return`: The casted value of type `T`, or an error if the cast fails.
        pub fn cast(v: core.Value) ElzError!T {
            return switch (@typeInfo(T)) {
                .float => switch (v) {
                    .number => |n| @floatCast(n),
                    else => ElzError.InvalidArgument,
                },
                .int => switch (v) {
                    .number => |n| @intFromFloat(n),
                    else => ElzError.InvalidArgument,
                },
                else => @compileError("Unsupported type for FFI casting"),
            };
        }
    };
}

/// Wraps a Zig function into an Element 0 foreign procedure.
/// This function uses comptime reflection to generate a wrapper based on the
/// signature of the provided Zig function. The wrapper handles the conversion
/// of arguments from Element 0 values to Zig types and the conversion of the
/// return value from a Zig type to an Element 0 value.
///
/// - `F`: The Zig function to wrap.
/// - `return`: A pointer to the wrapped function.
pub fn makeForeignFunc(comptime F: anytype) *const fn (env: *core.Environment, args: core.ValueList) anyerror!core.Value {
    const FInfo = @typeInfo(@TypeOf(F)).@"fn";

    if (FInfo.params.len == 2 and
        FInfo.params[0].type.? == std.mem.Allocator and
        FInfo.params[1].type.? == []const core.Value)
    {
        return ffi_wrap_variadic(F, FInfo);
    }

    return switch (FInfo.params.len) {
        0 => ffi_wrap_0(F, FInfo),
        1 => ffi_wrap_1(F, FInfo),
        2 => ffi_wrap_2(F, FInfo),
        else => @compileError("Unsupported number of arguments for FFI function. Only 0, 1, 2 or variadic slice are supported."),
    };
}

/// Wraps a Zig function with zero arguments.
/// This is a helper function for `makeForeignFunc`.
///
/// - `F`: The Zig function to wrap.
/// - `FInfo`: The function type information.
/// - `return`: A pointer to the wrapped function.
fn ffi_wrap_0(comptime F: anytype, comptime FInfo: std.builtin.Type.Fn) *const fn (env: *core.Environment, args: core.ValueList) anyerror!core.Value {
    const call = struct {
        fn call(env: *core.Environment, args: core.ValueList) anyerror!core.Value {
            if (args.items.len != 0) return ElzError.WrongArgumentCount;
            const ReturnTypeInfo = @typeInfo(FInfo.return_type.?);
            if (comptime ReturnTypeInfo == .error_union) {
                const result = F() catch |err| return err;
                return valueFromNative(env.allocator, result);
            } else {
                const result = F();
                return valueFromNative(env.allocator, result);
            }
        }
    }.call;
    return &call;
}

/// Wraps a Zig function with one argument.
/// This is a helper function for `makeForeignFunc`.
///
/// - `F`: The Zig function to wrap.
/// - `FInfo`: The function type information.
/// - `return`: A pointer to the wrapped function.
fn ffi_wrap_1(comptime F: anytype, comptime FInfo: std.builtin.Type.Fn) *const fn (env: *core.Environment, args: core.ValueList) anyerror!core.Value {
    const P1 = FInfo.params[0].type.?;
    const call = struct {
        fn call(env: *core.Environment, args: core.ValueList) anyerror!core.Value {
            if (args.items.len != 1) return ElzError.WrongArgumentCount;
            const p1 = try Caster(P1).cast(args.items[0]);
            const ReturnTypeInfo = @typeInfo(FInfo.return_type.?);
            if (comptime ReturnTypeInfo == .error_union) {
                const result = F(p1) catch |err| return err;
                return valueFromNative(env.allocator, result);
            } else {
                const result = F(p1);
                return valueFromNative(env.allocator, result);
            }
        }
    }.call;
    return &call;
}

/// Wraps a Zig function with two arguments.
/// This is a helper function for `makeForeignFunc`.
///
/// - `F`: The Zig function to wrap.
/// - `FInfo`: The function type information.
/// - `return`: A pointer to the wrapped function.
fn ffi_wrap_2(comptime F: anytype, comptime FInfo: std.builtin.Type.Fn) *const fn (env: *core.Environment, args: core.ValueList) anyerror!core.Value {
    const P1 = FInfo.params[0].type.?;
    const P2 = FInfo.params[1].type.?;
    const call = struct {
        fn call(env: *core.Environment, args: core.ValueList) anyerror!core.Value {
            if (args.items.len != 2) return ElzError.WrongArgumentCount;
            const p1 = try Caster(P1).cast(args.items[0]);
            const p2 = try Caster(P2).cast(args.items[1]);
            const ReturnTypeInfo = @typeInfo(FInfo.return_type.?);
            if (comptime ReturnTypeInfo == .error_union) {
                const result = F(p1, p2) catch |err| return err;
                return valueFromNative(env.allocator, result);
            } else {
                const result = F(p1, p2);
                return valueFromNative(env.allocator, result);
            }
        }
    }.call;
    return &call;
}

/// Wraps a variadic Zig function.
/// This is a helper function for `makeForeignFunc`.
///
/// - `F`: The Zig function to wrap.
/// - `FInfo`: The function type information.
/// - `return`: A pointer to the wrapped function.
fn ffi_wrap_variadic(comptime F: anytype, comptime FInfo: std.builtin.Type.Fn) *const fn (env: *core.Environment, args: core.ValueList) anyerror!core.Value {
    const call = struct {
        fn call(env: *core.Environment, args: core.ValueList) anyerror!core.Value {
            const ReturnTypeInfo = @typeInfo(FInfo.return_type.?);
            if (comptime ReturnTypeInfo == .error_union) {
                const result = F(env.allocator, args.items) catch |err| return err;
                return valueFromNative(env.allocator, result);
            } else {
                const result = F(env.allocator, args.items);
                return valueFromNative(env.allocator, result);
            }
        }
    }.call;
    return &call;
}

/// Converts a native Zig value to a `core.Value`.
///
/// - `allocator`: The memory allocator to use.
/// - `value`: The native Zig value to convert.
/// - `return`: The converted `core.Value`.
fn valueFromNative(allocator: std.mem.Allocator, value: anytype) core.Value {
    _ = allocator;
    const T = @TypeOf(value);
    return switch (@typeInfo(T)) {
        .void => core.Value.nil,
        .float, .comptime_float => core.Value{ .number = @floatCast(value) },
        .int, .comptime_int => core.Value{ .number = @floatFromInt(value) },
        .bool => core.Value{ .boolean = value },
        .@"union" => |u| {
            _ = u;
            if (T == core.Value) {
                return value;
            } else {
                @compileError("Unsupported union return type for FFI: " ++ @typeName(T));
            }
        },
        else => @compileError("Unsupported return type for FFI: " ++ @typeName(T)),
    };
}
