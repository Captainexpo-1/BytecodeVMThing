const std = @import("std");

const Instruction = @import("instruction.zig").Instruction;

const Value = @import("value.zig").Value;
const ValueType = @import("value.zig").ValueType;

pub const Function = struct {
    arg_types: []ValueType,
    return_type: ValueType,
    code: []Instruction,
    pub fn toString(self: Function) []const u8 {
        _ = self;
        return "Function";
    }
};
