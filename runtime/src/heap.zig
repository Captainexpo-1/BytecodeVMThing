const std = @import("std");
const ValueType = @import("value.zig").ValueType;
const Value = @import("value.zig").Value;
const _Value = @import("value.zig")._Value;

pub const Heap = struct {
    allocator: std.mem.Allocator,

    allocated_memory: std.AutoHashMap(*Value, ValueType),

    pub fn alloc(self: *Heap, size: usize) !*Value {
        const ptr: *Value = @as(*Value, @ptrCast(try self.allocator.alloc(Value, size)));
        self.allocated_memory.put(ptr, ptr.*.vtype) catch {
            self.allocator.destroy(ptr);
            return error.OutOfMemory;
        };
        return ptr;
    }

    pub fn alloc_array(self: *Heap, size: usize) ![]*Value {
        const ptr: []Value = try self.allocator.alloc(Value, size);
        const array_ptr: []const *Value = @ptrCast(ptr);
        for (array_ptr) |*value_ptr| {
            self.allocated_memory.put(value_ptr, value_ptr.*.vtype) catch {
                self.allocator.free(ptr);
                return error.OutOfMemory;
            };
        }
        return array_ptr;
    }

    pub fn dereference(self: *Heap, ptr: *Value) Value {
        _ = self;
        return ptr.*;
    }

    pub fn store(self: *Heap, ptr: *Value, value: Value) !void {
        _ = self;
        if (value.vtype != ptr.*.vtype) {
            return error.TypeMismatch; // Ensure type consistency
        }
        ptr.* = value;
    }

    pub fn free(self: *Heap, ptr: *Value) !void {
        if (self.allocated_memory.remove(ptr)) {
            // Successfully removed from the tracking map, now free the memory
            self.allocator.destroy(ptr);
        } else {
            return error.InvalidPointer; // Pointer was not allocated by this heap
        }
    }

    pub fn realloc(self: *Heap, ptr: *Value, new_size: usize) !*Value {
        return self.allocator.realloc(Value, ptr, new_size);
    }

    pub fn deinit(self: *Heap) void {
        // No specific deinitialization needed for the heap itself,
        // as it relies on the allocator's deinitialization.
        // However, you might want to free any allocated memory if necessary.
        for (self.allocated_memory.items) |item| {
            self.allocator.free(item.key);
        }
        self.allocated_memory.deinit();
    }

    pub fn init(allocator: std.mem.Allocator) Heap {
        return Heap{
            .allocator = allocator,
            .allocated_memory = std.AutoHashMap(*Value, ValueType).init(allocator),
        };
    }
};
