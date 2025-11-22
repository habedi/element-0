const core = @import("core.zig");
const std = @import("std");
const Value = core.Value;

/// Maximum nesting depth for printing lists to prevent stack overflow.
/// This protects against circular references and extremely deep nesting.
const MAX_PRINT_DEPTH: usize = 1000;

/// `write` prints a `Value` to the given writer in a human-readable format.
/// This function is used by the `display` and `write` primitive functions, as well as the REPL.
///
/// Parameters:
/// - `value`: The `Value` to be written.
/// - `writer`: The writer to print to. This can be any `std.io.Writer`.
pub fn write(value: Value, writer: anytype) !void {
    try writeWithDepth(value, writer, 0);
}

/// Internal function that tracks recursion depth to prevent stack overflow.
fn writeWithDepth(value: Value, writer: anytype, depth: usize) !void {
    if (depth > MAX_PRINT_DEPTH) {
        try writer.writeAll("...");
        return;
    }

    switch (value) {
        .symbol => |s| try writer.print("{s}", .{s}),
        .number => |n| try writer.print("{d}", .{n}),
        .boolean => |b| try writer.writeAll(if (b) "#t" else "#f"),
        .nil => try writer.writeAll("()"),
        .character => |c| {
            try writer.writeAll("#\\");
            switch (c) {
                ' ' => try writer.writeAll("space"),
                '\n' => try writer.writeAll("newline"),
                else => {
                    if (c > 0x10FFFF) {
                        try writer.writeAll("invalid-char");
                        return;
                    }

                    const codepoint: u21 = @intCast(c);
                    if (!std.unicode.utf8ValidCodepoint(codepoint)) {
                        try writer.writeAll("invalid-char");
                        return;
                    }

                    var buf: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(codepoint, &buf) catch {
                        try writer.writeAll("invalid-char");
                        return;
                    };
                    try writer.writeAll(buf[0..@as(usize, @intCast(len))]);
                },
            }
        },
        .string => |s| {
            try writer.print("\"{s}\"", .{s});
        },
        .pair => |p| {
            try writer.writeAll("(");
            var current = p;
            var list_depth: usize = 0;
            while (true) {
                if (list_depth > MAX_PRINT_DEPTH) {
                    try writer.writeAll("...");
                    break;
                }
                try writeWithDepth(current.car, writer, depth + 1);
                switch (current.cdr) {
                    .pair => |next_p| {
                        try writer.writeAll(" ");
                        current = next_p;
                        list_depth += 1;
                    },
                    .nil => {
                        break;
                    },
                    else => {
                        try writer.writeAll(" . ");
                        try writeWithDepth(current.cdr, writer, depth + 1);
                        break;
                    },
                }
            }
            try writer.writeAll(")");
        },
        .closure => try writer.writeAll("#<closure>"),
        .procedure => try writer.writeAll("#<procedure>"),
        .foreign_procedure => try writer.writeAll("#<foreign-procedure>"),
        .opaque_pointer => try writer.writeAll("#<opaque-pointer>"),
        .cell => try writer.writeAll("#<cell>"),
        .module => try writer.writeAll("#<module>"),
        .unspecified => try writer.writeAll("#<unspecified>"),
    }
}
