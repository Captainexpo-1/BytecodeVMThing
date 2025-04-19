const std = @import("std");

const String = @import("string.zig").String;

const Instruction = @import("instruction.zig").Instruction;
const _Instruction = @import("instruction.zig").OpCode;

const Function = @import("bytecode.zig").Function;

const Machine = @import("machine.zig").Machine;
const OpCode = @import("instruction.zig").OpCode;
pub fn main() !void {
    var machine = Machine.init(.Halted);
    defer machine.deinit();

    machine.prepare();
    var timer = try std.time.Timer.start();

    machine.run();

    const len: f64 = @floatFromInt(timer.read());

    std.log.debug("Took {d}ms, {d}ms per instruction", .{ len / 1e+6, len / @as(f64, @floatFromInt(machine.instructions_executed)) / 1e+6 });

    return;
}
