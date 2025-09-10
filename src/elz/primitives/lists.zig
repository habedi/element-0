const std = @import("std");
const core = @import("../core.zig");
const eval = @import("../eval.zig");
const Value = core.Value;
const ElzError = @import("../errors.zig").ElzError;
const interpreter = @import("../interpreter.zig");

pub fn cons(_: *interpreter.Interpreter, env: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const p = try env.allocator.create(core.Pair);
    p.* = .{
        .car = try args.items[0].deep_clone(env.allocator),
        .cdr = try args.items[1].deep_clone(env.allocator),
    };
    return Value{ .pair = p };
}

pub fn car(_: *interpreter.Interpreter, env: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    const p = args.items[0];
    if (p != .pair) return ElzError.InvalidArgument;
    return p.pair.car.deep_clone(env.allocator);
}

pub fn cdr(_: *interpreter.Interpreter, env: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    const p = args.items[0];
    if (p != .pair) return ElzError.InvalidArgument;
    return p.pair.cdr.deep_clone(env.allocator);
}

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
