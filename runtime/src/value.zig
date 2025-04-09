const std = @import("std");
const String = @import("string.zig").String;

pub const _Value = union(enum) {
    float: f64,
    string: String,
    bool: bool,
    none: void,
};

pub const ValueType = enum {
    Float,
    String,
    Bool,
    None,
};

pub const Value = struct {
    value: _Value,
    vtype: ValueType,

    pub fn add(self: Value, other: Value) Value {
        if (self.vtype == .Float and other.vtype == .Float) {
            return newValue(_Value{ .float = self.value.float + other.value.float }, .Float);
        }
        std.debug.print("Type mismatch in add\n", .{});
        return newValue(_Value{ .none = {} }, .None);
    }

    pub fn sub(self: Value, other: Value) Value {
        if (self.vtype == .Float and other.vtype == .Float) {
            return newValue(_Value{ .float = self.value.float - other.value.float }, .Float);
        }
        std.debug.print("Type mismatch in sub\n", .{});
        return Value.nullValue();
    }

    pub fn mul(self: Value, other: Value) Value {
        if (self.vtype == .Float and other.vtype == .Float) {
            return newValue(_Value{ .float = self.value.float * other.value.float }, .Float);
        }
        std.debug.print("Type mismatch in mul\n", .{});
        return Value.nullValue();
    }

    pub fn div(self: Value, other: Value) Value {
        if (self.vtype == .Float and other.vtype == .Float) {
            if (other.value.float == 0.0) {
                std.debug.print("Division by zero\n", .{});
                return Value.nullValue();
            }
            return newValue(_Value{ .float = self.value.float / other.value.float }, .Float);
        }
        std.debug.print("Type mismatch in div\n", .{});
        return Value.nullValue();
    }

    pub fn newValue(v: _Value, t: ValueType) Value {
        return Value{
            .value = v,
            .vtype = t,
        };
    }

    pub fn nullValue() Value {
        return newValue(_Value{ .none = {} }, .None);
    }

    pub fn eq(self: Value, b: Value) bool {
        if (b.vtype != self.vtype) {
            return false;
        }
        return switch (self.vtype) {
            ValueType.Float => self.value.float == b.value.float,
            ValueType.String => self.value.string.isEqual(b.value.string),
            ValueType.Bool => self.value.bool == b.value.bool,
            ValueType.None => true,
        };
    }

    pub fn gt(self: Value, b: Value) bool {
        if (self.vtype != .Float or b.vtype != .Float) {
            return false;
        }
        return self.value.float > b.value.float;
    }
    pub fn lt(self: Value, b: Value) bool {
        if (self.vtype != .Float or b.vtype != .Float) {
            return false;
        }
        return self.value.float < b.value.float;
    }

    pub fn toString(self: Value) String {
        return switch (self.vtype) {
            ValueType.Float => String.fromFloat(self.value.float),
            ValueType.String => self.value.string,
            ValueType.Bool => String.fromBool(self.value.bool),
            ValueType.None => String.new("null"),
        };
    }
};
