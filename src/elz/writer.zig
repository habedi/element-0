const core = @import("core.zig");
const std = @import("std");
const Value = core.Value;

/// `write` prints a `Value` to the given writer in a human-readable format.
/// This function is used by the `display` and `write` primitive functions, as well as the REPL.
///
/// Parameters:
/// - `value`: The `Value` to be written.
/// - `writer`: The writer to print to. This can be any `std.io.Writer`.
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
                    if (c > 0x10FFFF) {
                        try aw.writeAll("invalid-char");
                        return;
                    }

                    const codepoint: u21 = @intCast(c);
                    if (!std.unicode.utf8ValidCodepoint(codepoint)) {
                        try aw.writeAll("invalid-char");
                        return;
                    }

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
        .cell => try aw.print("#<cell>", .{}),
        .module => try aw.print("#<module>", .{}),
        .unspecified => try aw.print("#<unspecified>", .{}),
    }
}
