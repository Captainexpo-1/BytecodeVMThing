const std = @import("std");

const String = @import("string.zig").String;

const Value = @import("value.zig").Value;
const ValueType = @import("value.zig").ValueType;
const _Value = @import("value.zig")._Value;

const Instruction = @import("instruction.zig").Instruction;
const _Instruction = @import("instruction.zig").OpCode;

const Function = @import("bytecode.zig").Function;

const Machine = @import("machine.zig").Machine;
const MachineData = @import("machine.zig").MachineData;
const OpCode = @import("instruction.zig").OpCode;

const FFI = @import("ffi.zig");

const loadBytecode = @import("bytecodeloader.zig").loadBytecode;
const loadBytecodeFromFile = @import("bytecodeloader.zig").loadBytecodeFromFile;

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const args = try std.process.argsAlloc(alloc);

    const data = try loadBytecodeFromFile(args[1]);

    var machine = Machine.init(.Halted, 1024);
    defer machine.deinit();

    for (data.functions) |func| {
        machine.addFunction(func);
    }
    for (data.constants) |const_val| {
        machine.addConstant(const_val);
    }

    FFI.initFFI();

    machine.prepare();

    var timer = try std.time.Timer.start();

    machine.run();

    const len: f64 = @floatFromInt(timer.read());

    machine.dumpDebugData();

    std.debug.print("Took {d}ms, {d}ms per instruction\n", .{ len / 1e+6, len / @as(f64, @floatFromInt(machine.instructions_executed)) / 1e+6 });

    return;
}
