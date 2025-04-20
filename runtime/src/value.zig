const std = @import("std");
const stringutil = @import("string.zig");
const Global = @import("global.zig");
const StackWord = Global.StackWord;
pub const ValueType = enum {
    Int,
    Float,
    String,
    Bool,
    None,
    List,
    Struct,
    Pointer,
};

pub fn valueToString(val_type: ValueType, val: StackWord, allocator: std.mem.Allocator) ![]const u8 {
    switch (val_type) {
        .Int => {
            const intval = Global.fromStackWord(i64, val);
            return try stringutil.fromInt(intval, allocator);
        },
        .Float => {
            const floatval = Global.fromStackWord(f64, val);
            return try stringutil.fromFloat(floatval, allocator);
        },
        .String => {
            const str_pointer = @as([*]const u8, @ptrFromInt(@as(usize, val)));
            // Add @alignCast to ensure proper alignment for usize
            const len = @as(*const usize, @ptrCast(@alignCast(str_pointer))).*;
            return str_pointer[8 .. 8 + len]; // Adjust based on how length is stored
        },
        .Bool => {
            const boolval = Global.fromStackWord(u64, val) != 0;
            return try stringutil.fromBool(boolval, allocator);
        },
        else => return "Unsupported type",
    }
}
