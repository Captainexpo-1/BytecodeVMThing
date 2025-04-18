const std = @import("std");
const String = @import("string.zig").String;

// New type
pub const StructInstance = struct {
    fields: std.StringHashMap(Value),
    type_name: []const u8,

    pub fn init(allocator: std.mem.Allocator, type_name: []const u8) *StructInstance {
        const instance = allocator.create(StructInstance) catch unreachable;
        instance.* = StructInstance{
            .fields = std.StringHashMap(Value).init(allocator),
            .type_name = type_name,
        };
        return instance;
    }

    pub fn deinit(self: *StructInstance) void {
        self.fields.deinit();
    }
};

pub const _Value = union(enum) {
    float: f64,
    int: i64,
    string: String,
    bool: bool,
    none: void,
    list: std.ArrayList(Value),
    struct_inst: *StructInstance,
    pointer: *Value,
};
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

pub const Value = struct {
    value: _Value,
    vtype: ValueType,

    pub fn add(self: Value, other: Value) Value {
        if (self.vtype == .Float and other.vtype == .Float) {
            return newValue(_Value{ .float = self.value.float + other.value.float }, .Float);
        }
        if (self.vtype == .Int and other.vtype == .Int) {
            return newValue(_Value{ .int = self.value.int + other.value.int }, .Int);
        }
        std.debug.print("Type mismatch in add {s} and {s}\n", .{ @tagName(self.vtype), @tagName(other.vtype) });
        return newValue(_Value{ .none = {} }, .None);
    }

    pub fn sub(self: Value, other: Value) Value {
        if (self.vtype == .Float and other.vtype == .Float) {
            return newValue(_Value{ .float = self.value.float - other.value.float }, .Float);
        }
        if (self.vtype == .Int and other.vtype == .Int) {
            return newValue(_Value{ .int = self.value.int - other.value.int }, .Int);
        }
        std.debug.print("Type mismatch in sub {s} and {s}\n", .{ @tagName(self.vtype), @tagName(other.vtype) });
        return Value.nullValue();
    }

    pub fn mul(self: Value, other: Value) Value {
        if (self.vtype == .Float and other.vtype == .Float) {
            return newValue(_Value{ .float = self.value.float * other.value.float }, .Float);
        }
        if (self.vtype == .Int and other.vtype == .Int) {
            return newValue(_Value{ .int = self.value.int * other.value.int }, .Int);
        }
        std.debug.print("Type mismatch in mul {s} and {s}\n", .{ @tagName(self.vtype), @tagName(other.vtype) });
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
        if (self.vtype == .Int and other.vtype == .Int) {
            if (other.value.int == 0) {
                std.debug.print("Division by zero\n", .{});
                return Value.nullValue();
            }
            return newValue(_Value{ .int = @divFloor(self.value.int, other.value.int) }, .Int);
        }
        std.debug.print("Type mismatch in div {s} and {s}\n", .{ @tagName(self.vtype), @tagName(other.vtype) });
        return Value.nullValue();
    }

    pub fn newValue(v: _Value, t: ValueType) Value {
        return Value{
            .value = v,
            .vtype = t,
        };
    }

    pub fn newList(subtype: ValueType) Value {
        const t = .List;
        t.subtype = subtype;
        return Value{
            .value = _Value{ .list = std.ArrayList(Value).init(std.heap.page_allocator) },
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
            ValueType.Int => self.value.int == b.value.int,
            ValueType.Float => self.value.float == b.value.float,
            ValueType.String => self.value.string.isEqual(b.value.string),
            ValueType.Bool => self.value.bool == b.value.bool,
            ValueType.None => true,
            ValueType.List => {
                if (self.value.list.items.len != b.value.list.items.len) return false;
                for (self.value.list.items, 0..self.value.list.items.len) |item, i| {
                    if (!item.eq(b.value.list.items[i])) return false;
                }
                return true;
            },
            ValueType.Struct => {
                if (!std.mem.eql(u8, self.value.struct_inst.type_name, b.value.struct_inst.type_name)) return false;
                if (self.value.struct_inst.fields.count() != b.value.struct_inst.fields.count()) return false;
                var keyIterator = self.value.struct_inst.fields.keyIterator();
                for (0..keyIterator.len) |_| {
                    const key = keyIterator.next() orelse break;
                    const self_field_value = self.value.struct_inst.fields.get(key.*) orelse return false;
                    const b_field_value = b.value.struct_inst.fields.get(key.*) orelse return false;
                    if (!self_field_value.eq(b_field_value)) return false;
                }
                return true;
            },
            ValueType.Pointer => {
                return self.value.pointer == b.value.pointer;
            },
        };
    }

    pub fn gt(self: Value, b: Value) bool {
        if (self.vtype == .Float and b.vtype == .Float) {
            return self.value.float > b.value.float;
        }
        if (self.vtype == .Int and b.vtype == .Int) {
            return self.value.int > b.value.int;
        }
        std.debug.print("Type mismatch in gt {s} and {s}\n", .{ @tagName(self.vtype), @tagName(b.vtype) });
        return false;
    }

    pub fn lt(self: Value, b: Value) bool {
        if (self.vtype == .Float and b.vtype == .Float) {
            return self.value.float < b.value.float;
        }
        if (self.vtype == .Int and b.vtype == .Int) {
            return self.value.int < b.value.int;
        }
        std.debug.print("Type mismatch in lt {s} and {s}\n", .{ @tagName(self.vtype), @tagName(b.vtype) });
        return false;
    }

    pub fn toString(self: Value) String {
        return switch (self.vtype) {
            ValueType.Int => String.fromInt(self.value.int),
            ValueType.Float => String.fromFloat(self.value.float),
            ValueType.String => self.value.string,
            ValueType.Bool => String.fromBool(self.value.bool),
            ValueType.None => String.new("null"),
            ValueType.List => {
                var buffer = std.ArrayList(String).init(std.heap.page_allocator);
                defer buffer.deinit();

                var totallen: usize = 0;

                for (self.value.list.items) |item| {
                    const s = item.toString();
                    totallen += s.len();
                    buffer.append(s) catch {};
                }

                totallen += 2 + buffer.items.len * 2 + 1; // Add [] and ", " for every item, and a '\n'

                const final = std.heap.page_allocator.alloc(u8, totallen) catch return String{ .data = "" };

                var pos: usize = 0;
                final[pos] = '[';
                pos += 1;
                for (buffer.items, 0..buffer.items.len) |item, i| {
                    const s = item.toSlice();
                    for (s) |c| {
                        final[pos] = c;
                        pos += 1;
                    }
                    if (i < buffer.items.len - 1) {
                        final[pos] = ',';
                        pos += 1;
                        final[pos] = ' ';
                        pos += 1;
                    }
                }
                final[pos] = ']';
                return String{ .data = final[0 .. pos + 1] };
            },
            ValueType.Struct => {
                var buffer = std.ArrayList(String).init(std.heap.page_allocator);
                defer buffer.deinit();

                var keyIterator = self.value.struct_inst.fields.keyIterator();

                for (0..keyIterator.len) |_| {
                    const key = keyIterator.next() orelse break;
                    const field_value = self.value.struct_inst.fields.get(key.*);
                    if (field_value) |value| {
                        const d = std.fmt.allocPrint(std.heap.page_allocator, "{s}: {s}", .{ key, value.toString().toSlice() }) catch unreachable;
                        const field_string = String{ .data = d };
                        buffer.append(field_string) catch {};
                    }
                }

                var totallen: usize = 0;
                for (buffer.items) |item| {
                    totallen += item.len() + 2; // Add 2 for the curly braces
                }
                totallen += 2; // For the outer curly braces

                const final = std.heap.page_allocator.alloc(u8, totallen) catch return String{ .data = "" };

                var pos: usize = 0;
                final[pos] = '{';
                pos += 1;
                for (buffer.items, 0..buffer.items.len) |item, i| {
                    const s = item.toSlice();
                    for (s) |c| {
                        final[pos] = c;
                        pos += 1;
                    }
                    if (i < buffer.items.len - 1) {
                        final[pos] = ',';
                        pos += 1;
                        final[pos] = ' ';
                        pos += 1;
                    }
                }
                final[pos] = '}';
                return String{ .data = final[0 .. pos + 1] };
            },
            ValueType.Pointer => {
                const val = self.value.pointer.*;
                _ = val;
                return String{ .data = std.fmt.allocPrint(std.heap.page_allocator, "Ptrto({any})", .{self.value.pointer}) catch "error" };
            },
        };
    }

    pub fn append(self: Value, other: Value) Value {
        if (self.vtype == .String and other.vtype == .String) {
            return newValue(_Value{ .string = self.value.string.add(other.value.string) }, .String);
        }
        if (self.vtype == .List and other.vtype == self.vtype.subtype) {
            self.value.list.append(other);
            return self;
        }
        std.debug.print("Type mismatch in append {s} and {s}\n", .{ @tagName(self.vtype), @tagName(other.vtype) });
        return Value.nullValue();
    }

    pub fn initNone() Value {
        return newValue(_Value{ .none = {} }, .None);
    }
};
