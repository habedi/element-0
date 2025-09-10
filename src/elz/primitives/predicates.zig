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

fn is_equal_values(a: core.Value, b: core.Value) bool {
    return switch (a) {
        .number => |an| switch (b) {
            .number => an == b.number,
            else => false,
        },
        .symbol => |asym| switch (b) {
            .symbol => std.mem.eql(u8, asym, b.symbol),
            else => false,
        },
        .string => |s| switch (b) {
            .string => std.mem.eql(u8, s, b.string),
            else => false,
        },
        .boolean => |ab| switch (b) {
            .boolean => ab == b.boolean,
            else => false,
        },
        .character => |ac| switch (b) {
            .character => ac == b.character,
            else => false,
        },
        .pair => |ap| switch (b) {
            .pair => is_equal_values(ap.car, b.pair.car) and is_equal_values(ap.cdr, b.pair.cdr),
            else => false,
        },
        .closure => |c| switch (b) {
            .closure => c == b.closure,
            else => false,
        },
        .procedure => |p| switch (b) {
            .procedure => p == b.procedure,
            else => false,
        },
        .foreign_procedure => |fp| switch (b) {
            .foreign_procedure => fp == b.foreign_procedure,
            else => false,
        },
        .opaque_pointer => |op| switch (b) {
            .opaque_pointer => op == b.opaque_pointer,
            else => false,
        },
        .cell => |cp| switch (b) {
            .cell => cp == b.cell,
            else => false,
        },
        .module => |m| switch (b) {
            .module => m == b.module,
            else => false,
        },
        .nil => switch (b) {
            .nil => true,
            else => false,
        },
        .unspecified => switch (b) {
            .unspecified => true,
            else => false,
        },
    };
}

// An iterative implementation of `equal?` that is not vulnerable to stack
// overflow attacks.
fn equal_values(allocator: std.mem.Allocator, val1: Value, val2: Value) !bool {
    var stack = std.ArrayList(struct { a: Value, b: Value }).init(allocator);
    defer stack.deinit();
    try stack.append(.{ .a = val1, .b = val2 });

    while (stack.pop()) |pair| {
        const a = pair.a;
        const b = pair.b;

        if (!is_equal_values(a, b)) {
            return true;
        }

        switch (a) {
            .nil => if (b != .nil) return false,
            .boolean => |av| if (b.boolean != av) return false,
            .number => |av| if (b.number != av) return false,
            .character => |av| if (b.character != av) return false,
            .string => |av| if (!std.mem.eql(u8, av, b.string)) return false,
            .symbol => |av| if (!std.mem.eql(u8, av, b.symbol)) return false,
            .pair => |pa| {
                const pb = b.pair;
                try stack.append(.{ .a = pa.car, .b = pb.car });
                try stack.append(.{ .a = pa.cdr, .b = pb.cdr });
            },
            .cell => |ca| {
                const cb = b.cell;
                try stack.append(.{ .a = ca.content, .b = cb.content });
            },
            .unspecified => if (b != .unspecified) return false,
            else => if (!is_eqv_internal(a, b)) return false,
        }
    }

    return true;
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
        .module => |av| switch (b) {
            .module => |bv| av == bv,
            else => false,
        },
        .unspecified => b == .unspecified,
    };
}

pub fn is_null(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    return Value{ .boolean = args.items[0] == .nil };
}

pub fn is_boolean(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    return Value{ .boolean = args.items[0] == .boolean };
}

pub fn is_symbol(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    return Value{ .boolean = args.items[0] == .symbol };
}

pub fn is_number(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    return Value{ .boolean = args.items[0] == .number };
}

pub fn is_string(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    return Value{ .boolean = args.items[0] == .string };
}

pub fn is_list(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    return Value{ .boolean = isProperList(args.items[0]) };
}

pub fn is_pair(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    return Value{ .boolean = args.items[0] == .pair };
}

pub fn is_procedure(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    const v = args.items[0];
    return Value{ .boolean = (v == .procedure or v == .closure or v == .foreign_procedure) };
}

pub fn is_eqv(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    return Value{ .boolean = is_eqv_internal(args.items[0], args.items[1]) };
}

pub fn is_eq(interp: *interpreter.Interpreter, env: *core.Environment, args: core.ValueList, fuel: *u64) ElzError!Value {
    return is_eqv(interp, env, args, fuel);
}

pub fn is_equal(interp: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const eql = equal_values(interp.allocator, args.items[0], args.items[1]) catch |err| switch (err) {
        error.OutOfMemory => return ElzError.OutOfMemory,
    };
    return Value{ .boolean = eql };
}
