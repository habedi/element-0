//! This module defines the core data structures for the Element 0 interpreter.
//! It includes types for representing values, environments, procedures, and pairs.

const std = @import("std");
const ElzError = @import("errors.zig").ElzError;

const gc = @import("gc.zig");

/// A garbage-collected list of values.
pub const ValueList = gc.GcArrayList(Value);

/// Represents the lexical environment for evaluation.
/// An environment is a collection of bindings from symbols to values.
/// It can have an outer environment, creating a scope chain.
pub const Environment = struct {
    bindings: std.StringHashMap(Value),
    outer: ?*Environment,
    allocator: std.mem.Allocator,

    /// Creates a new environment.
    ///
    /// - `allocator`: The memory allocator to use.
    /// - `outer`: An optional pointer to the outer environment.
    /// - `return`: A pointer to the new environment.
    pub fn init(allocator: std.mem.Allocator, outer: ?*Environment) !*Environment {
        const self = try allocator.create(Environment);
        self.* = .{
            .bindings = std.StringHashMap(Value).init(allocator),
            .outer = outer,
            .allocator = allocator,
        };
        // Proactively ensure capacity is non-zero to prevent panics in std.hash_map.
        try self.bindings.ensureTotalCapacity(8);
        return self;
    }

    /// Retrieves a value from the environment.
    /// It searches the current environment and its outer environments iteratively.
    ///
    /// - `self`: A pointer to the environment.
    /// - `name`: The symbol name to look up.
    /// - `return`: The value associated with the symbol, or an error if not found.
    pub fn get(self: *const Environment, name: []const u8) ElzError!Value {
        var current_env: ?*const Environment = self;
        while (current_env) |env| {
            // Defensively check capacity to prevent panic on a corrupted or empty map.
            if (env.bindings.capacity() > 0) {
                if (env.bindings.get(name)) |value| {
                    return value;
                }
            }
            current_env = env.outer;
        }
        return ElzError.SymbolNotFound;
    }

    /// Binds a value to a symbol in the current environment.
    /// This function creates a new binding. It does not modify existing bindings.
    ///
    /// - `self`: A pointer to the environment.
    /// - `name`: The symbol name to bind.
    /// - `value`: The value to bind.
    pub fn set(self: *Environment, name: []const u8, value: Value) !void {
        const owned_name = try self.allocator.dupe(u8, name);
        const owned_value = try value.deep_clone(self.allocator);
        try self.bindings.put(owned_name, owned_value);
    }

    /// Updates an existing binding in the environment.
    /// It searches the current environment and its outer environments.
    ///
    /// - `self`: A pointer to the environment.
    /// - `name`: The symbol name to update.
    /// - `value`: The new value.
    /// - `return`: `void` on success, or an error if the symbol is not found.
    pub fn update(self: *Environment, name: []const u8, value: Value) ElzError!void {
        if (self.bindings.getEntry(name)) |entry| {
            entry.value_ptr.* = try value.deep_clone(self.allocator);
            return;
        }
        if (self.outer) |parent| {
            return parent.update(name, value);
        }
        return ElzError.SymbolNotFound;
    }
};

/// Represents a user-defined procedure.
/// It contains the parameter list, the procedure body, and the environment where it was created.
pub const UserDefinedProc = struct {
    params: ValueList,
    body: Value,
    env: *Environment,
};

/// Represents a primitive (built-in) function.
pub const PrimitiveFn = *const fn (env: *Environment, args: ValueList) anyerror!Value;

/// Represents a pair, the building block for lists.
/// A pair contains a `car` (the first element) and a `cdr` (the rest of the list).
pub const Pair = struct {
    car: Value,
    cdr: Value,
};

/// Represents any value in the Element 0 language.
/// This is a tagged union that can hold different types of data.
pub const Value = union(enum) {
    /// A symbol, represented as a string.
    symbol: []const u8,
    /// A number, represented as a 64-bit float.
    number: f64,
    /// A pair, used to build lists.
    pair: *Pair,
    /// A character, represented as a Unicode code point.
    character: u32,
    /// A string.
    string: []const u8,
    /// A boolean value.
    boolean: bool,
    /// A user-defined procedure (closure).
    closure: *UserDefinedProc,
    /// A primitive (built-in) procedure.
    procedure: PrimitiveFn,
    /// A foreign function.
    foreign_procedure: *const fn (env: *Environment, args: ValueList) anyerror!Value,
    /// An opaque pointer for FFI.
    opaque_pointer: ?*anyopaque,
    /// The `nil` value, representing an empty list.
    nil,
    /// A special value for procedures that only have side effects.
    unspecified,

    /// Checks if the value is a specific symbol.
    ///
    /// - `self`: The value to check.
    /// - `str`: The symbol name to compare against.
    /// - `return`: `true` if the value is the specified symbol, otherwise `false`.
    pub fn is_symbol(self: Value, comptime str: []const u8) bool {
        return switch (self) {
            .symbol => |s| std.mem.eql(u8, s, str),
            else => false,
        };
    }

    /// Creates a deep copy of the value.
    /// This function allocates new memory for symbols, strings, and pairs.
    ///
    /// - `self`: The value to clone.
    /// - `allocator`: The memory allocator to use.
    /// - `return`: A new `Value` that is a deep copy of the original.
    pub fn deep_clone(self: Value, allocator: std.mem.Allocator) !Value {
        return switch (self) {
            .symbol => |s| Value{ .symbol = try allocator.dupe(u8, s) },
            .number, .boolean, .character, .closure, .procedure, .foreign_procedure, .opaque_pointer, .nil, .unspecified => self,
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

    /// Creates a `Value` from a Zig type.
    /// This function converts a Zig value into its corresponding Element 0 representation.
    ///
    /// - `allocator`: The memory allocator to use.
    /// - `v`: The Zig value to convert.
    /// - `return`: A new `Value`.
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
