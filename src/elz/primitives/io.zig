//! This module implements the I/O primitives.
const std = @import("std");
const core = @import("../core.zig");
const writer = @import("../writer.zig");
const parser = @import("../parser.zig");
const eval = @import("../eval.zig");
const Value = core.Value;
const ElzError = @import("../errors.zig").ElzError;

/// The `display` primitive procedure.
/// Prints an object to standard output in a human-readable format.
/// Strings and characters are printed directly without formatting.
pub fn display(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    const stdout = std.io.getStdOut().writer();
    const aw = stdout.any();
    const value = args.items[0];

    switch (value) {
        .string => |s| try aw.writeAll(s),
        .character => |c| {
            // First, check if the u32 is in the valid Unicode range.
            if (c > 0x10FFFF) return ElzError.InvalidArgument;

            // Then, cast to u21 and check if it's a surrogate.
            const codepoint: u21 = @intCast(c);
            if (!std.unicode.utf8ValidCodepoint(codepoint)) {
                return ElzError.InvalidArgument;
            }

            var buf: [4]u8 = undefined;
            const len = std.unicode.utf8Encode(codepoint, &buf) catch {
                return ElzError.InvalidArgument;
            };
            try aw.writeAll(buf[0..@as(usize, @intCast(len))]);
        },
        // For other types, display falls back to the machine-readable format.
        else => try writer.write(value, stdout),
    }
    return Value.unspecified;
}

/// The `write` primitive procedure.
/// Prints an object to standard output in a machine-readable format.
pub fn write_proc(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    const stdout = std.io.getStdOut().writer();
    try writer.write(args.items[0], stdout);
    return Value.unspecified;
}

/// The `newline` primitive procedure.
/// Prints a newline character to standard output.
pub fn newline(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 0) return ElzError.WrongArgumentCount;
    const stdout = std.io.getStdOut().writer();
    const aw = stdout.any();
    try aw.print("\n", .{});
    return Value.unspecified;
}

/// The `load` primitive procedure.
/// Reads and evaluates all expressions from a file.
pub fn load(env: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    const filename_val = args.items[0];
    if (filename_val != .string) return ElzError.InvalidArgument;

    const filename = filename_val.string;
    const file = std.fs.cwd().openFile(filename, .{}) catch |err| {
        std.log.err("failed to load file '{s}': {s}", .{ filename, @errorName(err) });
        return ElzError.ForeignFunctionError;
    };
    defer file.close();

    const source = try file.readToEndAlloc(env.allocator, 1 * 1024 * 1024); // 1MB file limit
    defer env.allocator.free(source);

    const forms = try parser.readAll(source, env.allocator);
    if (forms.items.len == 0) return Value.unspecified;

    var last_result: Value = .unspecified;
    for (forms.items) |form| {
        var fuel: u64 = 1_000_000; // Give each loaded file a fresh fuel budget.
        last_result = try eval.eval(&form, env, &fuel);
    }

    // Only return the last result if it's not unspecified, otherwise keep it unspecified.
    return if (last_result == .unspecified) Value.unspecified else last_result;
}
