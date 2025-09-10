const std = @import("std");
const core = @import("./core.zig");
const env_setup = @import("./env_setup.zig");
const eval = @import("./eval.zig");
const parser = @import("./parser.zig");
const gc = @import("gc.zig");

var gc_initialized: bool = false;

pub const SandboxFlags = struct {
    enable_math: bool = true,
    enable_lists: bool = true,
    enable_predicates: bool = true,
    enable_strings: bool = true,
    enable_io: bool = true,
};

pub const Interpreter = struct {
    allocator: std.mem.Allocator,
    root_env: *core.Environment,
    last_error_message: ?[]const u8 = null,
    module_cache: std.StringHashMap(*core.Module),

    pub fn init(flags: SandboxFlags) !Interpreter {
        _ = flags;
        const allocator = gc.allocator;
        if (!gc_initialized) {
            gc.init();
            gc_initialized = true;
        }

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

        try env_setup.populate_globals(&self);

        const std_lib_source = @embedFile("../stdlib/std.elz");
        const std_lib_forms = try parser.readAll(std_lib_source, allocator);

        var fuel: u64 = 1_000_000;
        for (std_lib_forms.items) |form| {
            _ = try eval.eval(&self, &form, self.root_env, &fuel);
        }

        return self;
    }

    pub fn evalString(self: *Interpreter, source: []const u8, fuel: *u64) !core.Value {
        const forms = try parser.readAll(source, self.allocator);

        var result: core.Value = .unspecified;
        for (forms.items) |form| {
            result = try eval.eval(self, &form, self.root_env, fuel);
        }
        return result;
    }
};
