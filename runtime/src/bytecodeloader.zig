const std = @import("std");
const stringutil = @import("string.zig");
const ValueType = @import("value.zig").ValueType;
const Instruction = @import("instruction.zig").Instruction;
const OpCode = @import("instruction.zig").OpCode;
const Function = @import("bytecode.zig").Function;
const Global = @import("global.zig");
const StackWord = Global.StackWord;
const MachineData = @import("machine.zig").MachineData;
const Value = @import("value.zig");
const allocator = std.heap.page_allocator;

const ByteCodeParseError = error{
    InvalidBytecode,
    Unimplemented,
};

fn readFunction(data: []const u8, pos: *usize) !Function {
    const return_type = @as(ValueType, @enumFromInt(data[pos.*]));
    pos.* += 1;
    const num_args = data[pos.*];
    pos.* += 1;
    std.log.debug("Function return type: {d}, num_args: {d}", .{ @as(u8, @intFromEnum(return_type)), num_args });

    var arg_types = std.ArrayList(ValueType).init(allocator);

    for (0..num_args) |_| {
        const arg_type = @as(ValueType, @enumFromInt(data[pos.*]));
        pos.* += 1;
        try arg_types.append(arg_type);
    }
    std.log.debug("ptr: {d}", .{pos.*});

    const num_instr_buffer = data[pos.* .. pos.* + 2];
    if (pos.* + 2 > data.len) return ByteCodeParseError.InvalidBytecode;
    const num_instructions = std.mem.readInt(u16, @ptrCast(&num_instr_buffer[0]), std.builtin.Endian.little);
    std.log.debug("Number of instructions: {d}", .{num_instructions});
    pos.* += @sizeOf(u16);
    var instructions = std.ArrayList(Instruction).init(allocator);

    for (0..num_instructions) |_| {
        const instr_type = @as(OpCode, @enumFromInt(data[pos.*]));
        pos.* += 1;
        const arg = data[pos.*];
        pos.* += 1;
        const instr = Instruction.newInstruction(instr_type, arg);
        std.log.debug("Instruction: {s}", .{instr.toString()});
        try instructions.append(instr);
    }

    return Function{
        .arg_types = arg_types.items,
        .return_type = return_type,
        .code = instructions.items,
    };
}

fn readValue(data: []const u8, pos: *usize) !std.meta.Tuple(&[_]type{ StackWord, ValueType }) {
    const value_type: ValueType = @enumFromInt(data[pos.*]);
    pos.* += 1;

    var ret: StackWord = 0;

    switch (value_type) {
        .Float => {
            if (pos.* + 8 > data.len) return ByteCodeParseError.InvalidBytecode;
            const buf = data[pos.* .. pos.* + 8];

            var intval = std.mem.readInt(i64, @ptrCast(buf.ptr), std.builtin.Endian.little);
            const float_value = (@as(*f64, @ptrCast(&intval))).*;

            pos.* += 8;
            ret = Global.toStackWord(float_value);
        },
        .Int => {
            if (pos.* + 8 > data.len) return ByteCodeParseError.InvalidBytecode;
            const buf = data[pos.* .. pos.* + 8];

            const intval: i64 = std.mem.readInt(i64, @ptrCast(buf.ptr), std.builtin.Endian.little);
            pos.* += 8;
            ret = Global.toStackWord(intval);
        },
        .String => {
            if (pos.* >= data.len) return ByteCodeParseError.InvalidBytecode;

            // Read total length
            const total_len = std.mem.readInt(u32, @ptrCast(&data[pos.*]), std.builtin.Endian.little);
            pos.* += @sizeOf(u32);

            if (pos.* + total_len > data.len) return ByteCodeParseError.InvalidBytecode;

            // Read string length
            const str_len = std.mem.readInt(u32, @ptrCast(&data[pos.*]), std.builtin.Endian.little);
            pos.* += @sizeOf(u32);

            if (pos.* + str_len > data.len) return ByteCodeParseError.InvalidBytecode;

            // Allocate memory for length-prefixed string (8 bytes for length + string data)
            const memory = allocator.alloc(u8, 8 + str_len) catch return ByteCodeParseError.InvalidBytecode;

            // Store length in first 8 bytes
            @as(*usize, @ptrCast(@alignCast(memory.ptr))).* = str_len;

            // Copy string data after the length
            @memcpy(memory[8..], data[pos.* .. pos.* + str_len]);

            pos.* += str_len;

            ret = Global.toStackWord(@as(usize, @intFromPtr(memory.ptr)));
        },
        .Bool => {
            if (pos.* >= data.len) return ByteCodeParseError.InvalidBytecode;
            const bool_value = data[pos.*] != 0;
            pos.* += 1;
            ret = Global.toStackWord(@as(u64, @intFromBool(bool_value)));
        },
        .List => {
            if (pos.* >= data.len) return ByteCodeParseError.InvalidBytecode;
            const list_pointer = @as(*Value, @ptrFromInt(@as(usize, data[pos.*])));
            pos.* += 8;
            ret = Global.toStackWord(@as(usize, @intFromPtr(list_pointer)));
        },
        .None => ret = Global.toStackWord(@as(u64, 0)),
        else => {
            std.log.debug("Unimplemented value type: {d}", .{@intFromEnum(value_type)});
            return ByteCodeParseError.Unimplemented;
        },
    }

    return .{ ret, value_type };
}

pub fn loadBytecode(data: []const u8) !MachineData {
    var pos: usize = 0;

    const num_constants = data[0];

    pos += 1;

    var constant_types = std.ArrayList(ValueType).init(allocator);
    defer constant_types.deinit();
    var constants = allocator.alloc(StackWord, num_constants) catch return ByteCodeParseError.InvalidBytecode;
    for (0..num_constants) |i| {
        const value = try readValue(data, &pos);
        constants[i] = value[0];
        constant_types.append(value[1]) catch return ByteCodeParseError.InvalidBytecode;
    }

    // Print loaded constants for debugging
    // Print loaded constants for debugging
    std.log.debug("Loaded constants:", .{});
    for (constants, constant_types.items) |v, t| {
        const str = Value.valueToString(t, v, allocator) catch {
            std.log.err("Error converting value to string: {s}", .{@tagName(t)});
            return ByteCodeParseError.InvalidBytecode;
        };
        std.log.debug("  Constant: {s}", .{str});
    }
    const num_functions = data[pos];
    std.log.debug("Number of functions: {d}", .{num_functions});
    pos += 1;

    var functions = allocator.alloc(Function, num_functions) catch return ByteCodeParseError.InvalidBytecode;
    for (0..num_functions) |i| {
        const function = try readFunction(data, &pos);
        functions[i] = function;
    }
    std.log.debug("Loaded functions:", .{});
    return MachineData{
        .functions = functions,
        .constants = constants,
    };
}

pub fn loadBytecodeFromFile(path: []const u8) !MachineData {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const data = try file.readToEndAlloc(allocator, 1024 * 1024);

    return loadBytecode(data);
}
