const std = @import("std");
const Value = @import("value.zig").Value;

pub const OpCode = enum(u8) {
    // No operation
    Nop,

    // Stack manipulation
    Dup,
    Swap,

    // Arithmetic operations
    Add,
    Sub,
    Mul,
    Div,
    Mod,

    // Logical operations
    And,
    Or,
    Not,
    Xor,

    // Bitwise operations
    Shl,
    Shr,
    BitAnd,
    BitOr,
    BitXor,

    // Comparison operations
    Eq,
    Neq,
    Gt,
    Lt,
    Ge,
    Le,

    // Control flow
    Jmp,
    Jz,
    Jnz,
    Jif,
    Call,
    Ret,

    // Variables
    LoadVar,
    StoreVar,

    // Pointer operations
    LoadAddress, // Create a pointer to a variable
    Deref, // Access the value a pointer points to
    StoreDeref, // Update the value a pointer points to

    // Heap
    Alloc,
    Free,

    // Cast operations
    CastToInt,
    CastToFloat,

    // Load and halt
    LoadConst,
    Halt,
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
