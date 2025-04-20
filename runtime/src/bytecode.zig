const std = @import("std");

const Instruction = @import("instruction.zig").Instruction;

const ValueType = @import("value.zig").ValueType;

pub const Function = struct {
    arg_types: []const ValueType,
    return_type: ValueType,
    code: []const Instruction,
    pub fn toString(self: Function) []const u8 {
        _ = self;
        return "Function";
    }
};
