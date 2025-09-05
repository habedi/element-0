//! This module provides the `write` function for converting Element 0 values
//! into their string representations.

const core = @import("core.zig");
const Value = core.Value;

/// Writes a string representation of a `Value` to the given writer.
/// This function is the equivalent of `print` or `display` in other Lisp dialects.
///
/// - `value`: The `Value` to write.
/// - `writer`: The `std.io.Writer` to write to.
pub fn write(value: Value, writer: anytype) !void {
    switch (value) {
        .symbol => |s| try writer.print("{s}", .{s}),
        .number => |n| try writer.print("{d}", .{n}),
        .boolean => |b| try writer.writeAll(if (b) "#t" else "#f"),
        .nil => try writer.print("()", .{}),
        .character => |c| {
            // TODO: A suspected compiler bug in Zig 0.14.1 prevents correct UTF-8 printing here.
            // Printing the codepoint value as a workaround.
            try writer.print("#\\<{d}>", .{c});
        },
        .string => |s| {
            // TODO: escape internal quotes
            try writer.print("\"{s}\"", .{s});
        },
        .pair => |p| {
            try writer.print("(", .{});
            var current = p;
            while (true) {
                try write(current.car, writer);
                switch (current.cdr) {
                    .pair => |next_p| {
                        try writer.print(" ", .{});
                        current = next_p;
                    },
                    .nil => {
                        break;
                    },
                    else => {
                        try writer.print(" . ", .{});
                        try write(current.cdr, writer);
                        break;
                    },
                }
            }
            try writer.print(")", .{});
        },
        .closure => try writer.print("#<closure>", .{}),
        .procedure => try writer.print("#<procedure>", .{}),
        .foreign_procedure => try writer.print("#<foreign-procedure>", .{}),
        .opaque_pointer => try writer.print("#<opaque-pointer>", .{}),
    }
}
