const core = @import("core.zig");
const ffi = @import("ffi.zig");
const lists = @import("./primitives/lists.zig");
const math = @import("./primitives/math.zig");
const predicates = @import("./primitives/predicates.zig");
const strings = @import("./primitives/strings.zig");
const control = @import("./primitives/control.zig");
const io = @import("./primitives/io.zig");
const modules = @import("./primitives/modules.zig");
const process = @import("./primitives/process.zig");
const interpreter = @import("interpreter.zig");

/// Populates the interpreter's root environment with mathematical primitive functions.
///
/// Parameters:
/// - `interp`: A pointer to the interpreter instance.
pub fn populate_math(interp: *interpreter.Interpreter) !void {
    try interp.root_env.set(interp, "+", core.Value{ .procedure = math.add });
    try interp.root_env.set(interp, "-", core.Value{ .procedure = math.sub });
    try interp.root_env.set(interp, "*", core.Value{ .procedure = math.mul });
    try interp.root_env.set(interp, "/", core.Value{ .procedure = math.div });
    try interp.root_env.set(interp, "<=", core.Value{ .procedure = math.le });
    try interp.root_env.set(interp, "<", core.Value{ .procedure = math.lt });
    try interp.root_env.set(interp, ">=", core.Value{ .procedure = math.ge });
    try interp.root_env.set(interp, ">", core.Value{ .procedure = math.gt });
    try interp.root_env.set(interp, "=", core.Value{ .procedure = math.eq_num });
    try interp.root_env.set(interp, "sqrt", core.Value{ .procedure = math.sqrt });
    try interp.root_env.set(interp, "sin", core.Value{ .procedure = math.sin });
    try interp.root_env.set(interp, "cos", core.Value{ .procedure = math.cos });
    try interp.root_env.set(interp, "tan", core.Value{ .procedure = math.tan });
    try interp.root_env.set(interp, "log", core.Value{ .procedure = math.log });
    try interp.root_env.set(interp, "max", core.Value{ .procedure = math.max });
    try interp.root_env.set(interp, "min", core.Value{ .procedure = math.min });
}

/// Populates the interpreter's root environment with list manipulation primitive functions.
///
/// Parameters:
/// - `interp`: A pointer to the interpreter instance.
pub fn populate_lists(interp: *interpreter.Interpreter) !void {
    try interp.root_env.set(interp, "cons", core.Value{ .procedure = lists.cons });
    try interp.root_env.set(interp, "car", core.Value{ .procedure = lists.car });
    try interp.root_env.set(interp, "cdr", core.Value{ .procedure = lists.cdr });
    try interp.root_env.set(interp, "list", core.Value{ .procedure = lists.list });
    try interp.root_env.set(interp, "length", core.Value{ .procedure = lists.list_length });
    try interp.root_env.set(interp, "append", core.Value{ .procedure = lists.append });
    try interp.root_env.set(interp, "reverse", core.Value{ .procedure = lists.reverse });
    try interp.root_env.set(interp, "map", core.Value{ .procedure = lists.map });
}

/// Populates the interpreter's root environment with predicate primitive functions.
///
/// Parameters:
/// - `interp`: A pointer to the interpreter instance.
pub fn populate_predicates(interp: *interpreter.Interpreter) !void {
    try interp.root_env.set(interp, "null?", core.Value{ .procedure = predicates.is_null });
    try interp.root_env.set(interp, "boolean?", core.Value{ .procedure = predicates.is_boolean });
    try interp.root_env.set(interp, "symbol?", core.Value{ .procedure = predicates.is_symbol });
    try interp.root_env.set(interp, "number?", core.Value{ .procedure = predicates.is_number });
    try interp.root_env.set(interp, "string?", core.Value{ .procedure = predicates.is_string });
    try interp.root_env.set(interp, "list?", core.Value{ .procedure = predicates.is_list });
    try interp.root_env.set(interp, "pair?", core.Value{ .procedure = predicates.is_pair });
    try interp.root_env.set(interp, "procedure?", core.Value{ .procedure = predicates.is_procedure });
    try interp.root_env.set(interp, "eq?", core.Value{ .procedure = predicates.is_eq });
    try interp.root_env.set(interp, "eqv?", core.Value{ .procedure = predicates.is_eqv });
    try interp.root_env.set(interp, "equal?", core.Value{ .procedure = predicates.is_equal });
}

