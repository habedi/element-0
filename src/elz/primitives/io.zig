//! This module implements primitive procedures for I/O.

const std = @import("std");
const core = @import("../core.zig");
const writer = @import("../writer.zig");
const parser = @import("../parser.zig");
const eval = @import("../eval.zig");
const Value = core.Value;
const ElzError = @import("../errors.zig").ElzError;

// A custom writer logic for the `display` primitive.
// It prints strings without quotes and handles Unicode character encoding safely.
fn display_writer(value: Value, w: anytype) !void {
    switch (value) {
        .string => |s| try w.writeAll(s),
        .character => {
            const codepoint = value.character;
            // The value must be a valid Unicode scalar value.
            if (codepoint > 0x10FFFF or (codepoint >= 0xD800 and codepoint <= 0xDFFF)) {
                // If the codepoint is invalid, print the standard replacement character.
                try w.print("", .{});
                return;
            }

            var buf: [4]u8 = undefined;
            // utf8Encode returns the number of bytes written to the buffer.
            const len = std.unicode.utf8Encode(@intCast(codepoint), &buf) catch unreachable;

            // Use the returned length to create a slice of the valid bytes.
            try w.writeAll(buf[0..len]);
        },
        else => try writer.write(value, w),
    }
}

/// The `display` primitive procedure.
/// Prints an object to standard output in a human-readable format.
pub fn display(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    const stdout = std.io.getStdOut().writer();
    try display_writer(args.items[0], stdout);
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
    try stdout.print("\n", .{});
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
        // We can use std.log for richer error messages on the host side.
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
