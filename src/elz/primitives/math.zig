const std = @import("std");
const core = @import("../core.zig");
const Value = core.Value;
const ElzError = @import("../errors.zig").ElzError;
const interpreter = @import("../interpreter.zig");

/// `add` is the implementation of the `+` primitive function.
/// It returns the sum of its arguments.
///
/// Parameters:
/// - `args`: A `ValueList` of numbers.
pub fn add(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    var sum: f64 = 0;
    for (args.items) |arg| {
        if (arg != .number) return ElzError.InvalidArgument;
        sum += arg.number;
    }
    return Value{ .number = sum };
}

/// `sub` is the implementation of the `-` primitive function.
/// If called with one argument, it returns the negation of that argument.
/// If called with multiple arguments, it subtracts the subsequent arguments from the first.
///
/// Parameters:
/// - `args`: A `ValueList` of numbers.
pub fn sub(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
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

/// `mul` is the implementation of the `*` primitive function.
/// It returns the product of its arguments.
///
/// Parameters:
/// - `args`: A `ValueList` of numbers.
pub fn mul(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    var product: f64 = 1;
    for (args.items) |arg| {
        if (arg != .number) return ElzError.InvalidArgument;
        product *= arg.number;
    }
    return Value{ .number = product };
}

/// `div` is the implementation of the `/` primitive function.
/// It returns the result of dividing the first argument by the second.
///
/// Parameters:
/// - `args`: A `ValueList` containing two numbers.
pub fn div(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    if (args.items[0] != .number or args.items[1] != .number) return ElzError.InvalidArgument;
    if (args.items[1].number == 0) return ElzError.DivisionByZero;
    return Value{ .number = args.items[0].number / args.items[1].number };
}

/// `le` is the implementation of the `<=` primitive function.
/// It returns `#t` if the first argument is less than or equal to the second, and `#f` otherwise.
///
/// Parameters:
/// - `args`: A `ValueList` containing two numbers.
pub fn le(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const a = args.items[0];
    const b = args.items[1];
    if (a != .number or b != .number) return ElzError.InvalidArgument;
    return Value{ .boolean = a.number <= b.number };
}

/// `lt` is the implementation of the `<` primitive function.
/// It returns `#t` if the first argument is less than the second, and `#f` otherwise.
///
/// Parameters:
/// - `args`: A `ValueList` containing two numbers.
pub fn lt(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const a = args.items[0];
    const b = args.items[1];
    if (a != .number or b != .number) return ElzError.InvalidArgument;
    return Value{ .boolean = a.number < b.number };
}

/// `ge` is the implementation of the `>=` primitive function.
/// It returns `#t` if the first argument is greater than or equal to the second, and `#f` otherwise.
///
/// Parameters:
/// - `args`: A `ValueList` containing two numbers.
pub fn ge(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const a = args.items[0];
    const b = args.items[1];
    if (a != .number or b != .number) return ElzError.InvalidArgument;
    return Value{ .boolean = a.number >= b.number };
}

/// `gt` is the implementation of the `>` primitive function.
/// It returns `#t` if the first argument is greater than the second, and `#f` otherwise.
///
/// Parameters:
/// - `args`: A `ValueList` containing two numbers.
pub fn gt(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const a = args.items[0];
    const b = args.items[1];
    if (a != .number or b != .number) return ElzError.InvalidArgument;
    return Value{ .boolean = a.number > b.number };
}

/// `eq_num` is the implementation of the `=` primitive function for numbers.
/// It returns `#t` if the two arguments are numerically equal, and `#f` otherwise.
///
/// Parameters:
/// - `args`: A `ValueList` containing two numbers.
pub fn eq_num(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const a = args.items[0];
    const b = args.items[1];
    if (a != .number or b != .number) return ElzError.InvalidArgument;
    return Value{ .boolean = a.number == b.number };
}

/// `sqrt` is the implementation of the `sqrt` primitive function.
/// It returns the square root of its argument.
///
/// Parameters:
/// - `args`: A `ValueList` containing a single number.
pub fn sqrt(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    if (args.items[0] != .number) return ElzError.InvalidArgument;
    return Value{ .number = std.math.sqrt(args.items[0].number) };
}

/// `sin` is the implementation of the `sin` primitive function.
/// It returns the sine of its argument.
///
/// Parameters:
/// - `args`: A `ValueList` containing a single number.
pub fn sin(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    if (args.items[0] != .number) return ElzError.InvalidArgument;
    return Value{ .number = std.math.sin(args.items[0].number) };
}

/// `cos` is the implementation of the `cos` primitive function.
/// It returns the cosine of its argument.
///
/// Parameters:
/// - `args`: A `ValueList` containing a single number.
pub fn cos(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    if (args.items[0] != .number) return ElzError.InvalidArgument;
    return Value{ .number = std.math.cos(args.items[0].number) };
}

/// `tan` is the implementation of the `tan` primitive function.
/// It returns the tangent of its argument.
///
/// Parameters:
/// - `args`: A `ValueList` containing a single number.
pub fn tan(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    if (args.items[0] != .number) return ElzError.InvalidArgument;
    return Value{ .number = std.math.tan(args.items[0].number) };
}

/// `log` is the implementation of the `log` primitive function.
/// It returns the natural logarithm of its argument.
///
/// Parameters:
/// - `args`: A `ValueList` containing a single number.
pub fn log(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    if (args.items[0] != .number) return ElzError.InvalidArgument;
    const x = args.items[0].number;
    return Value{ .number = std.math.log(f64, std.math.e, x) };
}

/// `max` is the implementation of the `max` primitive function.
/// It returns the maximum value from its arguments.
///
/// Parameters:
/// - `args`: A `ValueList` of numbers.
pub fn max(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
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

/// `min` is the implementation of the `min` primitive function.
/// It returns the minimum value from its arguments.
///
/// Parameters:
/// - `args`: A `ValueList` of numbers.
pub fn min(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
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

test "math primitives" {
    const allocator = std.testing.allocator;
    const testing = std.testing;
    var interp_stub: interpreter.Interpreter = .{
        .allocator = allocator,
        .root_env = undefined,
        .last_error_message = null,
        .module_cache = undefined,
    };
    const env_stub = try core.Environment.init(allocator, null);
    var fuel: u64 = 1000;

    // Test add
    var args = core.ValueList.init(allocator);
    try args.append(Value{ .number = 1 });
    try args.append(Value{ .number = 2 });
    var result = try add(&interp_stub, env_stub, args, &fuel);
    try testing.expect(result == Value{ .number = 3 });

    // Test sub
    args.clearRetainingCapacity();
    try args.append(Value{ .number = 5 });
    try args.append(Value{ .number = 2 });
    result = try sub(&interp_stub, env_stub, args, &fuel);
    try testing.expect(result == Value{ .number = 3 });

    // Test mul
    args.clearRetainingCapacity();
    try args.append(Value{ .number = 2 });
    try args.append(Value{ .number = 3 });
    result = try mul(&interp_stub, env_stub, args, &fuel);
    try testing.expect(result == Value{ .number = 6 });

    // Test div
    args.clearRetainingCapacity();
    try args.append(Value{ .number = 6 });
    try args.append(Value{ .number = 2 });
    result = try div(&interp_stub, env_stub, args, &fuel);
    try testing.expect(result == Value{ .number = 3 });

    // Test div by zero
    args.clearRetainingCapacity();
    try args.append(Value{ .number = 6 });
    try args.append(Value{ .number = 0 });
    const err = div(&interp_stub, env_stub, args, &fuel);
    try testing.expectError(ElzError.DivisionByZero, err);
}
