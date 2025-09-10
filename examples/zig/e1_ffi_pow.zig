const std = @import("std");
const elz = @import("elz");

fn zig_pow(base: f64, exp: f64) f64 {
    return std.math.pow(f64, base, exp);
}

pub fn main() !void {
    var interpreter = try elz.Interpreter.init(.{});
    try elz.env_setup.define_foreign_func(interpreter.root_env, "zig-pow", zig_pow);
    const source = "(zig-pow 2 8)";
    std.debug.print("Evaluating Element 0 code: {s}\n", .{source});
    var fuel: u64 = 1000;
    const result = try interpreter.evalString(source, &fuel);
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: ", .{});
    try elz.write(result, stdout);
    try stdout.print("\n", .{});
}
