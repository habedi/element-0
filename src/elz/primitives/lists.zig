const std = @import("std");
const core = @import("../core.zig");
const eval = @import("../eval.zig");
const Value = core.Value;
const ElzError = @import("../errors.zig").ElzError;
const interpreter = @import("../interpreter.zig");

/// `cons` creates a new pair.
///
/// Parameters:
/// - `args`: A `ValueList` containing two elements, the `car` and the `cdr` of the new pair.
///
/// Returns:
/// A new `Value.pair`.
pub fn cons(_: *interpreter.Interpreter, env: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const p = try env.allocator.create(core.Pair);
    p.* = .{
        .car = try args.items[0].deep_clone(env.allocator),
        .cdr = try args.items[1].deep_clone(env.allocator),
    };
    return Value{ .pair = p };
}

/// `car` returns the first element of a pair.
///
/// Parameters:
/// - `args`: A `ValueList` containing a single pair.
///
/// Returns:
/// The `car` of the pair.
pub fn car(_: *interpreter.Interpreter, env: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    const p = args.items[0];
    if (p != .pair) return ElzError.InvalidArgument;
    return p.pair.car.deep_clone(env.allocator);
}

/// `cdr` returns the second element of a pair.
///
/// Parameters:
/// - `args`: A `ValueList` containing a single pair.
///
/// Returns:
/// The `cdr` of the pair.
pub fn cdr(_: *interpreter.Interpreter, env: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    const p = args.items[0];
    if (p != .pair) return ElzError.InvalidArgument;
    return p.pair.cdr.deep_clone(env.allocator);
}

/// `list` creates a new list from its arguments.
///
/// Parameters:
/// - `args`: A `ValueList` of elements to be included in the new list.
///
/// Returns:
/// A new list.
pub fn list(_: *interpreter.Interpreter, env: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    var head: core.Value = .nil;
    var i = args.items.len;
    while (i > 0) {
        i -= 1;
        const p = try env.allocator.create(core.Pair);
        p.* = .{
            .car = try args.items[i].deep_clone(env.allocator),
            .cdr = head,
        };
        head = Value{ .pair = p };
    }
    return head;
}

/// `list_length` returns the number of elements in a proper list.
///
/// Parameters:
/// - `args`: A `ValueList` containing a single list.
///
/// Returns:
/// The length of the list as a `Value.number`.
pub fn list_length(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    var count: f64 = 0;
    var current = args.items[0];
    while (current != .nil) {
        const p = switch (current) {
            .pair => |pair_val| pair_val,
            else => return ElzError.InvalidArgument,
        };
        count += 1;
        current = p.cdr;
    }
    return Value{ .number = count };
}

/// `append` concatenates multiple lists into a single list.
///
/// Parameters:
/// - `args`: A `ValueList` of lists to be appended.
///
/// Returns:
/// A new list containing the elements of all the input lists.
pub fn append(_: *interpreter.Interpreter, env: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len == 0) return Value.nil;
    var result_head: core.Value = .nil;
    var result_tail: ?*core.Pair = null;
    for (args.items[0 .. args.items.len - 1]) |list_val| {
        var current_node = list_val;
        while (current_node != .nil) {
            const p_node = switch (current_node) {
                .pair => |p| p,
                else => return ElzError.InvalidArgument,
            };
            const new_pair = try env.allocator.create(core.Pair);
            new_pair.* = .{ .car = try p_node.car.deep_clone(env.allocator), .cdr = .nil };
            if (result_head == .nil) {
                result_head = Value{ .pair = new_pair };
                result_tail = new_pair;
            } else {
                if (result_tail) |tail| {
                    tail.cdr = Value{ .pair = new_pair };
                }
                result_tail = new_pair;
            }
            current_node = p_node.cdr;
        }
    }
    const last_list = try args.items[args.items.len - 1].deep_clone(env.allocator);
    if (result_head == .nil) {
        return last_list;
    } else {
        if (result_tail) |tail| {
            tail.cdr = last_list;
        }
        return result_head;
    }
}

/// `reverse` reverses the order of elements in a proper list.
///
/// Parameters:
/// - `args`: A `ValueList` containing a single list to be reversed.
///
/// Returns:
/// A new list with the elements in reverse order.
pub fn reverse(_: *interpreter.Interpreter, env: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    var head: core.Value = .nil;
    var current = args.items[0];
    while (current != .nil) {
        const p_node = switch (current) {
            .pair => |p| p,
            else => return ElzError.InvalidArgument,
        };
        const new_pair = try env.allocator.create(core.Pair);
        new_pair.* = .{ .car = try p_node.car.deep_clone(env.allocator), .cdr = head };
        head = Value{ .pair = new_pair };
        current = p_node.cdr;
    }
    return head;
}

