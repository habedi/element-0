//! This module provides helper functions for the public API, especially for FFI.

const std = @import("std");
const core = @import("./core.zig");
const ElzError = @import("./errors.zig").ElzError;
const Value = core.Value;

/// Converts a Lisp proper list to a Zig slice.
/// The returned slice is allocated using the provided allocator.
///
/// - `allocator`: The memory allocator to use for the new slice.
/// - `list_head`: The head of the Lisp list (`.pair` or `.nil`).
/// - `return`: A new slice containing the values from the list.
pub fn listToSlice(allocator: std.mem.Allocator, list_head: Value) ![]Value {
    var items = std.ArrayList(Value).init(allocator);

    var current_node = list_head;
    while (current_node != .nil) {
        const p = switch (current_node) {
            .pair => |pair_val| pair_val,
            else => return ElzError.InvalidArgument, // Not a proper list
        };
        try items.append(p.car);
        current_node = p.cdr;
    }
    return items.toOwnedSlice();
}

/// Converts a Zig slice of Values to a Lisp proper list.
/// New pairs are allocated using the provided allocator.
///
/// - `allocator`: The memory allocator to use for the list pairs.
/// - `slice`: The slice of values to convert.
/// - `return`: The head of a new Lisp list.
pub fn sliceToList(allocator: std.mem.Allocator, slice: []const Value) !Value {
    var head: Value = .nil;
    var i = slice.len;
    while (i > 0) {
        i -= 1;
        const p = try allocator.create(core.Pair);
        p.* = .{
            .car = slice[i],
            .cdr = head,
        };
        head = Value{ .pair = p };
    }
    return head;
}
