const std = @import("std");

pub const OpCode = enum(u8) {
    // No operation
    Nop,

    // Stack manipulation
    Dup,
    Swap,

    // Arithmetic (typed)
    AddI,
    AddF,
    SubI,
    SubF,
    MulI,
    MulF,
    DivI,
    DivF,
    ModI,

    // Logical (typed)
    AndB, // Boolean AND
    OrB,
    NotB,
    XorB,

    // Bitwise (typed, usually int)
    ShlI,
    ShrI,
    BitAndI,
    BitOrI,
    BitXorI,

    // Comparison (typed)
    EqI,
    EqF,
    NeqI,
    NeqF,
    GtI,
    GtF,
    LtI,
    LtF,
    GeI,
    GeF,
    LeI,
    LeF,

    // Control flow
    Jmp, // Unconditional jump
    Jz, // Jump if zero (int or float == 0)
    Jnz, // Jump if nonzero
    Jif, // Jump if top of stack is true (bool)
    Call, // Call function at address
    Ret, // Return from function

    // Variable stack frame access
    LoadVarI,
    LoadVarF,
    StoreVarI,
    StoreVarF,

    // Pointer operations (typed)
    LoadAddrI,
    DerefI,
    StoreDerefI,

    LoadAddrF,
    DerefF,
    StoreDerefF,

    // Heap (typed)
    AllocI,
    AllocF,
    FreeI,
    FreeF,

    // Casts (typed)
    CastIToF,
    CastFToI,

    // Constants
    LoadConstI,
    LoadConstF,
    LoadConstB, // if you're storing bools too

    // Halt VM
    Halt,

    // Foreign function interface
    CallFFI,
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
