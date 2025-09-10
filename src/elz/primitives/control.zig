const std = @import("std");
const core = @import("../core.zig");
const eval = @import("../eval.zig");
const ElzError = @import("../errors.zig").ElzError;
const interpreter = @import("../interpreter.zig");

/// `apply` is the implementation of the `apply` primitive function in Elz.
/// It applies a procedure to a list of arguments. The last argument to `apply`
/// must be a list, which is then used as the arguments to the procedure.
///
/// For example: `(apply + '(1 2 3))` is equivalent to `(+ 1 2 3)`.
///
/// Parameters:
/// - `interp`: A pointer to the interpreter instance.
/// - `env`: The environment in which to apply the procedure.
/// - `args`: The arguments to `apply`, where the first argument is the procedure
///           and the last argument is the list of arguments for that procedure.
/// - `fuel`: A pointer to the execution fuel counter.
///
/// Returns:
/// The result of applying the procedure, or an error if the application fails.
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

test "control primitives" {
    const allocator = std.testing.allocator;
    const testing = std.testing;
    var interp = interpreter.Interpreter.init(allocator);
    defer interp.deinit();

    var fuel: u64 = 1000;

    // Test apply
    const source = "(lambda (x y) (+ x y))";
    const proc_val = try eval.eval(&interp, &try interp.read(source), interp.root_env, &fuel);

    var args = core.ValueList.init(allocator);
    try args.append(proc_val);
    try args.append(core.Value{ .number = 1 });

    const p = try allocator.create(core.Pair);
    p.* = .{ .car = core.Value{ .number = 2 }, .cdr = .nil };
    try args.append(core.Value{ .pair = p });

    const result = try apply(&interp, interp.root_env, args, &fuel);
    try testing.expect(result.number == 3);
}
