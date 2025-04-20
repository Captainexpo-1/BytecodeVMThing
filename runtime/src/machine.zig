const std = @import("std");

const Instruction = @import("instruction.zig").Instruction;
const OpCode = @import("instruction.zig").OpCode;
const Function = @import("bytecode.zig").Function;
const Stack = @import("stack.zig").Stack;
const Heap = @import("heap.zig").Heap;
const global = @import("global.zig");
const StackWord = @import("global.zig").StackWord;

const FFI = @import("ffi.zig");

const allocator = std.heap.page_allocator;

/// A machine-word storing raw bits for ints, floats, and bools
pub const Machine = struct {
    current_callframe: ?*CallFrame,
    function_table: std.ArrayList(Function),
    call_stack: std.ArrayList(CallFrame),
    state: MachineState,
    stack: Stack,
    heap: Heap,
    constants: std.ArrayList(StackWord),
    instructions_executed: i64 = 0,

    pub fn prepare(self: *Machine) void {
        self.state = MachineState.Running;
        self.stack.sp = 0;
        if (self.current_callframe == null) {
            if (self.function_table.items.len > 0) {
                self.callFunction(0);
                self.current_callframe.?.pc = 0;
            } else {
                self.errorAndStop("No functions to call");
            }
        }
    }

    pub fn run(self: *Machine) void {
        while (self.state == MachineState.Running) {
            const frame = self.current_callframe orelse {
                self.errorAndStop("Call frame missing");
                break;
            };
            const code = self.function_table.items[frame.function_index].code;
            if (frame.pc >= code.len) {
                self.stop();
                break;
            }
            const instr = code[frame.pc];
            frame.pc += 1;
            self.executeInstruction(instr);
        }
    }

    fn executeInstruction(self: *Machine, instr: Instruction) void {
        self.instructions_executed += 1;
        switch (instr.instr) {

            // Constants
            OpCode.LoadConst => self.stack.push(self.constants.items[instr.operand]),

            // Arithmetic Int
            OpCode.AddI => {
                const b = @as(i64, @bitCast(self.stack.pop()));
                const a = @as(i64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(a + b)));
            },
            OpCode.SubI => {
                const b = @as(i64, @bitCast(self.stack.pop()));
                const a = @as(i64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(a - b)));
            },
            OpCode.MulI => {
                const b = @as(i64, @bitCast(self.stack.pop()));
                const a = @as(i64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(a * b)));
            },
            OpCode.DivI => {
                const b = @as(i64, @bitCast(self.stack.pop()));
                const a = @as(i64, @bitCast(self.stack.pop()));
                if (b == 0) {
                    self.errorAndStop("Division by zero");
                    return;
                }
                self.stack.push(@as(StackWord, @bitCast(@divFloor(a, b))));
            },
            OpCode.ModI => {
                const b = @as(i64, @bitCast(self.stack.pop()));
                const a = @as(i64, @bitCast(self.stack.pop()));
                if (b == 0) {
                    self.errorAndStop("Modulo by zero");
                    return;
                }
                self.stack.push(@as(StackWord, @bitCast(@mod(a, b))));
            },

            // Arithmetic Float
            OpCode.AddF => {
                const b = @as(f64, @bitCast(self.stack.pop()));
                const a = @as(f64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(a + b)));
            },
            OpCode.SubF => {
                const b = @as(f64, @bitCast(self.stack.pop()));
                const a = @as(f64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(a - b)));
            },
            OpCode.MulF => {
                const b = @as(f64, @bitCast(self.stack.pop()));
                const a = @as(f64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(a * b)));
            },
            OpCode.DivF => {
                const b = @as(f64, @bitCast(self.stack.pop()));
                const a = @as(f64, @bitCast(self.stack.pop()));
                if (b == 0.0) {
                    self.errorAndStop("Division by zero");
                    return;
                }
                self.stack.push(@as(StackWord, @bitCast(a / b)));
            },

            // Bitwise
            OpCode.ShlI => {
                const b = @as(i64, @bitCast(self.stack.pop()));
                const a = @as(i64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(a << @as(u6, @intCast(b)))));
            },
            OpCode.ShrI => {
                const b = @as(i64, @bitCast(self.stack.pop()));
                const a = @as(i64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(a >> @as(u6, @intCast(b)))));
            },
            OpCode.BitAndI => {
                const b = @as(i64, @bitCast(self.stack.pop()));
                const a = @as(i64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(a & b)));
            },
            OpCode.BitOrI => {
                const b = @as(i64, @bitCast(self.stack.pop()));
                const a = @as(i64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(a | b)));
            },
            OpCode.BitXorI => {
                const b = @as(i64, @bitCast(self.stack.pop()));
                const a = @as(i64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(a ^ b)));
            },

            // Logical Boolean
            OpCode.AndB => {
                const bv = self.stack.pop() != 0;
                const av = self.stack.pop() != 0;
                self.stack.push(@as(StackWord, @bitCast(@as(u64, @intFromBool(av and bv)))));
            },
            OpCode.OrB => {
                const bv = self.stack.pop() != 0;
                const av = self.stack.pop() != 0;
                self.stack.push(@as(StackWord, @bitCast(@as(u64, @intFromBool(av or bv)))));
            },
            OpCode.NotB => {
                const v = self.stack.pop() == 0;
                self.stack.push(@as(StackWord, @bitCast(@as(u64, @intFromBool(v)))));
            },
            OpCode.XorB => {
                const bv = self.stack.pop() != 0;
                const av = self.stack.pop() != 0;
                self.stack.push(@as(StackWord, @bitCast(@as(u64, @intFromBool(av != bv)))));
            },

            // Comparisons Int
            OpCode.EqI => {
                const b = @as(i64, @bitCast(self.stack.pop()));
                const a = @as(i64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(@as(u64, @intFromBool((a == b))))));
            },
            OpCode.NeqI => {
                const b = @as(i64, @bitCast(self.stack.pop()));
                const a = @as(i64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(@as(u64, @intFromBool((a != b))))));
            },
            OpCode.GtI => {
                const b = @as(i64, @bitCast(self.stack.pop()));
                const a = @as(i64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(@as(u64, @intFromBool((a > b))))));
            },
            OpCode.LtI => {
                const b = @as(i64, @bitCast(self.stack.pop()));
                const a = @as(i64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(@as(u64, @intFromBool((a < b))))));
            },
            OpCode.GeI => {
                const b = @as(i64, @bitCast(self.stack.pop()));
                const a = @as(i64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(@as(u64, @intFromBool((a >= b))))));
            },
            OpCode.LeI => {
                const b = @as(i64, @bitCast(self.stack.pop()));
                const a = @as(i64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(@as(u64, @intFromBool((a <= b))))));
            },

            // Comparisons Float (EqF, NeqF, GtF, LtF, GeF, LeF) follow same pattern
            OpCode.EqF => {
                const b = @as(f64, @bitCast(self.stack.pop()));
                const a = @as(f64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(@as(u64, @intFromBool((a == b))))));
            },
            OpCode.NeqF => {
                const b = @as(f64, @bitCast(self.stack.pop()));
                const a = @as(f64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(@as(u64, @intFromBool((a != b))))));
            },
            OpCode.GtF => {
                const b = @as(f64, @bitCast(self.stack.pop()));
                const a = @as(f64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(@as(u64, @intFromBool((a > b))))));
            },
            OpCode.LtF => {
                const b = @as(f64, @bitCast(self.stack.pop()));
                const a = @as(f64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(@as(u64, @intFromBool((a < b))))));
            },
            OpCode.GeF => {
                const b = @as(f64, @bitCast(self.stack.pop()));
                const a = @as(f64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(@as(u64, @intFromBool((a >= b))))));
            },
            OpCode.LeF => {
                const b = @as(f64, @bitCast(self.stack.pop()));
                const a = @as(f64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(@as(u64, @intFromBool((a <= b))))));
            },

            // Control flow
            OpCode.Jmp => self.current_callframe.?.pc = instr.operand,
            OpCode.Jz => {
                const v = @as(i64, @bitCast(self.stack.pop()));
                if (v == 0) self.current_callframe.?.pc = instr.operand;
            },
            OpCode.Jnz => {
                const v = @as(i64, @bitCast(self.stack.pop()));
                if (v != 0) self.current_callframe.?.pc = instr.operand;
            },
            OpCode.Jif => {
                const v = self.stack.pop() != 0;
                if (v) self.current_callframe.?.pc = instr.operand;
            },
            OpCode.Call => self.callFunction(instr.operand),
            OpCode.TailCall => {
                const func_index = instr.operand;
                const func = self.function_table.items[func_index];
                const args_arr: []StackWord = self.stack.popN(func.arg_types.len);
                for (0..args_arr.len) |i| {
                    while (i >= self.current_callframe.?.local_vars.items.len) {
                        self.current_callframe.?.local_vars.append(0) catch {};
                    }
                    self.current_callframe.?.local_vars.items[i] = args_arr[i];
                }
                self.current_callframe.?.pc = 0;
            },
            OpCode.Ret => |_| {
                if (self.call_stack.items.len == 0) {
                    self.errorAndStop("Return underflow");
                    return;
                }
                var old_frame = self.call_stack.items[self.call_stack.items.len - 1];
                const return_pc = old_frame.return_pc;
                _ = self.call_stack.pop();
                old_frame.deinit();
                if (self.call_stack.items.len > 0) {
                    self.current_callframe = &self.call_stack.items[self.call_stack.items.len - 1];
                    self.current_callframe.?.pc = return_pc;
                } else {
                    self.current_callframe = null;
                    self.stop();
                }
            },
            // Variable access
            OpCode.LoadVarI => {
                const idx = instr.operand;
                const v = self.current_callframe.?.local_vars.items[idx];
                self.stack.push(v);
            },
            OpCode.StoreVarI => {
                const idx = instr.operand;
                const v = self.stack.pop();
                while (idx >= self.current_callframe.?.local_vars.items.len) {
                    self.current_callframe.?.local_vars.append(0) catch {};
                }
                self.current_callframe.?.local_vars.items[idx] = v;
            },
            OpCode.LoadVarF => {
                const idx = instr.operand;
                const v = self.current_callframe.?.local_vars.items[idx];
                self.stack.push(v);
            },
            OpCode.StoreVarF => {
                const idx = instr.operand;
                const v = self.stack.pop();
                while (idx >= self.current_callframe.?.local_vars.items.len) {
                    self.current_callframe.?.local_vars.append(0) catch {};
                }
                self.current_callframe.?.local_vars.items[idx] = v;
            },
            // Pointer operations
            OpCode.LoadAddrI => {
                // get the address of the variable at idx
                const idx = instr.operand;
                const ptr: *StackWord = &self.current_callframe.?.local_vars.items[idx];
                self.stack.push(@as(StackWord, @bitCast(@as(usize, @intFromPtr(ptr)))));
            },
            OpCode.DerefI => {
                const addr = @as(*i64, @ptrFromInt(@as(usize, @bitCast(self.stack.pop()))));
                self.stack.push(@as(StackWord, @bitCast(addr.*)));
            },
            OpCode.StoreDerefI => {
                const addr = @as(*i64, @ptrFromInt(@as(usize, @bitCast(self.stack.pop()))));
                const v = @as(i64, @bitCast(self.stack.pop()));
                addr.* = v;
            },
            OpCode.LoadAddrF => {
                // get the address of the variable at idx
                const idx = instr.operand;
                const ptr: *StackWord = &self.current_callframe.?.local_vars.items[idx];
                self.stack.push(@as(StackWord, @bitCast(@as(usize, @intFromPtr(ptr)))));
            },
            OpCode.DerefF => {
                const addr = @as(*f64, @ptrFromInt(@as(usize, @bitCast(self.stack.pop()))));
                self.stack.push(@as(StackWord, @bitCast(addr.*)));
            },
            OpCode.StoreDerefF => {
                const addr = @as(*f64, @ptrFromInt(@as(usize, @bitCast(self.stack.pop()))));
                const v = @as(f64, @bitCast(self.stack.pop()));
                addr.* = v;
            },
            OpCode.AllocI => {
                const size = @as(usize, @bitCast(self.stack.pop()));
                const ptr = self.heap.allocBytes(size) catch {
                    self.errorAndStop("Heap allocation failed");
                    return;
                };
                self.stack.push(@as(StackWord, @bitCast(@as(usize, @intFromPtr(ptr.ptr)))));
            },
            OpCode.AllocF => {
                const size = @as(usize, @bitCast(self.stack.pop()));
                const ptr = self.heap.allocBytes(size) catch {
                    self.errorAndStop("Heap allocation failed");
                    return;
                };
                self.stack.push(@as(StackWord, @bitCast(@as(usize, @intFromPtr(ptr.ptr)))));
            },
            OpCode.FreeI => {
                const ptr = @as(*i64, @ptrFromInt(@as(usize, @bitCast(self.stack.pop()))));
                self.heap.freeBytes(@as([*]u8, @ptrCast(ptr))[0..@sizeOf(i64)]);
            },
            OpCode.FreeF => {
                const ptr = @as(*f64, @ptrFromInt(@as(usize, @bitCast(self.stack.pop()))));
                self.heap.freeBytes(@as([*]u8, @ptrCast(ptr))[0..@sizeOf(f64)]);
            },
            // Casts
            OpCode.CastIToF => {
                const v = @as(i64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(@as(f64, @floatFromInt(v)))));
            },
            OpCode.CastFToI => {
                const v = @as(f64, @bitCast(self.stack.pop()));
                self.stack.push(@as(StackWord, @bitCast(@as(i64, @intFromFloat(v)))));
            },
            OpCode.CallFFI => {
                const func_index = instr.operand;
                const func: FFI.FFIData = FFI.FFI_mapping_linear.items[func_index];
                const args_arr: []StackWord = self.stack.popN(func.arg_types.len);

                const res: StackWord = func.call(args_arr) catch |err| {
                    self.errorAndStop(std.fmt.allocPrint(allocator, "FFI call to {d} failed: {?}", .{ func_index, err }) catch "Error");
                    return;
                };

                self.stack.push(res);
            },
            OpCode.Halt => self.stop(),
            else => self.errorAndStop("Unimplemented opcode"),
        }
    }

    pub fn callFunction(self: *Machine, idx: usize) void {
        const return_pc = if (self.current_callframe) |cf| cf.pc else 0;
        const new_frame = CallFrame{
            .function_index = idx,
            .pc = 0,
            .local_vars = std.ArrayList(StackWord).init(allocator),
            .return_pc = return_pc,
        };
        self.call_stack.append(new_frame) catch {
            self.errorAndStop("Failed to append call frame");
            return;
        };
        self.current_callframe = &self.call_stack.items[self.call_stack.items.len - 1];

        const func = self.function_table.items[idx];
        for (0..func.arg_types.len) |i| {
            const arg = self.stack.pop();
            while (i >= self.current_callframe.?.local_vars.items.len) {
                self.current_callframe.?.local_vars.append(0) catch {};
            }
            self.current_callframe.?.local_vars.items[i] = arg;
        }
    }

    pub fn errorAndStop(self: *Machine, msg: []const u8) void {
        self.state = MachineState.Error;
        std.log.err("Error: {s}", .{msg});
    }

    pub fn stop(self: *Machine) void {
        self.state = MachineState.Halted;
    }

    pub fn init(state: MachineState) Machine {
        return Machine{
            .current_callframe = null,
            .function_table = std.ArrayList(Function).init(allocator),
            .call_stack = std.ArrayList(CallFrame).init(allocator),
            .state = state,
            .stack = Stack.init(allocator),
            .heap = Heap.init(allocator),
            .constants = std.ArrayList(StackWord).init(allocator),
        };
    }

    pub fn addConstant(self: *Machine, val: StackWord) void {
        self.constants.append(val) catch {
            self.errorAndStop("Failed to add constant");
            return;
        };
    }

    pub fn deinit(self: *Machine) void {
        for (self.call_stack.items) |cf| cf.local_vars.deinit();
        self.function_table.deinit();
        self.call_stack.deinit();
        self.stack.deinit();
        self.constants.deinit();
    }

    pub fn addFunction(self: *Machine, func: Function) void {
        self.function_table.append(func) catch {
            self.errorAndStop("Failed to add function");
            return;
        };
    }

    pub fn addConstants(self: *Machine, constants: []const StackWord) void {
        for (constants) |c| self.addConstant(c);
    }

    pub fn loadFromMachineData(self: *Machine, data: MachineData) void {
        self.addConstants(data.constants);
        for (data.functions) |f| self.addFunction(f);
    }

    pub fn printDebugData(self: *Machine) void {
        std.log.debug("Machine state: {s}", .{self.state});
        std.log.debug("Call stack:", .{});
        for (self.call_stack.items) |cf| {
            std.log.debug("  Call frame: {d}", .{cf.function_index});
            std.log.debug("    PC: {d}", .{cf.pc});
            std.log.debug("    Local vars: {d}", .{cf.local_vars.items.len});
        }
        std.log.debug("Stack:", .{});
        for (self.stack.items[0..self.stack.sp]) |v| {
            std.log.debug("  Stack word: {d}", .{@as(i64, @bitCast(v))});
        }
    }
};

pub const CallFrame = struct {
    function_index: usize,
    pc: usize,
    local_vars: std.ArrayList(StackWord),
    return_pc: usize,
    pub fn deinit(self: *CallFrame) void {
        self.local_vars.deinit();
    }
};

pub const MachineState = enum { Running, Halted, Error };

pub const MachineData = struct {
    constants: []const StackWord,
    functions: []const Function,
};
