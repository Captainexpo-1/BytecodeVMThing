const std = @import("std");
const String = @import("string.zig").String;

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
