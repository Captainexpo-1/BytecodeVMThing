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

pub fn valueToString(val_type: ValueType, val: StackWord, allocator: std.mem.Allocator) ![:0]const u8 {
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
            const str_pointer = @as([*:0]const u8, @ptrFromInt(@as(usize, val)));
            const str_len = std.mem.len(str_pointer);
            const str_slice = str_pointer[0..str_len];
            return try stringutil.concat(str_slice, "", allocator);
        },
        .Bool => {
            const boolval = Global.fromStackWord(u64, val) != 0;
            return try stringutil.fromBool(boolval, allocator);
        },
        .Pointer => {
            const ptr = @as(*const u8, @ptrFromInt(@as(usize, val)));
            return try stringutil.fromPointer(ptr, allocator);
        },
        else => return std.fmt.allocPrintZ(allocator, "Unsupported type for string conversion: {s}", .{@tagName(val_type)}),
    }
}
