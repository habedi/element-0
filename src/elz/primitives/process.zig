const std = @import("std");
const core = @import("../core.zig");
const ElzError = @import("../errors.zig").ElzError;
const interpreter = @import("../interpreter.zig");

/// `exit` is the implementation of the `exit` primitive function.
/// It terminates the current process with the given exit code.
///
/// Parameters:
/// - `args`: A `ValueList` containing a single number, the exit code.
///           The exit code must be an integer in the range [0, 255].
pub fn exit(interp: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!core.Value {
    if (args.items.len != 1) {
        return ElzError.WrongArgumentCount;
    }
    const code = args.items[0];
    if (code != .number) {
        return ElzError.InvalidArgument;
    }

    const num = code.number;

    // Check for NaN or Infinity
    if (std.math.isNan(num) or std.math.isInf(num)) {
        interp.last_error_message = "Exit code must be a finite number.";
        return ElzError.InvalidArgument;
    }

    // Check range [0, 255]
    if (num < 0 or num > 255) {
        interp.last_error_message = "Exit code must be in the range [0, 255].";
        return ElzError.InvalidArgument;
    }

    // Check for fractional part
    if (@floor(num) != num) {
        interp.last_error_message = "Exit code must be an integer.";
        return ElzError.InvalidArgument;
    }

    std.process.exit(@intFromFloat(num));
}
