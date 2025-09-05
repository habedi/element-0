const std = @import("std");
const elz = @import("elz");

fn sum_of_squares(
    allocator: std.mem.Allocator,
    args: []const elz.Value,
) !elz.Value {
    _ = allocator;

    if (args.len != 1) {
        return elz.ElzError.WrongArgumentCount;
    }

    var sum: f64 = 0.0;
    var current_node = args[0];

    while (current_node != .nil) {
        const p = switch (current_node) {
            .pair => |pair_val| pair_val,
            else => return elz.ElzError.InvalidArgument,
        };

        const num = switch (p.car) {
            .number => |n| n,
            else => return elz.ElzError.InvalidArgument,
        };

        sum += num * num;

        current_node = p.cdr;
    }

    return elz.Value{ .number = sum };
}

pub fn main() !void {
    var interpreter = try elz.Interpreter.init(.{});

    try elz.env_setup.define_foreign_func(interpreter.root_env, "sum-of-squares", sum_of_squares);

    const source = "(sum-of-squares (quote (1 2 3 4)))";
    std.debug.print("Evaluating: {s}\n", .{source});

    var fuel: u64 = 1000;
    const result = try interpreter.evalString(source, &fuel);

    const stdout = std.io.getStdOut().writer();
    try elz.write(result, stdout);
    try stdout.print("\n", .{});
}
