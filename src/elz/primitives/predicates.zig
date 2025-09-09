//! This module implements primitive procedures for type predicates and equality.

const std = @import("std");
const core = @import("../core.zig");
const Value = core.Value;
const ElzError = @import("../errors.zig").ElzError;

/// Checks if a value is a proper list.
/// A proper list is a `nil` value or a pair whose `cdr` is a proper list.
///
/// - `v`: The value to check.
/// - `return`: `true` if the value is a proper list, otherwise `false`.
fn isProperList(v: Value) bool {
    var cur = v;
    while (cur == .pair) {
        cur = cur.pair.cdr;
    }
    return cur == .nil;
}

/// Checks if two values are equal.
/// This function performs a deep equality check for pairs.
///
/// - `a`: The first value.
/// - `b`: The second value.
/// - `return`: `true` if the values are equal, otherwise `false`.
fn equal_values(a: Value, b: Value) bool {
    switch (a) {
        .nil => return b == .nil,
        .boolean => |av| return switch (b) {
            .boolean => |bv| av == bv,
            else => false,
        },
        .number => |av| return switch (b) {
            .number => |bv| av == bv,
            else => false,
        },
        .character => |av| return switch (b) {
            .character => |bv| av == bv,
            else => false,
        },
        .string => |av| return switch (b) {
            .string => |bv| std.mem.eql(u8, av, bv),
            else => false,
        },
        .symbol => |av| return switch (b) {
            .symbol => |bv| std.mem.eql(u8, av, bv),
            else => false,
        },
        .closure => |av| return switch (b) {
            .closure => |bv| av == bv,
            else => false,
        },
        .procedure => |av| return switch (b) {
            .procedure => |bv| av == bv,
            else => false,
        },
        .foreign_procedure => |av| return switch (b) {
            .foreign_procedure => |bv| av == bv,
            else => false,
        },
        .opaque_pointer => |av| return switch (b) {
            .opaque_pointer => |bv| av == bv,
            else => false,
        },
        .pair => |pa| return switch (b) {
            .pair => |pb| equal_values(pa.car, pb.car) and equal_values(pa.cdr, pb.cdr),
            else => false,
        },
        .unspecified => return b == .unspecified,
    }
}

/// The `null?` primitive procedure.
/// Checks if a value is `nil`.
pub fn is_null(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    return Value{ .boolean = args.items[0] == .nil };
}

/// The `boolean?` primitive procedure.
/// Checks if a value is a boolean.
pub fn is_boolean(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    return Value{ .boolean = args.items[0] == .boolean };
}

/// The `symbol?` primitive procedure.
/// Checks if a value is a symbol.
pub fn is_symbol(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    return Value{ .boolean = args.items[0] == .symbol };
}

/// The `number?` primitive procedure.
/// Checks if a value is a number.
pub fn is_number(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    return Value{ .boolean = args.items[0] == .number };
}

/// The `list?` primitive procedure.
/// Checks if a value is a proper list.
pub fn is_list(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    return Value{ .boolean = isProperList(args.items[0]) };
}

/// The `eqv?` primitive procedure.
/// Checks for object identity for compound types, and value equality otherwise.
pub fn is_eqv(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const a = args.items[0];
    const b = args.items[1];
    const result = switch (a) {
        .nil => b == .nil,
        .boolean => |av| switch (b) {
            .boolean => |bv| av == bv,
            else => false,
        },
        .number => |av| switch (b) {
            .number => |bv| av == bv,
            else => false,
        },
        .character => |av| switch (b) {
            .character => |bv| av == bv,
            else => false,
        },
        .string => |av| switch (b) {
            .string => |bv| av.ptr == bv.ptr,
            else => false,
        },
        .pair => |av| switch (b) {
            .pair => |bv| av == bv,
            else => false,
        },
        .closure => |av| switch (b) {
            .closure => |bv| av == bv,
            else => false,
        },
        .procedure => |av| switch (b) {
            .procedure => |bv| av == bv,
            else => false,
        },
        .foreign_procedure => |av| switch (b) {
            .foreign_procedure => |bv| av == bv,
            else => false,
        },
        .opaque_pointer => |av| switch (b) {
            .opaque_pointer => |bv| av == bv,
            else => false,
        },
        .symbol => |av| switch (b) {
            .symbol => |bv| av.ptr == bv.ptr,
            else => false,
        },
        .unspecified => b == .unspecified,
    };
    return Value{ .boolean = result };
}

/// The `eq?` primitive procedure.
/// This implementation is an alias for `eqv?`.
pub fn is_eq(env: *core.Environment, args: core.ValueList) !Value {
    return is_eqv(env, args);
}

/// The `equal?` primitive procedure.
/// Checks if two values are structurally equal.
pub fn is_equal(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    return Value{ .boolean = equal_values(args.items[0], args.items[1]) };
}
