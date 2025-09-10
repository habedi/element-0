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

// An iterative implementation of `equal?` that is not vulnerable to stack
// overflow attacks.
fn equal_values(allocator: std.mem.Allocator, val1: Value, val2: Value) !bool {
    var stack = std.ArrayList(struct { a: Value, b: Value }).init(allocator);
    defer stack.deinit();
    try stack.append(.{ .a = val1, .b = val2 });

    while (stack.pop()) |pair| {
        const a = pair.a;
        const b = pair.b;

        // If two values are pointer-equivalent or identical immediate values,
        // they are equal. This is a fast path.
        if (is_eqv_internal(a, b)) {
            continue;
        }

        // If they are not eqv?, their types must be the same to be equal?.
        if (!std.mem.eql(u8, @tagName(a), @tagName(b))) {
            return false;
        }

        // Perform structural comparison based on type.
        switch (a) {
            .string => |s1| {
                if (!std.mem.eql(u8, s1, b.string)) return false;
            },
            .symbol => |s1| {
                if (!std.mem.eql(u8, s1, b.symbol)) return false;
            },
            .pair => |p1| {
                const p2 = b.pair;
                // Push cdr then car, so the stack (LIFO) processes car first.
                try stack.append(.{ .a = p1.cdr, .b = p2.cdr });
                try stack.append(.{ .a = p1.car, .b = p2.car });
            },
            .cell => |c1| {
                const c2 = b.cell;
                try stack.append(.{ .a = c1.content, .b = c2.content });
            },
            else => {
                // For all other types, if they have the same type but are not
                // `eqv?`, they are not `equal?`. This handles numbers, booleans,
                // characters, closures, etc.
                return false;
            },
        }
    }

    // The stack is empty and we never found a difference, so they are equal.
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

test "predicate primitives" {
    const allocator = std.testing.allocator;
    const testing = std.testing;
    var interp = interpreter.Interpreter.init(allocator);
    defer interp.deinit();
    var fuel: u64 = 1000;

    // Test is_null
    var args = core.ValueList.init(allocator);
    try args.append(Value.nil);
    var result = try is_null(&interp, interp.root_env, args, &fuel);
    try testing.expect(result == Value{ .boolean = true });

    args.clearRetainingCapacity();
    try args.append(Value{ .number = 0 });
    result = try is_null(&interp, interp.root_env, args, &fuel);
    try testing.expect(result == Value{ .boolean = false });

    // Test is_boolean
    args.clearRetainingCapacity();
    try args.append(Value{ .boolean = true });
    result = try is_boolean(&interp, interp.root_env, args, &fuel);
    try testing.expect(result == Value{ .boolean = true });

    // Test is_eq
    args.clearRetainingCapacity();
    try args.append(Value{ .number = 1 });
    try args.append(Value{ .number = 1 });
    result = try is_eq(&interp, interp.root_env, args, &fuel);
    try testing.expect(result == Value{ .boolean = true });

    args.clearRetainingCapacity();
    try args.append(Value{ .number = 1 });
    try args.append(Value{ .number = 2 });
    result = try is_eq(&interp, interp.root_env, args, &fuel);
    try testing.expect(result == Value{ .boolean = false });

    // Test is_equal
    args.clearRetainingCapacity();
    const p1 = try allocator.create(core.Pair);
    p1.* = .{ .car = core.Value{ .number = 1 }, .cdr = .nil };
    const list1 = core.Value{ .pair = p1 };

    const p2 = try allocator.create(core.Pair);
    p2.* = .{ .car = core.Value{ .number = 1 }, .cdr = .nil };
    const list2 = core.Value{ .pair = p2 };

    try args.append(list1);
    try args.append(list2);
    result = try is_equal(&interp, interp.root_env, args, &fuel);
    try testing.expect(result == Value{ .boolean = true });
}
