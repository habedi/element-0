const std = @import("std");
const core = @import("../core.zig");
const Value = core.Value;
const ElzError = @import("../errors.zig").ElzError;
const interpreter = @import("../interpreter.zig");

pub fn module_ref(interp: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;

    const module_val = args.items[0];
    const symbol_val = args.items[1];

    if (module_val != .module) {
        interp.last_error_message = "First argument to module-ref must be a module object.";
        return ElzError.InvalidArgument;
    }
    if (symbol_val != .symbol) {
        interp.last_error_message = "Second argument to module-ref must be a symbol.";
        return ElzError.InvalidArgument;
    }

    const module = module_val.module;
    const name = symbol_val.symbol;

    if (module.exports.get(name)) |value| {
        return value;
    } else {
        interp.last_error_message = std.fmt.allocPrint(interp.allocator, "Module does not export symbol '{s}'.", .{name}) catch null;
        return ElzError.SymbolNotFound;
    }
}
