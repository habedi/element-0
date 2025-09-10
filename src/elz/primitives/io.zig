const std = @import("std");
const core = @import("../core.zig");
const writer = @import("../writer.zig");
const parser = @import("../parser.zig");
const eval = @import("../eval.zig");
const Value = core.Value;
const ElzError = @import("../errors.zig").ElzError;
const interpreter = @import("../interpreter.zig");

pub fn display(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    const stdout = std.io.getStdOut().writer();
    const aw = stdout.any();
    const value = args.items[0];

    switch (value) {
        .string => |s| aw.writeAll(s) catch return ElzError.ForeignFunctionError,
        .character => |c| {
            if (c > 0x10FFFF) return ElzError.InvalidArgument;

            const codepoint: u21 = @intCast(c);
            if (!std.unicode.utf8ValidCodepoint(codepoint)) {
                return ElzError.InvalidArgument;
            }

            var buf: [4]u8 = undefined;
            const len = std.unicode.utf8Encode(codepoint, &buf) catch {
                return ElzError.InvalidArgument;
            };
            aw.writeAll(buf[0..@as(usize, @intCast(len))]) catch return ElzError.ForeignFunctionError;
        },
        else => writer.write(value, stdout) catch return ElzError.ForeignFunctionError,
    }
    return Value.unspecified;
}

pub fn write_proc(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    const stdout = std.io.getStdOut().writer();
    writer.write(args.items[0], stdout) catch return ElzError.ForeignFunctionError;
    return Value.unspecified;
}

pub fn newline(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 0) return ElzError.WrongArgumentCount;
    const stdout = std.io.getStdOut().writer();
    const aw = stdout.any();
    aw.print("\n", .{}) catch return ElzError.ForeignFunctionError;
    return Value.unspecified;
}

pub fn load(interp: *interpreter.Interpreter, env: *core.Environment, args: core.ValueList, fuel: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    const filename_val = args.items[0];
    if (filename_val != .string) return ElzError.InvalidArgument;

    const filename = filename_val.string;
    const file = std.fs.cwd().openFile(filename, .{}) catch |err| {
        interp.last_error_message = std.fmt.allocPrint(interp.allocator, "Failed to load file '{s}': {s}", .{ filename, @errorName(err) }) catch null;
        return ElzError.ForeignFunctionError;
    };
    defer file.close();

    const source = file.readToEndAlloc(env.allocator, 1 * 1024 * 1024) catch return ElzError.OutOfMemory;
    defer env.allocator.free(source);

    const forms = parser.readAll(source, env.allocator) catch |e| return e;
    if (forms.items.len == 0) return Value.unspecified;

    var last_result: Value = .unspecified;
    for (forms.items) |form| {
        last_result = try eval.eval(interp, &form, env, fuel);
    }

    return if (last_result == .unspecified) Value.unspecified else last_result;
}
