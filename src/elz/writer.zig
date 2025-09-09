//! This module provides the `write` function for converting Element 0 values
//! into their string representations.

const core = @import("core.zig");
const Value = core.Value;

/// Writes a string representation of a `Value` to the given writer.
pub fn write(value: Value, writer: anytype) !void {
    switch (value) {
        .symbol => |s| try writer.print("{s}", .{s}),
        .number => |n| try writer.print("{d}", .{n}),
        .boolean => |b| try writer.writeAll(if (b) "#t" else "#f"),
        .nil => try writer.print("()", .{}),
        .character => |c| {
            try writer.print("#\\<{d}>", .{c});
        },
        .string => |s| {
            try writer.writeByte('"');
            var i: usize = 0;
            while (i < s.len) {
                switch (s[i]) {
                    '\\' => try writer.writeAll("\\\\"),
                    '"' => try writer.writeAll("\\\""),
                    '\n' => try writer.writeAll("\\n"),
                    '\t' => try writer.writeAll("\\t"),
                    else => try writer.writeByte(s[i]),
                }
                i += 1;
            }
            try writer.writeByte('"');
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
