const std = @import("std");
const core = @import("../core.zig");
const Value = core.Value;
const ElzError = @import("../errors.zig").ElzError;
const interpreter = @import("../interpreter.zig");

pub fn add(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    var sum: f64 = 0;
    for (args.items) |arg| {
        if (arg != .number) return ElzError.InvalidArgument;
        sum += arg.number;
    }
    return Value{ .number = sum };
}

pub fn sub(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len == 0) return ElzError.WrongArgumentCount;
    if (args.items[0] != .number) return ElzError.InvalidArgument;
    var result = args.items[0].number;
    if (args.items.len == 1) {
        return Value{ .number = -result };
    }
    for (args.items[1..]) |arg| {
        if (arg != .number) return ElzError.InvalidArgument;
        result -= arg.number;
    }
    return Value{ .number = result };
}

pub fn mul(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    var product: f64 = 1;
    for (args.items) |arg| {
        if (arg != .number) return ElzError.InvalidArgument;
        product *= arg.number;
    }
    return Value{ .number = product };
}

pub fn div(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    if (args.items[0] != .number or args.items[1] != .number) return ElzError.InvalidArgument;
    if (args.items[1].number == 0) return ElzError.DivisionByZero;
    return Value{ .number = args.items[0].number / args.items[1].number };
}

pub fn le(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const a = args.items[0];
    const b = args.items[1];
    if (a != .number or b != .number) return ElzError.InvalidArgument;
    return Value{ .boolean = a.number <= b.number };
}

pub fn lt(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const a = args.items[0];
    const b = args.items[1];
    if (a != .number or b != .number) return ElzError.InvalidArgument;
    return Value{ .boolean = a.number < b.number };
}

pub fn ge(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const a = args.items[0];
    const b = args.items[1];
    if (a != .number or b != .number) return ElzError.InvalidArgument;
    return Value{ .boolean = a.number >= b.number };
}

pub fn gt(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const a = args.items[0];
    const b = args.items[1];
    if (a != .number or b != .number) return ElzError.InvalidArgument;
    return Value{ .boolean = a.number > b.number };
}

pub fn eq_num(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const a = args.items[0];
    const b = args.items[1];
    if (a != .number or b != .number) return ElzError.InvalidArgument;
    return Value{ .boolean = a.number == b.number };
}

pub fn sqrt(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    if (args.items[0] != .number) return ElzError.InvalidArgument;
    return Value{ .number = std.math.sqrt(args.items[0].number) };
}

pub fn sin(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    if (args.items[0] != .number) return ElzError.InvalidArgument;
    return Value{ .number = std.math.sin(args.items[0].number) };
}

pub fn cos(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    if (args.items[0] != .number) return ElzError.InvalidArgument;
    return Value{ .number = std.math.cos(args.items[0].number) };
}

pub fn tan(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    if (args.items[0] != .number) return ElzError.InvalidArgument;
    return Value{ .number = std.math.tan(args.items[0].number) };
}

pub fn log(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    if (args.items[0] != .number) return ElzError.InvalidArgument;
    const x = args.items[0].number;
    return Value{ .number = std.math.log(f64, std.math.e, x) };
}

pub fn max(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len == 0) return ElzError.WrongArgumentCount;
    var max_val: f64 = -std.math.inf(f64);
    if (args.items[0] == .number) {
        max_val = args.items[0].number;
    } else {
        return ElzError.InvalidArgument;
    }

    for (args.items[1..]) |arg| {
        if (arg != .number) return ElzError.InvalidArgument;
        if (arg.number > max_val) {
            max_val = arg.number;
        }
    }
    return Value{ .number = max_val };
}

pub fn min(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len == 0) return ElzError.WrongArgumentCount;
    var min_val: f64 = std.math.inf(f64);
    if (args.items[0] == .number) {
        min_val = args.items[0].number;
    } else {
        return ElzError.InvalidArgument;
    }

    for (args.items[1..]) |arg| {
        if (arg != .number) return ElzError.InvalidArgument;
        if (arg.number < min_val) {
            min_val = arg.number;
        }
    }
    return Value{ .number = min_val };
}
