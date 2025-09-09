//! This module implements primitive procedures for string, symbol, and character manipulation.

const std = @import("std");
const core = @import("../core.zig");
const Value = core.Value;
const ElzError = @import("../errors.zig").ElzError;

/// The `symbol->string` primitive procedure.
/// Converts a symbol to a string.
pub fn symbol_to_string(env: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    const sym = args.items[0];
    if (sym != .symbol) return ElzError.InvalidArgument;
    const str = try env.allocator.dupe(u8, sym.symbol);
    return Value{ .string = str };
}

/// The `string->symbol` primitive procedure.
/// Converts a string to a symbol.
pub fn string_to_symbol(env: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    const str = args.items[0];
    if (str != .string) return ElzError.InvalidArgument;
    const sym = try env.allocator.dupe(u8, str.string);
    return Value{ .symbol = sym };
}

/// The `string-length` primitive procedure.
/// Returns the number of characters in a string.
pub fn string_length(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    const str = args.items[0];
    if (str != .string) return ElzError.InvalidArgument;
    // Note: This function can return an error if the string is not valid UTF-8.
    const len = try std.unicode.utf8CountCodepoints(str.string);
    return Value{ .number = @floatFromInt(len) };
}

/// The `char=?` primitive procedure.
/// Checks if two characters are equal.
pub fn char_eq(_: *core.Environment, args: core.ValueList) !Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const a = args.items[0];
    const b = args.items[1];
    if (a != .character or b != .character) return ElzError.InvalidArgument;
    return Value{ .boolean = a.character == b.character };
}
