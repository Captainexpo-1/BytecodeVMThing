const std = @import("std");
const StackWord = @import("global.zig").StackWord;

pub const STACK_SIZE: usize = 1024;

pub const Stack = struct {
    items: []StackWord,
    sp: usize,
    allocator: std.mem.Allocator,

    /// Create a stack capable of holding `size` words
    pub fn init(allocator: std.mem.Allocator) Stack {
        const items = allocator.alloc(StackWord, STACK_SIZE) catch {
            std.debug.panic("Failed to allocate stack", .{});
        };
        return Stack{
            .items = items,
            .sp = 0,
            .allocator = allocator,
        };
    }

    /// Push a word onto the stack (no-op on overflow)
    pub fn push(self: *Stack, value: StackWord) void {
        if (self.sp < self.items.len) {
            self.items[self.sp] = value;
            self.sp += 1;
        }
    }

    /// Pop a word from the stack, returning 0 on underflow
    pub fn pop(self: *Stack) StackWord {
        if (self.sp == 0) return 0;
        self.sp -= 1;
        return self.items[self.sp];
    }

    pub fn popN(self: *Stack, n: usize) []StackWord {
        if (self.sp < n) return self.items[0..0];
        const result = self.items[self.sp - n .. self.sp];
        self.sp -= n;
        return result;
    }

    /// Peek at the word `offset` from the top (0 = top)
    pub fn peek(self: *Stack, offset: usize) StackWord {
        if (offset >= self.sp) return 0;
        return self.items[self.sp - 1 - offset];
    }

    /// Free the stack's backing storage
    pub fn deinit(self: *Stack) void {
        self.allocator.free(self.items);
    }
};
