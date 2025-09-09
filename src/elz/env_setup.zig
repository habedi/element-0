//! This module provides functions to set up the initial interpreter environment.
//! It populates the environment with primitive procedures.

const core = @import("core.zig");
const ffi = @import("ffi.zig");
const lists = @import("./primitives/lists.zig");
const math = @import("./primitives/math.zig");
const predicates = @import("./primitives/predicates.zig");
const strings = @import("./primitives/strings.zig");
const control = @import("./primitives/control.zig");
const io = @import("./primitives/io.zig");

/// Populates the environment with mathematical procedures.
pub fn populate_math(env: *core.Environment) !void {
    try env.set("+", core.Value{ .procedure = math.add });
    try env.set("-", core.Value{ .procedure = math.sub });
    try env.set("*", core.Value{ .procedure = math.mul });
    try env.set("/", core.Value{ .procedure = math.div });
    try env.set("<=", core.Value{ .procedure = math.le });
    try env.set("<", core.Value{ .procedure = math.lt });
    try env.set(">=", core.Value{ .procedure = math.ge });
    try env.set(">", core.Value{ .procedure = math.gt });
    try env.set("=", core.Value{ .procedure = math.eq_num });
    try env.set("sqrt", core.Value{ .procedure = math.sqrt });
    try env.set("sin", core.Value{ .procedure = math.sin });
    try env.set("cos", core.Value{ .procedure = math.cos });
    try env.set("tan", core.Value{ .procedure = math.tan });
    try env.set("log", core.Value{ .procedure = math.log });
}

/// Populates the environment with list manipulation procedures.
pub fn populate_lists(env: *core.Environment) !void {
    try env.set("cons", core.Value{ .procedure = lists.cons });
    try env.set("car", core.Value{ .procedure = lists.car });
    try env.set("cdr", core.Value{ .procedure = lists.cdr });
    try env.set("list", core.Value{ .procedure = lists.list });
    try env.set("length", core.Value{ .procedure = lists.list_length });
    try env.set("append", core.Value{ .procedure = lists.append });
    try env.set("reverse", core.Value{ .procedure = lists.reverse });
    try env.set("map", core.Value{ .procedure = lists.map });
}

/// Populates the environment with type predicate procedures.
pub fn populate_predicates(env: *core.Environment) !void {
    try env.set("null?", core.Value{ .procedure = predicates.is_null });
    try env.set("boolean?", core.Value{ .procedure = predicates.is_boolean });
    try env.set("symbol?", core.Value{ .procedure = predicates.is_symbol });
    try env.set("number?", core.Value{ .procedure = predicates.is_number });
    try env.set("list?", core.Value{ .procedure = predicates.is_list });
    try env.set("pair?", core.Value{ .procedure = predicates.is_pair });

    try env.set("eq?", core.Value{ .procedure = predicates.is_eq });
    try env.set("eqv?", core.Value{ .procedure = predicates.is_eqv });
    try env.set("equal?", core.Value{ .procedure = predicates.is_equal });
}

/// Populates the environment with string and symbol procedures.
pub fn populate_strings(env: *core.Environment) !void {
    try env.set("symbol->string", core.Value{ .procedure = strings.symbol_to_string });
    try env.set("string->symbol", core.Value{ .procedure = strings.string_to_symbol });
    try env.set("string-length", core.Value{ .procedure = strings.string_length });
    try env.set("char=?", core.Value{ .procedure = strings.char_eq });
}

/// Populates the environment with control procedures.
pub fn populate_control(env: *core.Environment) !void {
    try env.set("apply", core.Value{ .procedure = control.apply });
}

/// Populates the environment with I/O procedures.
pub fn populate_io(env: *core.Environment) !void {
    try env.set("display", core.Value{ .procedure = io.display });
    try env.set("write", core.Value{ .procedure = io.write_proc });
    try env.set("newline", core.Value{ .procedure = io.newline });
    try env.set("load", core.Value{ .procedure = io.load });
}

/// Populates the environment with all global procedures.
pub fn populate_globals(env: *core.Environment) !void {
    try populate_math(env);
    try populate_lists(env);
    try populate_predicates(env);
    try populate_strings(env);
    try populate_control(env);
    try populate_io(env);
}

/// Defines a foreign function in the given environment.
pub fn define_foreign_func(env: *core.Environment, name: []const u8, comptime func: anytype) !void {
    const ff = ffi.makeForeignFunc(func);
    try env.set(name, core.Value{ .foreign_procedure = ff });
}
