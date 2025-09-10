const std = @import("std");
const core = @import("./core.zig");
const env_setup = @import("./env_setup.zig");
const eval = @import("./eval.zig");
const parser = @import("./parser.zig");
const gc = @import("gc.zig");

var gc_once = std.once(init_gc);

fn init_gc() void {
    gc.init();
}

/// `SandboxFlags` is a struct that defines the features to be enabled in the Elz interpreter.
/// This allows for creating a sandboxed environment with a restricted set of capabilities.
pub const SandboxFlags = struct {
    /// Enables or disables mathematical functions.
    enable_math: bool = true,
    /// Enables or disables list manipulation functions.
    enable_lists: bool = true,
    /// Enables or disables predicate functions (e.g., `null?`, `pair?`).
    enable_predicates: bool = true,
    /// Enables or disables string manipulation functions.
    enable_strings: bool = true,
    /// Enables or disables I/O functions (e.g., `display`, `load`).
    enable_io: bool = true,
};

/// `Interpreter` is the main struct for the Elz interpreter.
/// It holds the state of the interpreter, including the root environment, allocator, and module cache.
pub const Interpreter = struct {
    /// The memory allocator used by the interpreter.
    allocator: std.mem.Allocator,
    /// The root environment of the interpreter, containing the built-in functions and variables.
    root_env: *core.Environment,
    /// A message describing the last error that occurred, if any.
    last_error_message: ?[]const u8 = null,
    /// A cache for loaded modules to avoid redundant parsing and evaluation.
    module_cache: std.StringHashMap(*core.Module),

    /// Initializes a new Elz interpreter instance.
    /// This function sets up the garbage collector, creates the root environment,
    /// populates it with primitive functions based on the provided `SandboxFlags`,
    /// and loads the standard library.
    ///
    /// Parameters:
    /// - `flags`: A `SandboxFlags` struct specifying which features to enable.
    ///
    /// Returns:
    /// An initialized `Interpreter` instance, or an error if initialization fails.
    pub fn init(flags: SandboxFlags) !Interpreter {
        gc_once.call();
        const allocator = gc.allocator;

        var self: Interpreter = .{
            .allocator = allocator,
            .root_env = undefined,
            .last_error_message = null,
            .module_cache = std.StringHashMap(*core.Module).init(allocator),
        };

        const root_env_ptr = gc.allocUncollectable(@sizeOf(core.Environment)) orelse return error.OutOfMemory;
        const root_env: *core.Environment = @ptrCast(@alignCast(root_env_ptr));
        root_env.* = .{
            .bindings = std.StringHashMap(core.Value).init(allocator),
            .outer = null,
            .allocator = allocator,
        };
        try root_env.bindings.ensureTotalCapacity(8);
        gc.add_roots(@intFromPtr(root_env), @intFromPtr(root_env) + @sizeOf(core.Environment));
        self.root_env = root_env;

        try root_env.set(&self, "nil", core.Value.nil);

        if (flags.enable_math) {
            try env_setup.populate_math(&self);
        }
        if (flags.enable_lists) {
            try env_setup.populate_lists(&self);
        }
        if (flags.enable_predicates) {
            try env_setup.populate_predicates(&self);
        }
        if (flags.enable_strings) {
            try env_setup.populate_strings(&self);
        }
        if (flags.enable_io) {
            try env_setup.populate_io(&self);
        }
        try env_setup.populate_control(&self);
        try env_setup.populate_modules(&self);
        try env_setup.populate_process(&self);

        const std_lib_source = @embedFile("../stdlib/std.elz");
        const std_lib_forms = try parser.readAll(std_lib_source, allocator);

        var fuel: u64 = 1_000_000;
        for (std_lib_forms.items) |form| {
            _ = try eval.eval(&self, &form, self.root_env, &fuel);
        }

        return self;
    }

    /// Evaluates a string of Elz source code.
    /// This function parses the source code into a series of expressions and then evaluates them
    /// in the interpreter's root environment.
    ///
    /// Parameters:
    /// - `self`: A pointer to the `Interpreter` instance.
    /// - `source`: A string slice containing the Elz code to evaluate.
    /// - `fuel`: A pointer to a `u64` value that represents the maximum number of evaluation steps
    ///           allowed. This is a mechanism to prevent infinite loops. The value is decremented
    ///           during evaluation.
    ///
    /// Returns:
    /// The `core.Value` of the last evaluated expression, or an error if parsing or evaluation fails.
    pub fn evalString(self: *Interpreter, source: []const u8, fuel: *u64) !core.Value {
        const forms = try parser.readAll(source, self.allocator);

        var result: core.Value = .unspecified;
        for (forms.items) |form| {
            result = try eval.eval(self, &form, self.root_env, fuel);
        }
        return result;
    }
};
