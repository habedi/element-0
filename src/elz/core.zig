const std = @import("std");
const errors = @import("errors.zig");
const ElzError = errors.ElzError;
const interpreter = @import("interpreter.zig");

const gc = @import("gc.zig");

pub const ValueList = gc.GcArrayList(Value);

pub const Module = struct {
    exports: std.StringHashMap(Value),
};

pub const Cell = struct {
    content: Value,
};

pub const Environment = struct {
    bindings: std.StringHashMap(Value),
    outer: ?*Environment,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, outer: ?*Environment) !*Environment {
        const self = try allocator.create(Environment);
        self.* = .{
            .bindings = std.StringHashMap(Value).init(allocator),
            .outer = outer,
            .allocator = allocator,
        };
        try self.bindings.ensureTotalCapacity(8);
        return self;
    }

    pub fn get(self: *const Environment, name: []const u8, interp: *interpreter.Interpreter) ElzError!Value {
        var current_env: ?*const Environment = self;
        while (current_env) |env| {
            if (env.bindings.capacity() > 0) {
                if (env.bindings.get(name)) |value| {
                    return switch (value) {
                        .cell => |c| c.content,
                        else => value,
                    };
                }
            }
            current_env = env.outer;
        }
        interp.last_error_message = std.fmt.allocPrint(self.allocator, "Symbol '{s}' not found.", .{name}) catch null;
        return ElzError.SymbolNotFound;
    }

    pub fn contains(self: *const Environment, name: []const u8) bool {
        var current_env: ?*const Environment = self;
        while (current_env) |env| {
            if (env.bindings.contains(name)) {
                return true;
            }
            current_env = env.outer;
        }
        return false;
    }

    pub fn set(self: *Environment, interp: *interpreter.Interpreter, name: []const u8, value: Value) ElzError!void {
        const owned_name = try self.allocator.dupe(u8, name);
        const owned_value = try value.deep_clone(self.allocator);
        try self.bindings.put(owned_name, owned_value);
        _ = interp;
    }

    pub fn update(self: *Environment, interp: *interpreter.Interpreter, name: []const u8, value: Value) ElzError!void {
        var current_env: ?*Environment = self;
        while (current_env) |env| {
            if (env.bindings.getEntry(name)) |entry| {
                switch (entry.value_ptr.*) {
                    .cell => |c| c.content = try value.deep_clone(self.allocator),
                    else => entry.value_ptr.* = try value.deep_clone(self.allocator),
                }
                return;
            }
            current_env = env.outer;
        }
        interp.last_error_message = std.fmt.allocPrint(self.allocator, "Cannot set! unbound symbol '{s}'.", .{name}) catch null;
        return ElzError.SymbolNotFound;
    }
};

pub const UserDefinedProc = struct {
    params: ValueList,
    body: Value,
    env: *Environment,
};

pub const PrimitiveFn = *const fn (interp: *interpreter.Interpreter, env: *Environment, args: ValueList, fuel: *u64) ElzError!Value;

pub const Pair = struct {
    car: Value,
    cdr: Value,
};

pub const Value = union(enum) {
    symbol: []const u8,
    number: f64,
    pair: *Pair,
    character: u32,
    string: []const u8,
    boolean: bool,
    closure: *UserDefinedProc,
    procedure: PrimitiveFn,
    foreign_procedure: *const fn (env: *Environment, args: ValueList) anyerror!Value,
    opaque_pointer: ?*anyopaque,
    cell: *Cell,
    module: *Module,
    nil,
    unspecified,

    pub fn is_symbol(self: Value, comptime str: []const u8) bool {
        return switch (self) {
            .symbol => |s| std.mem.eql(u8, s, str),
            else => false,
        };
    }

    pub fn deep_clone(self: Value, allocator: std.mem.Allocator) !Value {
        return switch (self) {
            .symbol => |s| Value{ .symbol = try allocator.dupe(u8, s) },
            .number, .boolean, .character, .closure, .procedure, .foreign_procedure, .opaque_pointer, .cell, .module, .nil, .unspecified => self,
            .string => |s| Value{ .string = try allocator.dupe(u8, s) },
            .pair => |p| {
                const new_pair = try allocator.create(Pair);
                new_pair.* = .{
                    .car = try p.car.deep_clone(allocator),
                    .cdr = try p.cdr.deep_clone(allocator),
                };
                return Value{ .pair = new_pair };
            },
        };
    }

    pub fn from(allocator: std.mem.Allocator, v: anytype) !Value {
        return switch (@typeInfo(@TypeOf(v))) {
            .float => Value{ .number = v },
            .int => Value{ .number = @floatFromInt(v) },
            .bool => Value{ .boolean = v },
            .pointer => |p| switch (p.size) {
                .slice => blk: {
                    const s = try allocator.dupe(u8, v);
                    break :blk Value{ .string = s };
                },
                else => @compileError("Unsupported pointer type"),
            },
            else => @compileError("Unsupported from type"),
        };
    }
};

test "core environment" {
    const allocator = std.testing.allocator;
    const testing = std.testing;
    var interp_stub: interpreter.Interpreter = .{
        .allocator = allocator,
        .root_env = undefined,
        .last_error_message = null,
        .module_cache = undefined,
    };

    // Test set and get in the same environment
    var env = try Environment.init(allocator, null);
    try env.set(&interp_stub, "x", Value{ .number = 42 });
    var value = try env.get("x", &interp_stub);
    try testing.expect(value == Value{ .number = 42 });

    // Test get from outer environment
    var outer_env = try Environment.init(allocator, null);
    try outer_env.set(&interp_stub, "y", Value{ .string = "hello" });
    var inner_env = try Environment.init(allocator, outer_env);
    value = try inner_env.get("y", &interp_stub);
    try testing.expect(value == Value{ .string = "hello" });

    // Test update on outer environment
    try inner_env.update(&interp_stub, "y", Value{ .string = "world" });
    value = try outer_env.get("y", &interp_stub);
    try testing.expect(value == Value{ .string = "world" });

    // Test update on symbol not found
    const err = inner_env.update(&interp_stub, "z", Value{ .number = 0 });
    try testing.expectError(ElzError.SymbolNotFound, err);
}
