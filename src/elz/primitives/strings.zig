const std = @import("std");
const core = @import("../core.zig");
const Value = core.Value;
const ElzError = @import("../errors.zig").ElzError;
const interpreter = @import("../interpreter.zig");

pub fn symbol_to_string(_: *interpreter.Interpreter, env: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    const sym = args.items[0];
    if (sym != .symbol) return ElzError.InvalidArgument;
    const str = try env.allocator.dupe(u8, sym.symbol);
    return Value{ .string = str };
}

pub fn string_to_symbol(_: *interpreter.Interpreter, env: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    const str = args.items[0];
    if (str != .string) return ElzError.InvalidArgument;
    const sym = try env.allocator.dupe(u8, str.string);
    return Value{ .symbol = sym };
}

pub fn string_length(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 1) return ElzError.WrongArgumentCount;
    const str = args.items[0];
    if (str != .string) return ElzError.InvalidArgument;
    const len = std.unicode.utf8CountCodepoints(str.string) catch return ElzError.InvalidArgument;
    return Value{ .number = @floatFromInt(len) };
}

pub fn string_append(_: *interpreter.Interpreter, env: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    var buffer = std.ArrayList(u8).init(env.allocator);
    defer buffer.deinit();

    for (args.items) |arg| {
        switch (arg) {
            .string => |s| try buffer.appendSlice(s),
            else => return ElzError.InvalidArgument,
        }
    }

    return Value{ .string = try buffer.toOwnedSlice() };
}

pub fn char_eq(_: *interpreter.Interpreter, _: *core.Environment, args: core.ValueList, _: *u64) ElzError!Value {
    if (args.items.len != 2) return ElzError.WrongArgumentCount;
    const a = args.items[0];
    const b = args.items[1];
    if (a != .character or b != .character) return ElzError.InvalidArgument;
    return Value{ .boolean = a.character == b.character };
}

test "string primitives" {
    const allocator = std.testing.allocator;
    const testing = std.testing;
    var interp = interpreter.Interpreter.init(allocator);
    defer interp.deinit();
    var fuel: u64 = 1000;

    // Test symbol->string
    var args = core.ValueList.init(allocator);
    try args.append(Value{ .symbol = "foo" });
    var result = try symbol_to_string(&interp, interp.root_env, args, &fuel);
    try testing.expect(result == Value{ .string = "foo" });

    // Test string->symbol
    args.clearRetainingCapacity();
    try args.append(Value{ .string = "bar" });
    result = try string_to_symbol(&interp, interp.root_env, args, &fuel);
    try testing.expect(result == Value{ .symbol = "bar" });

    // Test string-length
    args.clearRetainingCapacity();
    try args.append(Value{ .string = "hello" });
    result = try string_length(&interp, interp.root_env, args, &fuel);
    try testing.expect(result == Value{ .number = 5 });

    // Test char=?
    args.clearRetainingCapacity();
    try args.append(Value{ .character = 'a' });
    try args.append(Value{ .character = 'a' });
    result = try char_eq(&interp, interp.root_env, args, &fuel);
    try testing.expect(result == Value{ .boolean = true });
}
