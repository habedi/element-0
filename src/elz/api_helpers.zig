//! This module provides helper functions for the public API, especially for FFI.

const std = @import("std");
const core = @import("./core.zig");
const ElzError = @import("./errors.zig").ElzError;
const Value = core.Value;

/// Converts an Element 0 proper list to a Zig slice of `Value`s.
/// This function is useful for converting data from Elz to a format that is easier to work with in Zig.
///
/// Parameters:
/// - `allocator`: The memory allocator to use for the new slice.
/// - `list_head`: The head of the Element 0 list, which must be a proper list (ending in `nil`).
///
/// Returns:
/// A new slice containing the values from the list, or an error if the input is not a proper list.
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

/// Converts a Zig slice of `Value`s to an Element 0 proper list.
/// This function is useful for creating Element 0 lists in Zig to be passed to Elz.
///
/// Parameters:
/// - `allocator`: The memory allocator to use for allocating the pairs of the new list.
/// - `slice`: The slice of `Value`s to convert.
///
/// Returns:
/// The head of a new Element 0 list as a `Value`, or an error if allocation fails.
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
