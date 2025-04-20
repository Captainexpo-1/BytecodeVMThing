const std = @import("std");
const String = @import("string.zig").String;
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

pub fn valueToString(val_type: ValueType, val: StackWord, allocator: std.mem.Allocator) !String {
    switch (val_type) {
        .Int => {
            const intval = Global.fromStackWord(i64, val);
            return String.new(try std.fmt.allocPrint(allocator, "{d}", .{intval}));
        },
        .Float => {
            const floatval = Global.fromStackWord(f64, val);
            return String.new(try std.fmt.allocPrint(allocator, "{d}", .{floatval}));
        },
        .String => {
            const str_pointer = @as(*String, @ptrFromInt(@as(usize, val)));
            return str_pointer.*;
        },
        .Bool => {
            const boolval = Global.fromStackWord(u64, val) != 0;
            return String.new(try std.fmt.allocPrint(allocator, "{any}", .{boolval}));
        },
        else => return String.new("Unsupported type"),
    }
}
