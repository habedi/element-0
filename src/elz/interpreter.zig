//! This module defines the main `Interpreter` struct.
//! The `Interpreter` struct is the entry point for using the Element 0 interpreter.

const std = @import("std");
const core = @import("./core.zig");
const env_setup = @import("./env_setup.zig");
const eval = @import("./eval.zig");
const parser = @import("./parser.zig");
const gc = @import("gc.zig");

/// Flags for controlling the interpreter's sandbox environment.
/// These flags determine which sets of primitive procedures are available.
pub const SandboxFlags = struct {
    /// Enables mathematical procedures like `+`, `-`, `*`, `/`.
    enable_math: bool = true,
    /// Enables list manipulation procedures like `cons`, `car`, `cdr`.
    enable_lists: bool = true,
    /// Enables type predicate procedures like `null?`, `boolean?`, `number?`.
    enable_predicates: bool = true,
    /// Enables string, symbol, and character procedures like `symbol->string`.
    enable_strings: bool = true,
    /// Enables I/O procedures like `display`, `load`, which may have side effects.
    enable_io: bool = true,
};

/// The Element 0 interpreter.
/// This struct holds the state of the interpreter, including the allocator
/// and the root environment.
pub const Interpreter = struct {
    allocator: std.mem.Allocator,
    root_env: *core.Environment,

    /// Initializes a new interpreter.
    pub fn init(flags: SandboxFlags) !Interpreter {
        const allocator = gc.allocator;
        gc.init();
        const root_env = try core.Environment.init(allocator, null);

        // Define 'nil' as a global constant
        try root_env.set("nil", core.Value.nil);

        if (flags.enable_math) {
            try env_setup.populate_math(root_env);
        }
        if (flags.enable_lists) {
            try env_setup.populate_lists(root_env);
        }
        if (flags.enable_predicates) {
            try env_setup.populate_predicates(root_env);
        }
        if (flags.enable_strings) {
            try env_setup.populate_strings(root_env);
        }
        if (flags.enable_io) {
            try env_setup.populate_io(root_env);
        }
        try env_setup.populate_control(root_env);

        const std_lib_source = @embedFile("../stdlib/std.elz");
        const std_lib_forms = try parser.readAll(std_lib_source, allocator);

        var fuel: u64 = 1_000_000;
        for (std_lib_forms.items) |form| {
            _ = try eval.eval(&form, root_env, &fuel);
        }

        return Interpreter{
            .allocator = allocator,
            .root_env = root_env,
        };
    }

    /// Evaluates a string of Element 0 source code.
    pub fn evalString(self: *Interpreter, source: []const u8, fuel: *u64) !core.Value {
        const ast = try parser.read(source, self.allocator);
        return eval.eval(&ast, self.root_env, fuel);
    }
};
