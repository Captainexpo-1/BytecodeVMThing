const std = @import("std");

const String = @import("string.zig").String;

const Value = @import("value.zig").Value;
const ValueType = @import("value.zig").ValueType;
const _Value = @import("value.zig")._Value;

const Instruction = @import("instruction.zig").Instruction;
const OpCode = @import("instruction.zig").OpCode;

const Function = @import("bytecode.zig").Function;

const allocator = std.heap.page_allocator;

pub const Machine = struct {
    current_callframe: ?*CallFrame,
    function_table: std.ArrayList(Function),
    call_stack: std.ArrayList(CallFrame),
    state: MachineState,
    stack: []Value,
    sp: usize,
    constants: std.ArrayList(Value),

    pub fn prepare(self: *Machine) void {
        self.state = MachineState.Running;
        self.sp = 0;
        if (self.current_callframe == null) {
            if (self.function_table.items.len > 0) {
                self.callFunction(0);
                self.current_callframe.?.pc = 0;
            } else {
                self.errorAndStop("No functions available to call");
            }
        }
    }

    pub fn run(self: *Machine) void {
        while (self.state == MachineState.Running) {
            const frame = self.current_callframe orelse {
                self.errorAndStop("No current call frame");
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

    fn pop(self: *Machine) Value {
        if (self.sp == 0) {
            self.stop();
            return Value.newValue(_Value{ .none = {} }, .None); // Return a default value if stack is empty
        }
        self.sp -= 1;
        return self.stack[self.sp];
    }
    fn push(self: *Machine, value: Value) void {
        if (self.sp >= self.stack.len) {
            self.stop();
            return; // Stack overflow, handle as needed
        }
        self.stack[self.sp] = value;
        self.sp += 1;
    }

    fn executeInstruction(self: *Machine, instr: Instruction) void {
        std.debug.print("Executing instruction: {s}\n", .{instr.toString()});
        switch (instr.instr) {
            OpCode.LoadConst => self.push(self.constants.items[instr.operand]),
            OpCode.Add => {
                const b = self.pop();
                const a = self.pop();
                self.push(a.add(b));
            },
            OpCode.Sub => {
                const b = self.pop();
                const a = self.pop();
                self.push(a.sub(b));
            },
            OpCode.Mul => {
                const b = self.pop();
                const a = self.pop();
                const r = a.mul(b);
                self.push(r);
            },
            OpCode.Div => {
                const b = self.pop();
                const a = self.pop();
                self.push(a.div(b));
            },
            OpCode.Jmp => {
                self.current_callframe.?.pc = instr.operand;
            },
            OpCode.Jz => {
                const value = self.pop();
                if (value.vtype == .Float and value.value.float == 0.0) {
                    self.current_callframe.?.pc = instr.operand;
                }
            },
            OpCode.Call => {
                self.callFunction(instr.operand);
            },
            OpCode.Halt => {
                self.stop();
            },
            OpCode.Ret => {
                // Pop the current frame off the call stack.
                // Restore the previous call frame, if there is one.
                // Push a return value if the return type is not None.
                // Resume execution at the return address stored in the popped frame.
                if (self.call_stack.items.len == 0) {
                    self.errorAndStop("Call stack underflow on return");
                    return;
                }

                // Pop the current frame
                var old_frame = self.call_stack.pop();
                old_frame.deinit();

                // Restore previous frame
                if (self.call_stack.items.len > 0) {
                    self.current_callframe = &self.call_stack.items[self.call_stack.items.len - 1];
                    self.current_callframe.?.pc = old_frame.return_pc;
                } else {
                    self.current_callframe = null;
                    self.stop(); // Halt when main function returns
                }
            },
            OpCode.Dup => {
                if (self.sp == 0) {
                    self.stop();
                    return;
                }
                self.push(self.stack[self.sp - 1]);
            },
            OpCode.Swap => {
                if (self.sp < 2) {
                    self.stop();
                    return;
                }
                const a = self.stack[self.sp - 1];
                const b = self.stack[self.sp - 2];
                self.stack[self.sp - 2] = a;
                self.stack[self.sp - 1] = b;
            },
            OpCode.Eq => {
                const b = self.pop();
                const a = self.pop();
                self.push(Value.newValue(_Value{ .bool = a.eq(b) }, .Bool));
            },
            OpCode.Nop => {},
            OpCode.Gt => {
                const b = self.pop();
                const a = self.pop();
                if (a.vtype == .Float and b.vtype == .Float) {
                    self.push(Value.newValue(_Value{ .bool = a.gt(b) }, .Bool));
                } else {
                    self.errorAndStop("Type mismatch in Gt");
                }
            },
            OpCode.Lt => {
                const b = self.pop();
                const a = self.pop();
                if (a.vtype == .Float and b.vtype == .Float) {
                    self.push(Value.newValue(_Value{ .bool = a.lt(b) }, .Bool));
                } else {
                    self.errorAndStop("Type mismatch in Lt");
                }
            },
            OpCode.LoadVar => {
                const var_index = instr.operand;
                if (var_index >= self.current_callframe.?.local_vars.items.len) {
                    self.errorAndStop("LoadVar: Invalid variable index");
                    return;
                }
                self.push(self.current_callframe.?.local_vars.items[var_index]);
            },
            OpCode.StoreVar => {
                const var_index = instr.operand;
                if (var_index >= self.current_callframe.?.local_vars.items.len) {
                    while (var_index >= self.current_callframe.?.local_vars.items.len) {
                        self.current_callframe.?.local_vars.append(Value.newValue(_Value{ .none = {} }, .None)) catch unreachable;
                    }
                }
                if (self.sp == 0) {
                    self.errorAndStop("StoreVar: Stack is empty");
                    return;
                }
                self.current_callframe.?.local_vars.items[var_index] = self.pop();
            },
            else => {
                std.debug.print("Unknown instruction encountered: {s}\n", .{@tagName(instr.instr)});
            },
        }
    }

    pub fn errorAndStop(self: *Machine, message: []const u8) void {
        self.state = MachineState.Error;
        std.debug.print("Machine encountered an error: {s}\n", .{message});
    }

    pub fn stop(self: *Machine) void {
        self.state = MachineState.Halted;
    }

    pub fn init(s: MachineState, stack_size: usize) Machine {
        return Machine{
            .current_callframe = null,
            .constants = std.ArrayList(Value).init(allocator),
            .function_table = std.ArrayList(Function).init(allocator),
            .call_stack = std.ArrayList(CallFrame).init(allocator),
            .state = s,
            .stack = allocator.alloc(Value, stack_size) catch unreachable,
            .sp = 0,
        };
    }

    pub fn addFunction(self: *Machine, func: Function) void {
        std.debug.print("Adding: {s}\n", .{func.toString()});
        self.function_table.append(func) catch {
            self.errorAndStop("Failed to add function");
        };
    }

    pub fn getFunction(self: *Machine, index: usize) ?Function {
        if (index >= self.function_table.items.len) {
            return null;
        }
        return self.function_table.items[index];
    }

    pub fn deinit(self: *Machine) void {
        for (self.call_stack.items) |cf| {
            cf.local_vars.deinit();
        }
        self.constants.deinit();
        self.function_table.deinit();
        self.call_stack.deinit();
    }

    pub fn callFunction(self: *Machine, function_index: usize) void {
        // Save return address (current PC) if inside another function
        const return_pc = if (self.current_callframe) |cf| cf.pc else 0;

        // Push new call frame
        const new_frame = CallFrame{
            .function_index = function_index,
            .pc = 0,
            .local_vars = std.ArrayList(Value).init(allocator),
            .return_pc = return_pc,
        };
        self.call_stack.append(new_frame) catch unreachable;
        self.current_callframe = &self.call_stack.items[self.call_stack.items.len - 1];

        for (0..self.function_table.items[function_index].arg_types.len) |i| {
            const val = self.pop();
            if (val.vtype == self.function_table.items[function_index].arg_types[i]) {
                self.current_callframe.?.local_vars.append(val) catch unreachable;
            } else {
                std.debug.print("Argument type mismatch, expected {s} got {s}\n", .{ @tagName(self.function_table.items[function_index].arg_types[i]), @tagName(val.vtype) });
                self.errorAndStop(
                    "",
                );
            }
        }
    }

    pub fn addConstant(self: *Machine, value: Value) void {
        self.constants.append(value) catch unreachable;
    }

    pub fn dumpStack(self: *Machine) void {
        std.debug.print("Stack contents:\n", .{});
        for (self.stack[0..self.sp]) |value| {
            std.debug.print("  {s}\n", .{value.toString().data});
        }

        // Dump vars
        std.debug.print("Local variables in current frame:\n", .{});
        if (self.current_callframe) |cf| {
            for (cf.local_vars.items) |v| {
                std.debug.print("  {s}\n", .{v.toString().data});
            }
        }
    }
};

pub const CallFrame = struct {
    function_index: usize,
    pc: usize,
    local_vars: std.ArrayList(Value),
    return_pc: usize,
    pub fn deinit(self: *CallFrame) void {
        self.local_vars.deinit();
    }
};

pub const MachineState = enum {
    Running,
    Halted,
    Error,
};

pub const MachineData = struct {
    functions: []Function,
    constants: []Value,
};
