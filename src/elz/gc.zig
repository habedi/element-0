const std = @import("std");
const mem = std.mem;

pub const c = @cImport({
    @cInclude("gc.h");
});

fn gcAlloc(ctx: *anyopaque, len: usize, alignment: mem.Alignment, ret_addr: usize) ?[*]u8 {
    _ = ret_addr;
    _ = ctx;
    const res = c.GC_memalign(mem.Alignment.toByteUnits(alignment), len);
    if (res == null) return null;
    return @ptrCast(res);
}

fn gcResize(ctx: *anyopaque, buf: []u8, buf_align: mem.Alignment, new_len: usize, ret_addr: usize) bool {
    _ = ctx;
    _ = buf;
    _ = buf_align;
    _ = new_len;
    _ = ret_addr;
    return false;
}

fn gcRemap(ctx: *anyopaque, buf: []u8, buf_align: mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
    _ = ctx;
    _ = buf_align;
    _ = ret_addr;
    const new_ptr = c.GC_realloc(buf.ptr, new_len);
    if (new_ptr == null) return null;
    return @ptrCast(new_ptr);
}

fn gcFree(ctx: *anyopaque, buf: []u8, buf_align: mem.Alignment, ret_addr: usize) void {
    _ = ctx;
    _ = buf;
    _ = buf_align;
    _ = ret_addr;
}

/// Allocates memory that is not subject to garbage collection.
/// This is useful for allocating objects that should persist for the lifetime of the interpreter.
///
/// Parameters:
/// - `len`: The number of bytes to allocate.
///
/// Returns:
/// A pointer to the allocated memory, or `null` if allocation fails.
pub fn allocUncollectable(len: usize) ?*anyopaque {
    return c.GC_malloc_uncollectable(len);
}

const GcAllocator = struct {
    vtable: mem.Allocator.VTable = .{
        .alloc = gcAlloc,
        .resize = gcResize,
        .remap = gcRemap,
        .free = gcFree,
    },
};

var gc_allocator_instance = GcAllocator{};

/// A `std.mem.Allocator` that uses the Boehm-Demers-Weiser garbage collector.
/// All memory allocated with this allocator is subject to garbage collection.
pub const allocator: mem.Allocator = .{
    .ptr = &gc_allocator_instance,
    .vtable = &gc_allocator_instance.vtable,
};

/// Initializes the garbage collector.
/// This function must be called before any other GC functions are used.
pub fn init() void {
    c.GC_init();
}

/// Adds a memory region to the set of roots for garbage collection.
/// The garbage collector will scan this region for pointers to garbage-collected memory.
///
/// Parameters:
/// - `start`: The start address of the memory region.
/// - `end`: The end address of the memory region.
pub fn add_roots(start: usize, end: usize) void {
    c.GC_add_roots(@ptrFromInt(start), @ptrFromInt(end));
}

/// `GcArrayList` is a generic struct that provides a garbage-collected dynamic array.
/// It is similar to `std.ArrayList`, but its internal storage is managed by the garbage collector.
///
/// Parameters:
/// - `T`: The type of the items in the array.
pub fn GcArrayList(comptime T: type) type {
    return struct {
        items: []T,
        capacity: usize,

        const Self = @This();

        /// Initializes a new `GcArrayList`.
        ///
        /// Parameters:
        /// - `allocator`: This parameter is ignored, as the `GcArrayList` always uses the GC allocator.
        pub fn init(_: mem.Allocator) Self {
            return .{
                .items = &[_]T{},
                .capacity = 0,
            };
        }

        /// Appends an item to the end of the array.
        /// If the array is full, it will be reallocated with a larger capacity.
        ///
        /// Parameters:
        /// - `self`: A pointer to the `GcArrayList`.
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
        /// Parameters:
        /// - `self`: The `GcArrayList`.
        /// - `index`: The index of the item to get.
        pub fn get(self: Self, index: usize) T {
            return self.items[index];
        }

        /// Sets the item at the specified index.
        ///
        /// Parameters:
        /// - `self`: The `GcArrayList`.
        /// - `index`: The index of the item to set.
        /// - `value`: The new value for the item.
        pub fn set(self: Self, index: usize, value: T) void {
            self.items[index] = value;
        }
    };
}
