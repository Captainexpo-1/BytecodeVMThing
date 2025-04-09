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
    std.debug.print("Function return type: {d}, num_args: {d}\n", .{ @as(u8, @intFromEnum(return_type)), num_args });

    var arg_types = std.ArrayList(ValueType).init(allocator);

    for (0..num_args) |_| {
        const arg_type = @as(ValueType, @enumFromInt(data[pos.*]));
        pos.* += 1;
        try arg_types.append(arg_type);
    }
    std.debug.print("ptr: {d}\n", .{pos.*});

    const num_instr_buffer = data[pos.* .. pos.* + 2];
    if (pos.* + 2 > data.len) return ByteCodeParseError.InvalidBytecode;
    const num_instructions = std.mem.readInt(u16, @ptrCast(&num_instr_buffer[0]), std.builtin.Endian.little);
    std.debug.print("Number of instructions: {d}\n", .{num_instructions});
    pos.* += @sizeOf(u16);
    var instructions = std.ArrayList(Instruction).init(allocator);

    for (0..num_instructions) |_| {
        const instr_type = @as(OpCode, @enumFromInt(data[pos.*]));
        pos.* += 1;
        const arg = data[pos.*];
        pos.* += 1;
        const instr = Instruction.newInstruction(instr_type, arg);
        std.debug.print("Instruction: {s}\n", .{instr.toString()});
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
        .String => {
            if (pos.* >= data.len) return ByteCodeParseError.InvalidBytecode;

            const strlen = std.mem.readInt(u32, @ptrCast(&data[pos.*]), std.builtin.Endian.little);
            pos.* += @sizeOf(u32);
            if (pos.* + strlen > data.len) return ByteCodeParseError.InvalidBytecode;
            const str_value = String{ .data = data[pos.* + 1 .. pos.* + strlen] };
            pos.* += strlen;
            return Value.newValue(.{ .string = str_value }, .String);
        },
        .Bool => {
            if (pos.* >= data.len) return ByteCodeParseError.InvalidBytecode;
            const bool_value = data[pos.*] != 0;
            pos.* += 1;
            return Value.newValue(.{ .bool = bool_value }, .Bool);
        },
        .None => return Value.newValue(.{ .none = {} }, .None),
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
    std.debug.print("Loaded constants:\n", .{});
    for (constants) |v| {
        std.debug.print("  Constant: {s}\n", .{v.toString().data});
    }
    const num_functions = data[pos];
    std.debug.print("Number of functions: {d}\n", .{num_functions});
    pos += 1;

    var functions = allocator.alloc(Function, num_functions) catch return ByteCodeParseError.InvalidBytecode;
    for (0..num_functions) |i| {
        const function = try readFunction(data, &pos);
        functions[i] = function;
    }
    std.debug.print("Loaded functions:\n", .{});
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
