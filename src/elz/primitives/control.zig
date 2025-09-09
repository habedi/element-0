//! This module implements control-related primitive procedures.

const std = @import("std");
const core = @import("../core.zig");
const eval = @import("../eval.zig");
const ElzError = @import("../errors.zig").ElzError;

/// The `apply` primitive procedure.
/// Applies a procedure to a list of arguments.
///
/// - `env`: The environment.
/// - `args`: The arguments, where the last argument is a list of arguments for the procedure.
/// - `return`: The result of the procedure call.
pub fn apply(env: *core.Environment, args: core.ValueList) !core.Value {
    if (args.items.len < 2) return ElzError.WrongArgumentCount;

    const proc = args.items[0];
    const last_arg = args.items[args.items.len - 1];

    var final_args = core.ValueList.init(env.allocator);
    // Add all arguments except the last one.
    for (args.items[1 .. args.items.len - 1]) |arg| {
        try final_args.append(arg);
    }

    // Unpack the last argument, which must be a list.
    var current_node = last_arg;
    while (current_node != .nil) {
        const p = switch (current_node) {
            .pair => |pair_val| pair_val,
            else => return ElzError.InvalidArgument, // Last arg must be a proper list
        };
        try final_args.append(p.car);
        current_node = p.cdr;
    }

    var fuel: u64 = 1_000_000; // Fuel for the applied call
    return eval.eval_proc(proc, final_args, env, &fuel);
}
