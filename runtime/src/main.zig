const std = @import("std");

const String = @import("string.zig").String;

const Instruction = @import("instruction.zig").Instruction;
const _Instruction = @import("instruction.zig").OpCode;

const Function = @import("bytecode.zig").Function;

const Machine = @import("machine.zig").Machine;
const OpCode = @import("instruction.zig").OpCode;

const ValueType = @import("value.zig").ValueType;
const Global = @import("global.zig");
const StackWord = Global.StackWord;

const loadBytecode = @import("bytecodeloader.zig").loadBytecodeFromFile;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = std.process.argsAlloc(allocator) catch |err| {
        std.log.err("Failed to allocate args: {?}", .{err});
        return err;
    };
    defer std.process.argsFree(allocator, args);
    if (args.len != 2) {
        std.log.err("Usage: {s} <bytecode file>", .{args[0]});
        return error.InvalidArgumentCount;
    }

    const bytecode_file = args[1];
    const bytecode = loadBytecode(bytecode_file) catch |err| {
        std.log.err("Failed to load bytecode: {?}", .{err});
        return err;
    };

    var machine = Machine.init(.Halted);
    defer machine.deinit();

    machine.loadFromMachineData(bytecode);

    machine.prepare();
    var timer = try std.time.Timer.start();

    machine.run();

    const len: f64 = @floatFromInt(timer.read());

    std.log.debug("Took {d}ms, {d}ms per instruction", .{ len / 1e+6, len / @as(f64, @floatFromInt(machine.instructions_executed)) / 1e+6 });

    return;
}
