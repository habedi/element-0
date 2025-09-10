const std = @import("std");
const core = @import("../core.zig");
const ElzError = @import("../errors.zig").ElzError;
const interpreter = @import("../interpreter.zig");

pub fn exit(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!core.Value {
    if (args.items.len != 1) {
        return ElzError.WrongArgumentCount;
    }
    const code = args.items[0];
    if (code != .number) {
        return ElzError.InvalidArgument;
    }
    std.process.exit(@intFromFloat(code.number));
}
