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

pub const allocator: mem.Allocator = .{
    .ptr = &gc_allocator_instance,
    .vtable = &gc_allocator_instance.vtable,
};

pub fn init() void {
    c.GC_init();
}

pub fn add_roots(start: usize, end: usize) void {
    c.GC_add_roots(@ptrFromInt(start), @ptrFromInt(end));
}

pub fn GcArrayList(comptime T: type) type {
    return struct {
        items: []T,
        capacity: usize,

        const Self = @This();

        pub fn init(_: mem.Allocator) Self {
            return .{
                .items = &[_]T{},
                .capacity = 0,
            };
        }

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

        pub fn get(self: Self, index: usize) T {
            return self.items[index];
        }

        pub fn set(self: Self, index: usize, value: T) void {
            self.items[index] = value;
        }
    };
}
