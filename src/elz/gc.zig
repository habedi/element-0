//! This module provides an interface to the Boehm-Demers-Weiser garbage collector.
//! It defines a custom allocator that uses the GC and a `GcArrayList` that
//! uses this allocator.

const std = @import("std");
const mem = std.mem;

/// Imports the C interface for the garbage collector.
pub const c = @cImport({
    @cInclude("gc.h");
});

/// Allocates memory using the garbage collector.
fn gcAlloc(ctx: *anyopaque, len: usize, alignment: mem.Alignment, ret_addr: usize) ?[*]u8 {
    _ = ret_addr;
    _ = ctx;
    const res = c.GC_memalign(mem.Alignment.toByteUnits(alignment), len);
    if (res == null) return null;
    return @ptrCast(res);
}

/// Resize function for the garbage collector allocator.
/// This function is a no-op because the GC handles resizing.
fn gcResize(ctx: *anyopaque, buf: []u8, buf_align: mem.Alignment, new_len: usize, ret_addr: usize) bool {
    _ = ctx;
    _ = buf;
    _ = buf_align;
    _ = new_len;
    _ = ret_addr;
    return false;
}

/// Remaps a memory buffer using the garbage collector.
fn gcRemap(ctx: *anyopaque, buf: []u8, buf_align: mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
    _ = ctx;
    _ = buf_align;
    _ = ret_addr;
    const new_ptr = c.GC_realloc(buf.ptr, new_len);
    if (new_ptr == null) return null;
    return @ptrCast(new_ptr);
}

/// Frees memory using the garbage collector.
/// This function is a no-op because the GC handles freeing memory.
fn gcFree(ctx: *anyopaque, buf: []u8, buf_align: mem.Alignment, ret_addr: usize) void {
    _ = ctx;
    _ = buf;
    _ = buf_align;
    _ = ret_addr;
}

/// A custom allocator that uses the Boehm-Demers-Weiser garbage collector.
const GcAllocator = struct {
    vtable: mem.Allocator.VTable = .{
        .alloc = gcAlloc,
        .resize = gcResize,
        .remap = gcRemap,
        .free = gcFree,
    },
};

var gc_allocator_instance = GcAllocator{};

/// The global instance of the garbage collector allocator.
pub const allocator: mem.Allocator = .{
    .ptr = &gc_allocator_instance,
    .vtable = &gc_allocator_instance.vtable,
};

/// Initializes the garbage collector.
pub fn init() void {
    c.GC_init();
}

/// A generic ArrayList that uses the garbage collector for memory management.
///
/// - `T`: The type of the elements in the list.
pub fn GcArrayList(comptime T: type) type {
    return struct {
        items: []T,
        capacity: usize,

        const Self = @This();

        /// Initializes a new `GcArrayList`.
        ///
        /// - `allocator`: The allocator to use. This is ignored because the
        ///                `GcArrayList` always uses the garbage collector.
        /// - `return`: A new `GcArrayList`.
        pub fn init(_: mem.Allocator) Self {
            return .{
                .items = &[_]T{},
                .capacity = 0,
            };
        }

        /// Appends an item to the list.
        ///
        /// - `self`: A pointer to the list.
        /// - `item`: The item to append.
        pub fn append(self: *Self, item: T) !void {
            if (self.items.len == self.capacity) {
                const new_capacity = if (self.capacity == 0) 4 else self.capacity * 2;
                const new_byte_size = new_capacity * @sizeOf(T);
                var new_ptr_untyped: ?*anyopaque = undefined;
                if (self.capacity == 0) {
                    new_ptr_untyped = c.GC_malloc(new_byte_size);
                } else {
                    new_ptr_untyped = c.GC_realloc(self.items.ptr, new_byte_size);
                }

                if (new_ptr_untyped == null) return error.OutOfMemory;

                const new_ptr_typed: [*]T = @alignCast(@ptrCast(new_ptr_untyped));
                self.items = new_ptr_typed[0..self.items.len];
                self.capacity = new_capacity;
            }

            self.items.ptr[self.items.len] = item;
            self.items.len += 1;
        }

        /// Gets the item at the specified index.
        ///
        /// - `self`: The list.
        /// - `index`: The index of the item to get.
        /// - `return`: The item at the specified index.
        pub fn get(self: Self, index: usize) T {
            return self.items[index];
        }

        /// Sets the item at the specified index.
        ///
        /// - `self`: The list.
        /// - `index`: The index of the item to set.
        /// - `value`: The new value.
        pub fn set(self: Self, index: usize, value: T) void {
            self.items[index] = value;
        }
    };
}
