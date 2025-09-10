const std = @import("std");
const core = @import("../core.zig");
const Value = core.Value;
const ElzError = @import("../errors.zig").ElzError;
const interpreter = @import("../interpreter.zig");

fn isProperList(v: Value) bool {
    var cur = v;
    while (cur == .pair) {
        cur = cur.pair.cdr;
    }
    return cur == .nil;
}

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
        .closure, .procedure, .foreign_procedure, .opaque_pointer => return is_eqv_internal(a, b),
        .pair => |pa| return switch (b) {
            .pair => |pb| equal_values(pa.car, pb.car) and equal_values(pa.cdr, pb.cdr),
            else => false,
        },
        .cell => |ca| return switch (b) {
            .cell => |cb| equal_values(ca.content, cb.content),
            else => false,
        },
        .unspecified => return b == .unspecified,
    }
}

fn is_eqv_internal(a: Value, b: Value) bool {
    return switch (a) {
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
        .cell => |av| switch (b) {
            .cell => |bv| av == bv,
            else => false,
        },
        .unspecified => b == .unspecified,
    };
}

pub fn is_null(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    return Value{ .boolean = args.items[0] == .nil };
}

pub fn is_boolean(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    return Value{ .boolean = args.items[0] == .boolean };
}

pub fn is_symbol(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    return Value{ .boolean = args.items[0] == .symbol };
}

pub fn is_number(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    return Value{ .boolean = args.items[0] == .number };
}

pub fn is_list(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    return Value{ .boolean = isProperList(args.items[0]) };
}

pub fn is_pair(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    return Value{ .boolean = args.items[0] == .pair };
}

pub fn is_eqv(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    return Value{ .boolean = is_eqv_internal(args.items[0], args.items[1]) };
}

pub fn is_eq(interp: *interpreter.Interpreter, env: *core.Environment, args: core.ValueList) ElzError!Value {
    return is_eqv(interp, env, args);
}

pub fn is_equal(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    return Value{ .boolean = equal_values(args.items[0], args.items[1]) };
}
