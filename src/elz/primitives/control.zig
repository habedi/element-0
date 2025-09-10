const std = @import("std");
const core = @import("../core.zig");
const eval = @import("../eval.zig");
const ElzError = @import("../errors.zig").ElzError;
const interpreter = @import("../interpreter.zig");

pub fn apply(interp: *interpreter.Interpreter, env: *core.Environment, args: core.ValueList, fuel: *u64) ElzError!core.Value {
    if (args.items.len < 2) return ElzError.WrongArgumentCount;

    const proc = args.items[0];
    const last_arg = args.items[args.items.len - 1];

    var final_args = core.ValueList.init(env.allocator);
    for (args.items[1 .. args.items.len - 1]) |item| {
        try final_args.append(item);
    }

    var current_node = last_arg;
    while (current_node != .nil) {
        const p = switch (current_node) {
            .pair => |pair_val| pair_val,
            else => return ElzError.InvalidArgument,
        };
        try final_args.append(p.car);
        current_node = p.cdr;
    }

    return eval.eval_proc(interp, proc, final_args, env, fuel);
}
