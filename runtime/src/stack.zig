const Value = @import("value.zig").Value;
const _Value = @import("value.zig")._Value;

const std = @import("std");

pub const Stack = struct {
    items: []Value,
    sp: usize,
    allocator: std.mem.Allocator,
    pub fn init(size: usize, alloc: std.mem.Allocator) Stack {
        return Stack{
            .items = alloc.alloc(Value, size) catch unreachable,
            .sp = 0,
            .allocator = alloc,
        };
    }

    pub fn pop(self: *Stack) Value {
        if (self.sp == 0) {
            return Value.newValue(_Value{ .none = {} }, .None); // Return a default value if stack is empty
        }
        self.sp -= 1;
        return self.items[self.sp];
    }

    pub fn push(self: *Stack, value: Value) void {
        if (self.sp >= self.items.len) {
            return; // Stack overflow, handle as needed
        }
        self.items[self.sp] = value;
        self.sp += 1;
    }

    pub fn deinit(self: *Stack) void {
        self.allocator.free(self.items);
    }

    pub fn get(self: *Stack, index: usize) Value {
        if (index >= self.sp) {
            return Value.newValue(_Value{ .none = {} }, .None);
        }
        return self.items[index];
    }

    pub fn set(self: *Stack, index: usize, value: Value) void {
        if (index >= self.sp) {
            return; // Handle as needed
        }
        self.items[index] = value;
    }
};
