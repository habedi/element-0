//! This module provides the `write` function for converting Element 0 values
//! into their string representations.

const core = @import("core.zig");
const std = @import("std");
const Value = core.Value;

/// Writes a string representation of a `Value` to the given writer.
/// This function is the equivalent of `print` or `display` in other Lisp dialects.
///
/// - `value`: The `Value` to write.
/// - `writer`: The `std.io.Writer` to write to.
pub fn write(value: Value, writer: anytype) !void {
    const aw = writer.any();
    switch (value) {
        .symbol => |s| try aw.print("{s}", .{s}),
        .number => |n| try aw.print("{d}", .{n}),
        .boolean => |b| try aw.writeAll(if (b) "#t" else "#f"),
        .nil => try aw.print("()", .{}),
        .character => |c| {
            try aw.writeAll("#\\");
            switch (c) {
                ' ' => try aw.writeAll("space"),
                '\n' => try aw.writeAll("newline"),
                else => {
                    // First, check if the u32 is in the valid Unicode range.
                    if (c > 0x10FFFF) {
                        try aw.writeAll("invalid-char");
                        return;
                    }

                    // Then, cast to u21 and check if it's a surrogate.
                    const codepoint: u21 = @intCast(c);
                    if (!std.unicode.utf8ValidCodepoint(codepoint)) {
                        try aw.writeAll("invalid-char");
                        return;
                    }

                    // Encode the character to a UTF-8 byte slice.
                    var buf: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(codepoint, &buf) catch {
                        try aw.writeAll("invalid-char");
                        return;
                    };
                    try aw.writeAll(buf[0..@as(usize, @intCast(len))]);
                },
            }
        },
        .string => |s| {
            // TODO: escape internal quotes
            try aw.print("\"{s}\"", .{s});
        },
        .pair => |p| {
            try aw.print("(", .{});
            var current = p;
            while (true) {
                try write(current.car, writer);
                switch (current.cdr) {
                    .pair => |next_p| {
                        try aw.print(" ", .{});
                        current = next_p;
                    },
                    .nil => {
                        break;
                    },
                    else => {
                        try aw.print(" . ", .{});
                        try write(current.cdr, writer);
                        break;
                    },
                }
            }
            try aw.print(")", .{});
        },
        .closure => try aw.print("#<closure>", .{}),
        .procedure => try aw.print("#<procedure>", .{}),
        .foreign_procedure => try aw.print("#<foreign-procedure>", .{}),
        .opaque_pointer => try aw.print("#<opaque-pointer>", .{}),
        .unspecified => try aw.print("#<unspecified>", .{}),
    }
}
