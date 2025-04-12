const std = @import("std");

const String = @import("string.zig").String;

const Value = @import("value.zig").Value;
const ValueType = @import("value.zig").ValueType;
const _Value = @import("value.zig")._Value;

const Instruction = @import("instruction.zig").Instruction;
const _Instruction = @import("instruction.zig").OpCode;

const Function = @import("bytecode.zig").Function;

const Machine = @import("machine.zig").Machine;
const OpCode = @import("instruction.zig").OpCode;

const loadBytecode = @import("bytecodeloader.zig").loadBytecode;
const loadBytecodeFromFile = @import("bytecodeloader.zig").loadBytecodeFromFile;

fn testMachine() void {

    // Example ByteCode and Machine initialization
    var fn_1 = [_]Instruction{
        Instruction.newInstruction(_Instruction.Nop, 0),
        Instruction.newInstruction(_Instruction.LoadConst, 0),
        Instruction.newInstruction(_Instruction.Call, 1),
        Instruction.newInstruction(_Instruction.Add, 0),
        Instruction.newInstruction(_Instruction.Halt, 0),
    };
    const fn_1_bytecode = fn_1[0..];

    var machine = Machine.init(.Halted, 1024);
    defer machine.deinit();

    machine.addFunction(Function{
        .arg_types = &.{},
        .return_type = .None,
        .code = fn_1_bytecode,
    });

    var fn_2 = [_]Instruction{
        Instruction.newInstruction(_Instruction.LoadConst, 0),
        Instruction.newInstruction(_Instruction.Ret, 0),
    };

    const fn_2_bytecode = fn_2[0..];

    machine.addFunction(Function{
        .arg_types = &.{},
        .return_type = .Float,
        .code = fn_2_bytecode,
    });

    machine.addConstant(Value.newValue(.{ .float = 42.0 }, .Float));
    machine.addConstant(Value.newValue(.{ .float = 3.14 }, .Float));

    // Run the machine
    machine.prepare();
    machine.run();

    machine.dumpDebugData();
}

pub fn argsAsArray(allocator: std.mem.Allocator) ![][]u8 {
    const args = try std.process.argsAlloc(allocator);
    return args;
}

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const args = try argsAsArray(alloc);

    const data = try loadBytecodeFromFile(args[1]);

    var machine = Machine.init(.Halted, 1024);
    defer machine.deinit();

    for (data.functions) |func| {
        machine.addFunction(func);
    }
    for (data.constants) |const_val| {
        machine.addConstant(const_val);
    }
    machine.prepare();

    var timer = try std.time.Timer.start();

    machine.run();

    const len: f64 = @floatFromInt(timer.read());

    machine.dumpDebugData();

    std.debug.print("Took {d}ms, {d}ms per instruction\n", .{ len / 1e+6, len / @as(f64, @floatFromInt(machine.instructions_executed)) / 1e+6 });

    return;
}