/// Populates the interpreter's root environment with string manipulation primitive functions.
///
/// Parameters:
/// - `interp`: A pointer to the interpreter instance.
pub fn populate_strings(interp: *interpreter.Interpreter) !void {
    try interp.root_env.set(interp, "symbol->string", core.Value{ .procedure = strings.symbol_to_string });
    try interp.root_env.set(interp, "string->symbol", core.Value{ .procedure = strings.string_to_symbol });
    try interp.root_env.set(interp, "string-length", core.Value{ .procedure = strings.string_length });
    try interp.root_env.set(interp, "string-append", core.Value{ .procedure = strings.string_append });
    try interp.root_env.set(interp, "char=?", core.Value{ .procedure = strings.char_eq });
}

/// Populates the interpreter's root environment with control-related primitive functions.
///
/// Parameters:
/// - `interp`: A pointer to the interpreter instance.
pub fn populate_control(interp: *interpreter.Interpreter) !void {
    try interp.root_env.set(interp, "apply", core.Value{ .procedure = control.apply });
}

/// Populates the interpreter's root environment with I/O primitive functions.
///
/// Parameters:
/// - `interp`: A pointer to the interpreter instance.
pub fn populate_io(interp: *interpreter.Interpreter) !void {
    try interp.root_env.set(interp, "display", core.Value{ .procedure = io.display });
    try interp.root_env.set(interp, "write", core.Value{ .procedure = io.write_proc });
    try interp.root_env.set(interp, "newline", core.Value{ .procedure = io.newline });
    try interp.root_env.set(interp, "load", core.Value{ .procedure = io.load });
}

/// Populates the interpreter's root environment with module-related primitive functions.
///
/// Parameters:
/// - `interp`: A pointer to the interpreter instance.
pub fn populate_modules(interp: *interpreter.Interpreter) !void {
    try interp.root_env.set(interp, "module-ref", core.Value{ .procedure = modules.module_ref });
}

/// Populates the interpreter's root environment with process-related primitive functions.
///
/// Parameters:
/// - `interp`: A pointer to the interpreter instance.
pub fn populate_process(interp: *interpreter.Interpreter) !void {
    try interp.root_env.set(interp, "exit", core.Value{ .procedure = process.exit });
}

/// Populates the interpreter's root environment with all primitive functions.
///
/// Parameters:
/// - `interp`: A pointer to the interpreter instance.
pub fn populate_globals(interp: *interpreter.Interpreter) !void {
    try populate_math(interp);
    try populate_lists(interp);
    try populate_predicates(interp);
    try populate_strings(interp);
    try populate_control(interp);
    try populate_io(interp);
    try populate_modules(interp);
    try populate_process(interp);
}

/// Defines a foreign function in the given environment.
/// This function uses `ffi.makeForeignFunc` to create a wrapper around a Zig function,
/// making it callable from Elz.
///
/// Parameters:
/// - `env`: The environment in which to define the foreign function.
/// - `name`: The name of the function as it will be known in Elz.
/// - `func`: The Zig function to be exposed to Elz. This must be a comptime-known function.
pub fn define_foreign_func(env: *core.Environment, name: []const u8, comptime func: anytype) !void {
    const ff = ffi.makeForeignFunc(func);
    const owned_name = try env.allocator.dupe(u8, name);
    try env.bindings.put(owned_name, core.Value{ .foreign_procedure = ff });
}
