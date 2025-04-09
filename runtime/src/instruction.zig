const std = @import("std");
const Value = @import("value.zig").Value;

pub const OpCode = enum(u8) {
    // No operation
    Nop = 0,

    // Stack manipulation
    Dup = 1,
    Swap = 2,

    // Arithmetic operations
    Add = 3,
    Sub = 4,
    Mul = 5,
    Div = 6,
    Mod = 7,

    // Logical operations
    And = 8,
    Or = 9,
    Not = 10,
    Xor = 11,

    // Bitwise operations
    Shl = 12,
    Shr = 13,

    // Comparison operations
    Eq = 14,
    Neq = 15,
    Gt = 16,
    Lt = 17,
    Ge = 18,
    Le = 19,

    // Control flow
    Jmp = 20,
    Jz = 21,
    Jnz = 22,
    Call = 23,
    Ret = 24,

    // Variables
    LoadVar = 25,
    StoreVar = 26,

    // Load and halt
    LoadConst = 27,
    Halt = 28,
};

pub const Instruction = struct {
    instr: OpCode,
    operand: usize = 0,

    pub fn newInstruction(instr: OpCode, operand: usize) Instruction {
        return Instruction{
            .instr = instr,
            .operand = operand,
        };
    }

    pub fn toString(self: Instruction) []const u8 {
        const name = @tagName(self.instr);
        return std.fmt.allocPrint(std.heap.page_allocator, "{s} {d}", .{ name, self.operand }) catch "Error";
    }
};
