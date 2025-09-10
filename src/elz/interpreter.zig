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

    fn verifyPrimitives(self: *Interpreter) !void {
        const must = [_][]const u8{
            "display",
            "newline",
            "cons",
            "car",
            "cdr",
        };
        inline for (must) |name| {
            if (!self.root_env.contains(name)) {
                return error.MissingPrimitive;
            }
        }
    }

    pub fn init(flags: SandboxFlags) !Interpreter {
        if (!gc_initialized) {
            gc.init();
            gc_initialized = true;
        }
        const allocator = gc.allocator;

        var self: Interpreter = .{
            .allocator = allocator,
            .root_env = undefined,
            .last_error_message = null,
        };
        const root_env = try core.Environment.init(allocator, null);
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

        if (flags.enable_io and flags.enable_lists) {
            try self.verifyPrimitives();
        }

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
