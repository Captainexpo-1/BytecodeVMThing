const std = @import("std");
const StackWord = @import("global.zig").StackWord;
/// A simple byte-level heap allocator for raw memory
pub const Heap = struct {
    allocator: std.mem.Allocator,

    /// Initialize the heap with a given allocator
    pub fn init(allocator: std.mem.Allocator) Heap {
        return Heap{ .allocator = allocator };
    }

    /// Allocate a buffer of `size` bytes
    pub fn allocBytes(self: *Heap, size: usize) ![]u8 {
        return try self.allocator.alloc(u8, size);
    }

    /// Reallocate a previously allocated buffer to `newSize`
    pub fn reallocBytes(self: *Heap, ptr: []u8, newSize: usize) ![]u8 {
        return try self.allocator.realloc(u8, ptr, newSize);
    }

    /// Free a previously allocated buffer
    pub fn freeBytes(self: *Heap, ptr: []u8) void {
        self.allocator.free(ptr);
    }
};
