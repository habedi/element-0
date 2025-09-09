//! This module implements primitive procedures for mathematical operations.

const std = @import("std");
const core = @import("../core.zig");
const Value = core.Value;
const ElzError = @import("../errors.zig").ElzError;

/// The `+` primitive procedure.
/// Adds a list of numbers.
///
/// - `args`: A list of numbers.
/// - `return`: The sum of the numbers.
pub fn add(_: *core.Environment, args: core.ValueList) !Value {
    var sum: f64 = 0;
    for (args.items) |arg| {
        if (arg != .number) return ElzError.InvalidArgument;
        sum += arg.number;
    }
    return Value{ .number = sum };
}

/// The `-` primitive procedure.
/// Subtracts a list of numbers from the first number.
/// If only one number is provided, it is negated.
///
/// - `args`: A list of numbers.
/// - `return`: The result of the subtraction.
pub fn sub(_: *core.Environment, args: core.ValueList) !Value {
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

/// The `*` primitive procedure.
/// Multiplies a list of numbers.
///
/// - `args`: A list of numbers.
/// - `return`: The product of the numbers.
pub fn mul(_: *core.Environment, args: core.ValueList) !Value {
    var product: f64 = 1;
    for (args.items) |arg| {
        if (arg != .number) return ElzError.InvalidArgument;
        product *= arg.number;
    }
    return Value{ .number = product };
}

/// The `/` primitive procedure.
/// Divides two numbers.
///
/// - `args`: A list containing two numbers.
/// - `return`: The result of the division.
pub fn div(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    if (args.items[0] != .number or args.items[1] != .number) return ElzError.InvalidArgument;
    if (args.items[1].number == 0) return ElzError.DivisionByZero;
    return Value{ .number = args.items[0].number / args.items[1].number };
}

/// The `<=` primitive procedure.
/// Checks if the first number is less than or equal to the second number.
///
/// - `args`: A list containing two numbers.
/// - `return`: A boolean value.
pub fn le(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const a = args.items[0];
    const b = args.items[1];
    if (a != .number or b != .number) return ElzError.InvalidArgument;
    return Value{ .boolean = a.number <= b.number };
}

/// The `<` primitive procedure.
/// Checks if the first number is less than the second number.
///
/// - `args`: A list containing two numbers.
/// - `return`: A boolean value.
pub fn lt(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const a = args.items[0];
    const b = args.items[1];
    if (a != .number or b != .number) return ElzError.InvalidArgument;
    return Value{ .boolean = a.number < b.number };
}

/// The `>=` primitive procedure.
/// Checks if the first number is greater than or equal to the second number.
///
/// - `args`: A list containing two numbers.
/// - `return`: A boolean value.
pub fn ge(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const a = args.items[0];
    const b = args.items[1];
    if (a != .number or b != .number) return ElzError.InvalidArgument;
    return Value{ .boolean = a.number >= b.number };
}

/// The `>` primitive procedure.
/// Checks if the first number is greater than the second number.
///
/// - `args`: A list containing two numbers.
/// - `return`: A boolean value.
pub fn gt(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const a = args.items[0];
    const b = args.items[1];
    if (a != .number or b != .number) return ElzError.InvalidArgument;
    return Value{ .boolean = a.number > b.number };
}

/// The `=` primitive procedure.
/// Checks if two numbers are equal.
///
/// - `args`: A list containing two numbers.
/// - `return`: A boolean value.
pub fn eq_num(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const a = args.items[0];
    const b = args.items[1];
    if (a != .number or b != .number) return ElzError.InvalidArgument;
    return Value{ .boolean = a.number == b.number };
}

/// The `sqrt` primitive procedure.
pub fn sqrt(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    if (args.items[0] != .number) return ElzError.InvalidArgument;
    return Value{ .number = std.math.sqrt(args.items[0].number) };
}

/// The `sin` primitive procedure.
pub fn sin(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    if (args.items[0] != .number) return ElzError.InvalidArgument;
    return Value{ .number = std.math.sin(args.items[0].number) };
}

/// The `cos` primitive procedure.
pub fn cos(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    if (args.items[0] != .number) return ElzError.InvalidArgument;
    return Value{ .number = std.math.cos(args.items[0].number) };
}

/// The `tan` primitive procedure.
pub fn tan(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    if (args.items[0] != .number) return ElzError.InvalidArgument;
    return Value{ .number = std.math.tan(args.items[0].number) };
}

/// The `log` primitive procedure (natural logarithm).
pub fn log(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    if (args.items[0] != .number) return ElzError.InvalidArgument;
    const x = args.items[0].number;
    return Value{ .number = std.math.log(f64, std.math.e, x) };
}