/// `map` applies a procedure to each element of a list and returns a new list with the results.
///
/// Parameters:
/// - `args`: A `ValueList` containing two elements: the procedure to apply and the list to map over.
///
/// Returns:
/// A new list containing the results of applying the procedure to each element of the input list.
pub fn map(interp: *interpreter.Interpreter, env: *core.Environment, args: core.ValueList, fuel: *u64) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const proc = args.items[0];
    const list_val = args.items[1];
    var result_head: core.Value = .nil;
    var result_tail: ?*core.Pair = null;
    var arg_list = core.ValueList.init(env.allocator);
    try arg_list.append(.nil);
    var current_node = list_val;
    while (current_node != .nil) {
        const p_node = switch (current_node) {
            .pair => |p| p,
            else => return ElzError.InvalidArgument,
        };
        arg_list.items[0] = p_node.car;
        const mapped_val = try eval.eval_proc(interp, proc, arg_list, env, fuel);
        const new_pair = try env.allocator.create(core.Pair);
        new_pair.* = .{ .car = mapped_val, .cdr = .nil };
        if (result_tail) |tail| {
            tail.cdr = Value{ .pair = new_pair };
            result_tail = new_pair;
        } else {
            result_head = Value{ .pair = new_pair };
            result_tail = new_pair;
        }
        current_node = p_node.cdr;
    }
    return result_head;
}

test "list primitives" {
    const allocator = std.testing.allocator;
    const testing = std.testing;
    var interp = interpreter.Interpreter.init(allocator);
    defer interp.deinit();
    var fuel: u64 = 1000;

    // Test list
    var args = core.ValueList.init(allocator);
    try args.append(Value{ .number = 1 });
    try args.append(Value{ .number = 2 });
    const list_val = try list(&interp, interp.root_env, args, &fuel);
    try testing.expect(list_val.pair.car == Value{ .number = 1 });
    try testing.expect(list_val.pair.cdr.pair.car == Value{ .number = 2 });

    // Test cons
    args.clearRetainingCapacity();
    try args.append(Value{ .number = 0 });
    try args.append(list_val);
    const new_list = try cons(&interp, interp.root_env, args, &fuel);
    try testing.expect(new_list.pair.car == Value{ .number = 0 });

    // Test car
    args.clearRetainingCapacity();
    try args.append(new_list);
    const car_val = try car(&interp, interp.root_env, args, &fuel);
    try testing.expect(car_val == Value{ .number = 0 });

    // Test cdr
    args.clearRetainingCapacity();
    try args.append(new_list);
    const cdr_val = try cdr(&interp, interp.root_env, args, &fuel);
    try testing.expect(cdr_val.pair.car == Value{ .number = 1 });

    // Test list-length
    args.clearRetainingCapacity();
    try args.append(new_list);
    const len_val = try list_length(&interp, interp.root_env, args, &fuel);
    try testing.expect(len_val == Value{ .number = 3 });

    // Test reverse
    args.clearRetainingCapacity();
    try args.append(list_val);
    const reversed_list = try reverse(&interp, interp.root_env, args, &fuel);
    try testing.expect(reversed_list.pair.car == Value{ .number = 2 });
    try testing.expect(reversed_list.pair.cdr.pair.car == Value{ .number = 1 });

    // Test append
    args.clearRetainingCapacity();
    try args.append(list_val);
    try args.append(reversed_list);
    const appended_list = try append(&interp, interp.root_env, args, &fuel);
    try testing.expect(appended_list.pair.car == Value{ .number = 1 });
    try testing.expect(appended_list.pair.cdr.pair.car == Value{ .number = 2 });
    try testing.expect(appended_list.pair.cdr.pair.cdr.pair.car == Value{ .number = 2 });
    try testing.expect(appended_list.pair.cdr.pair.cdr.pair.cdr.pair.car == Value{ .number = 1 });

    // Test map
    const source = "(lambda (x) (* x 2))";
    const proc_val = try eval.eval(&interp, &try interp.read(source), interp.root_env, &fuel);
    args.clearRetainingCapacity();
    try args.append(proc_val);
    try args.append(list_val);
    const mapped_list = try map(&interp, interp.root_env, args, &fuel);
    try testing.expect(mapped_list.pair.car == Value{ .number = 2 });
    try testing.expect(mapped_list.pair.cdr.pair.car == Value{ .number = 4 });
}
