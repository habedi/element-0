//! This module defines the core data structures for the Element 0 interpreter.
//! It includes types for representing values, environments, procedures, and pairs.

const std = @import("std");
const ElzError = @import("errors.zig").ElzError;

const gc = @import("gc.zig");

/// A garbage-collected list of values.
pub const ValueList = gc.GcArrayList(Value);

/// Represents a mutable container for a value, used for `set!` and `letrec`.
pub const Cell = struct {
    content: Value,
};

/// Represents the lexical environment for evaluation.
/// An environment is a collection of bindings from symbols to values.
/// It can have an outer environment, creating a scope chain.
pub const Environment = struct {
    bindings: std.StringHashMap(Value),
    outer: ?*Environment,
    allocator: std.mem.Allocator,

    /// Creates a new environment.
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

    /// Retrieves a value from the environment, resolving cells.
    pub fn get(self: *const Environment, name: []const u8) ElzError!Value {
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
        return ElzError.SymbolNotFound;
    }

    /// Binds a value to a symbol in the current environment.
    pub fn set(self: *Environment, name: []const u8, value: Value) !void {
        const owned_name = try self.allocator.dupe(u8, name);
        const owned_value = try value.deep_clone(self.allocator);
        try self.bindings.put(owned_name, owned_value);
    }

    /// Updates an existing binding in the environment chain.
    pub fn update(self: *Environment, name: []const u8, value: Value) ElzError!void {
        var current_env: ?*Environment = self;
        while (current_env) |env| {
            if (env.bindings.getEntry(name)) |entry| {
                // If the binding is a cell, update its content. Otherwise, update the binding itself.
                switch (entry.value_ptr.*) {
                    .cell => |c| c.content = try value.deep_clone(self.allocator),
                    else => entry.value_ptr.* = try value.deep_clone(self.allocator),
                }
                return;
            }
            current_env = env.outer;
        }
        return ElzError.SymbolNotFound;
    }
};

/// Represents a user-defined procedure.
pub const UserDefinedProc = struct {
    params: ValueList,
    body: Value,
    env: *Environment,
};

/// Represents a primitive (built-in) function.
pub const PrimitiveFn = *const fn (env: *Environment, args: ValueList) anyerror!Value;

/// Represents a pair, the building block for lists.
pub const Pair = struct {
    car: Value,
    cdr: Value,
};

/// Represents any value in the Element 0 language.
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
            .number, .boolean, .character, .closure, .procedure, .foreign_procedure, .opaque_pointer, .cell, .nil, .unspecified => self,
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
            .Float => Value{ .number = v },
            .Int => Value{ .number = @floatFromInt(v) },
            .Bool => Value{ .boolean = v },
            .Pointer => |p| switch (p.size) {
                .Slice => blk: {
                    const s = try allocator.dupe(u8, v);
                    break :blk Value{ .string = s };
                },
                else => @compileError("Unsupported pointer type"),
            },
            else => @compileError("Unsupported from type"),
        };
    }
};
