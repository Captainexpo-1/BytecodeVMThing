const std = @import("std");
const String = @import("string.zig").String;
const Value = @import("value.zig").Value;
const ValueType = @import("value.zig").ValueType;
const Instruction = @import("instruction.zig").Instruction;
const OpCode = @import("instruction.zig").OpCode;
const Function = @import("bytecode.zig").Function;

const MachineData = @import("machine.zig").MachineData;

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

fn readValue(data: []const u8, pos: *usize) !Value {
    const value_type: ValueType = @enumFromInt(data[pos.*]);
    pos.* += 1;

    switch (value_type) {
        .Float => {
            if (pos.* + 8 > data.len) return ByteCodeParseError.InvalidBytecode;
            const buf = data[pos.* .. pos.* + 8];

            var intval = std.mem.readInt(i64, @ptrCast(buf.ptr), std.builtin.Endian.little);
            const float_value = (@as(*f64, @ptrCast(&intval))).*;

            pos.* += 8;
            return Value.newValue(.{ .float = float_value }, .Float);
        },
        .Int => {
            if (pos.* + 8 > data.len) return ByteCodeParseError.InvalidBytecode;
            const buf = data[pos.* .. pos.* + 8];

            const intval: i64 = std.mem.readInt(i64, @ptrCast(buf.ptr), std.builtin.Endian.little);
            pos.* += 8;
            return Value.newValue(.{ .int = intval }, .Int);
        },
        .String => {
            if (pos.* >= data.len) return ByteCodeParseError.InvalidBytecode;

            // First read the total length
            const total_len = std.mem.readInt(u32, @ptrCast(&data[pos.*]), std.builtin.Endian.little);
            pos.* += @sizeOf(u32);

            if (pos.* + total_len > data.len) return ByteCodeParseError.InvalidBytecode;

            // Then read the actual string length (which is embedded inside)
            const str_len = std.mem.readInt(u32, @ptrCast(&data[pos.*]), std.builtin.Endian.little);
            pos.* += @sizeOf(u32);

            if (pos.* + str_len > data.len) return ByteCodeParseError.InvalidBytecode;

            // Now get the actual string data (without any length prefixes)
            const str_value = String{ .data = data[pos.* .. pos.* + str_len] };
            pos.* += str_len;

            return Value.newValue(.{ .string = str_value }, .String);
        },
        .Bool => {
            if (pos.* >= data.len) return ByteCodeParseError.InvalidBytecode;
            const bool_value = data[pos.*] != 0;
            pos.* += 1;
            return Value.newValue(.{ .bool = bool_value }, .Bool);
        },
        .List => unreachable,
        .None => return Value.newValue(.{ .none = {} }, .None),
        else => {
            std.log.debug("Unimplemented value type: {d}", .{@intFromEnum(value_type)});
            return ByteCodeParseError.Unimplemented;
        },
    }
}

pub fn loadBytecode(data: []const u8) !MachineData {
    var pos: usize = 0;

    const num_constants = data[0];

    pos += 1;

    var constants = allocator.alloc(Value, num_constants) catch return ByteCodeParseError.InvalidBytecode;
    for (0..num_constants) |i| {
        const value = try readValue(data, &pos);
        constants[i] = value;
    }

    // Print loaded constants for debugging
    std.log.debug("Loaded constants:", .{});
    for (constants) |v| {
        std.log.debug("  Constant: {s}", .{v.toString().data});
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
