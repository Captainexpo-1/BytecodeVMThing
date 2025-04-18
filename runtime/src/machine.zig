const std = @import("std");

const String = @import("string.zig").String;

const Value = @import("value.zig").Value;
const ValueType = @import("value.zig").ValueType;
const _Value = @import("value.zig")._Value;

const Instruction = @import("instruction.zig").Instruction;
const OpCode = @import("instruction.zig").OpCode;

const Function = @import("bytecode.zig").Function;

const allocator = std.heap.page_allocator;

const Stack = @import("stack.zig").Stack;

const Heap = @import("heap.zig").Heap;

const FFI = @import("ffi.zig");

// Disable debug logging for performance

pub const Machine = struct {
    current_callframe: ?*CallFrame,
    function_table: std.ArrayList(Function),
    call_stack: std.ArrayList(CallFrame),
    state: MachineState,
    stack: Stack,
    heap: Heap,
    constants: std.ArrayList(Value),
    instructions_executed: i64 = 0,

    pub fn prepare(self: *Machine) void {
        self.state = MachineState.Running;
        self.stack.sp = 0;
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

    fn executeInstruction(self: *Machine, instr: Instruction) void {
        //std.log.debug("Executing instruction: {s}", .{instr.toString()});
        self.instructions_executed += 1;
        switch (instr.instr) {
            OpCode.LoadConst => self.stack.push(self.constants.items[instr.operand]),
            OpCode.Add => {
                const b = self.stack.pop();
                const a = self.stack.pop();
                self.stack.push(a.add(b));
            },
            OpCode.Sub => {
                const b = self.stack.pop();
                const a = self.stack.pop();
                self.stack.push(a.sub(b));
            },
            OpCode.Mul => {
                const b = self.stack.pop();
                const a = self.stack.pop();
                const r = a.mul(b);
                self.stack.push(r);
            },
            OpCode.Div => {
                const b = self.stack.pop();
                const a = self.stack.pop();
                self.stack.push(a.div(b));
            },
            OpCode.Jmp => {
                self.current_callframe.?.pc = instr.operand;
            },
            OpCode.Jz => {
                const value = self.stack.pop();
                if (value.vtype == .Float and value.value.float == 0.0) {
                    self.current_callframe.?.pc = instr.operand;
                }
            },
            OpCode.Jnz => {
                const value = self.stack.pop();
                if (value.vtype == .Float and value.value.float != 0.0) {
                    //std.log.debug("Jumping to {d}", .{instr.operand});
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
                var old_frame = self.call_stack.pop() orelse unreachable;
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
                if (self.stack.sp == 0) {
                    self.stop();
                    return;
                }
                self.stack.push(self.stack.get(self.stack.sp - 1));
            },
            OpCode.Swap => {
                if (self.stack.sp < 2) {
                    self.stop();
                    return;
                }
                const a = self.stack.get(self.stack.sp - 1);
                const b = self.stack.get(self.stack.sp - 2);
                self.stack.set(self.stack.sp - 2, a);
                self.stack.set(self.stack.sp - 1, b);
            },
            OpCode.Eq => {
                const b = self.stack.pop();
                const a = self.stack.pop();
                self.stack.push(Value.newValue(_Value{ .bool = a.eq(b) }, .Bool));
            },
            OpCode.Nop => {},
            OpCode.Gt => {
                const b = self.stack.pop();
                const a = self.stack.pop();
                if (a.vtype == .Float and b.vtype == .Float) {
                    self.stack.push(Value.newValue(_Value{ .bool = a.gt(b) }, .Bool));
                } else {
                    self.errorAndStop("Type mismatch in Gt");
                }
            },
            OpCode.Lt => {
                const b = self.stack.pop();
                const a = self.stack.pop();
                if (a.vtype == .Float and b.vtype == .Float) {
                    self.stack.push(Value.newValue(_Value{ .bool = a.lt(b) }, .Bool));
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
                self.stack.push(self.current_callframe.?.local_vars.items[var_index]);
            },
            OpCode.StoreVar => {
                const var_index = instr.operand;
                if (var_index >= self.current_callframe.?.local_vars.items.len) {
                    while (var_index >= self.current_callframe.?.local_vars.items.len) {
                        self.current_callframe.?.local_vars.append(Value.newValue(_Value{ .none = {} }, .None)) catch unreachable;
                    }
                }
                if (self.stack.sp == 0) {
                    self.errorAndStop("StoreVar: Stack is empty");
                    return;
                }
                self.current_callframe.?.local_vars.items[var_index] = self.stack.pop();
            },
            OpCode.Jif => {
                const value = self.stack.pop();
                if (value.vtype == .Bool and value.value.bool == true) {
                    self.current_callframe.?.pc = instr.operand;
                }
            },
            OpCode.CastToInt => {
                const value = self.stack.pop();
                switch (value.vtype) {
                    .Float => self.stack.push(Value.newValue(_Value{ .int = @as(i64, @intFromFloat(value.value.float)) }, .Int)),
                    .Int => self.stack.push(value),
                    else => self.errorAndStop("CastToInt: Invalid type"),
                }
            },
            OpCode.CastToFloat => {
                const value = self.stack.pop();
                switch (value.vtype) {
                    .Float => self.stack.push(value),
                    .Int => self.stack.push(Value.newValue(_Value{ .float = @as(f64, @floatFromInt(value.value.int)) }, .Float)),
                    else => self.errorAndStop("CastToFloat: Invalid type"),
                }
            },
            OpCode.Shl => {
                const b = self.stack.pop();
                const a = self.stack.pop();
                if (a.vtype == .Int and b.vtype == .Int) {
                    self.stack.push(Value.newValue(_Value{ .int = @as(i64, @intCast(a.value.int)) << @as(u6, @intCast(b.value.int)) }, .Int));
                } else {
                    self.errorAndStop("Type mismatch in Shl");
                }
            },
            OpCode.Shr => {
                const b = self.stack.pop();
                const a = self.stack.pop();
                if (a.vtype == .Int and b.vtype == .Int) {
                    self.stack.push(Value.newValue(_Value{ .int = @as(i64, @intCast(a.value.int)) >> @as(u6, @intCast(b.value.int)) }, .Int));
                } else {
                    self.errorAndStop("Type mismatch in Shr");
                }
            },
            OpCode.Not => {
                const value = self.stack.pop();
                if (value.vtype == .Bool) {
                    self.stack.push(Value.newValue(_Value{ .bool = !value.value.bool }, .Bool));
                } else {
                    self.errorAndStop("Not: Invalid type");
                }
            },
            OpCode.And => {
                const b = self.stack.pop();
                const a = self.stack.pop();
                if (a.vtype == .Bool and b.vtype == .Bool) {
                    self.stack.push(Value.newValue(_Value{ .bool = a.value.bool and b.value.bool }, .Bool));
                } else {
                    self.errorAndStop("Type mismatch in And");
                }
            },
            OpCode.Or => {
                const b = self.stack.pop();
                const a = self.stack.pop();
                if (a.vtype == .Bool and b.vtype == .Bool) {
                    self.stack.push(Value.newValue(_Value{ .bool = a.value.bool or b.value.bool }, .Bool));
                } else {
                    self.errorAndStop("Type mismatch in Or");
                }
            },
            OpCode.Xor => {
                const b = self.stack.pop();
                const a = self.stack.pop();
                const av = a.value.bool;
                const bv = b.value.bool;
                if (a.vtype == .Bool and b.vtype == .Bool) {
                    self.stack.push(Value.newValue(_Value{ .bool = (av or bv) and !(av and bv) }, .Bool));
                } else {
                    self.errorAndStop("Type mismatch in Xor");
                }
            },
            OpCode.BitAnd => {
                const b = self.stack.pop();
                const a = self.stack.pop();
                if (a.vtype == .Int and b.vtype == .Int) {
                    self.stack.push(Value.newValue(_Value{ .int = a.value.int & b.value.int }, .Int));
                } else {
                    self.errorAndStop("Type mismatch in BitAnd");
                }
            },
            OpCode.BitOr => {
                const b = self.stack.pop();
                const a = self.stack.pop();
                if (a.vtype == .Int and b.vtype == .Int) {
                    self.stack.push(Value.newValue(_Value{ .int = a.value.int | b.value.int }, .Int));
                } else {
                    self.errorAndStop("Type mismatch in BitOr");
                }
            },
            OpCode.BitXor => {
                const b = self.stack.pop();
                const a = self.stack.pop();
                if (a.vtype == .Int and b.vtype == .Int) {
                    self.stack.push(Value.newValue(_Value{ .int = a.value.int ^ b.value.int }, .Int));
                } else {
                    self.errorAndStop("Type mismatch in BitXor");
                }
            },
            OpCode.Mod => {
                const b = self.stack.pop();
                const a = self.stack.pop();
                if (a.vtype == .Int and b.vtype == .Int) {
                    if (b.value.int == 0) {
                        self.errorAndStop("Division by zero in Mod");
                        return;
                    }
                    self.stack.push(Value.newValue(_Value{ .int = @mod(a.value.int, b.value.int) }, .Int));
                } else {
                    self.errorAndStop("Type mismatch in Mod");
                }
            },
            OpCode.Neq => {
                const b = self.stack.pop();
                const a = self.stack.pop();
                self.stack.push(Value.newValue(_Value{ .bool = !a.eq(b) }, .Bool));
            },
            OpCode.Ge => {
                const b = self.stack.pop();
                const a = self.stack.pop();
                const is_true = a.eq(b) or a.gt(b);
                self.stack.push(Value.newValue(_Value{ .bool = is_true }, .Bool));
            },
            OpCode.Le => {
                const b = self.stack.pop();
                const a = self.stack.pop();
                const is_true = a.eq(b) or a.lt(b);
                self.stack.push(Value.newValue(_Value{ .bool = is_true }, .Bool));
            },
            OpCode.LoadAddress => {
                const var_index = instr.operand;
                if (var_index >= self.current_callframe.?.local_vars.items.len) {
                    self.errorAndStop("LoadAddress: Invalid variable index");
                    return;
                }

                // Create a pointer directly to the value in the call frame
                const pointer_value = Value.newValue(.{ .pointer = &self.current_callframe.?.local_vars.items[var_index] }, ValueType.Pointer);
                self.stack.push(pointer_value);
            },
            OpCode.Deref => {
                // var index = operand
                const addr_value = self.stack.pop();
                if (addr_value.vtype != .Pointer) {
                    self.errorAndStop("Deref: Expected pointer type");
                    return;
                }
                const value = self.heap.dereference(addr_value.value.pointer);
                self.stack.push(value);
            },
            OpCode.StoreDeref => {
                // var index = operand
                const addr_value = self.stack.pop();
                if (addr_value.vtype != .Pointer) {
                    self.errorAndStop("StoreDeref: Expected pointer type");
                    return;
                }
                const value = self.stack.pop();
                self.heap.store(addr_value.value.pointer, value) catch {
                    self.errorAndStop("Failed to store value in pointer");
                    return;
                };
            },
            OpCode.Alloc => {
                const size = self.stack.pop();
                if (size.vtype != .Int or size.value.int <= 0) {
                    self.errorAndStop("Alloc: Invalid size");
                    return;
                }

                // Allocate memory
                const memory = self.heap.alloc(@as(usize, @intCast(size.value.int))) catch {
                    self.errorAndStop("Alloc: Failed to allocate memory");
                    return;
                };

                // Create a value representing the allocated memory
                const value = Value.newValue(.{ .pointer = memory }, ValueType.Pointer);
                self.stack.push(value);
            },
            OpCode.Free => {
                const value = self.stack.pop();
                if (value.vtype != .Pointer) {
                    self.errorAndStop("Free: Expected pointer type");
                    return;
                }

                // Free the allocated memory
                self.heap.free(value.value.pointer) catch {
                    self.errorAndStop("Free: Failed to free memory");
                    return;
                };
            },
            OpCode.CallFFI => {
                const ffi_name: Value = self.constants.items[instr.operand];
                if (ffi_name.vtype != .String) {
                    self.errorAndStop("CallFFI: Expected string constant");
                    return;
                }
                const name = ffi_name.value.string.data;
                std.log.debug("Calling FFI function: '{s}'", .{name});
                // debug the exact bytes to see what's in the variable
                // Print the length to check if there are hidden characters
                std.log.debug("name length: {d}", .{name.len});
                const ffidata = FFI.FFI_mapping.get(name) orelse {
                    self.errorAndStop("CallFFI: Function not found");
                    return;
                };
                const argc = ffidata.arg_types.len;
                if (argc > self.stack.sp) {
                    self.errorAndStop("CallFFI: Not enough arguments on stack");
                    return;
                }
                const args = self.stack.items[self.stack.sp - argc .. self.stack.sp];
                self.stack.sp -= argc; // Pop the arguments from the stack
                const res = FFI.callFFI(name, args) catch |err| {
                    self.errorAndStop(std.fmt.allocPrint(allocator, "CallFFI: Failed to call FFI function: {any}", .{err}) catch unreachable);
                    return;
                };
                if (ffidata.does_return_void) {
                    // If the FFI function does not return a value, we don't push anything
                    return;
                }
                self.stack.push(res);
            },
        }
    }

    pub fn errorAndStop(self: *Machine, message: []const u8) void {
        self.state = MachineState.Error;
        std.log.err("Machine encountered an error: {s}", .{message});
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
            .stack = Stack.init(stack_size, allocator),
            .heap = Heap.init(allocator),
        };
    }

    pub fn addFunction(self: *Machine, func: Function) void {
        //std.log.debug("Adding: {s}", .{func.toString()});
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
        self.stack.deinit();
    }

    pub fn callFunction(self: *Machine, function_index: usize) void {
        // Save return address (current PC) if inside another function
        const return_pc = if (self.current_callframe) |cf| cf.pc else 0;

        // Push new call frame
        const new_frame = CallFrame{
            .function_index = function_index,
            .pc = 0,
            .local_vars = std.ArrayList(Value).init(allocator),
            .local_vars_types = std.ArrayList(ValueType).init(allocator),
            .return_pc = return_pc,
        };
        self.call_stack.append(new_frame) catch unreachable;
        self.current_callframe = &self.call_stack.items[self.call_stack.items.len - 1];

        for (0..self.function_table.items[function_index].arg_types.len) |i| {
            const val = self.stack.pop();
            if (val.vtype == self.function_table.items[function_index].arg_types[i]) {
                self.current_callframe.?.local_vars.append(val) catch unreachable;
            } else {
                //std.log.debug("Argument type mismatch, expected {s} got {s}", .{ @tagName(self.function_table.items[function_index].arg_types[i]), @tagName(val.vtype) });
                self.errorAndStop(
                    "",
                );
            }
        }
    }

    pub fn addConstant(self: *Machine, value: Value) void {
        self.constants.append(value) catch unreachable;
    }

    pub fn dumpDebugData(self: *Machine) void {
        std.log.debug("Stack contents:", .{});
        for (self.stack.items[0..self.stack.sp]) |value| {
            std.log.debug("  {s}", .{value.toString().data});
        }

        // Dump vars
        std.log.debug("Local variables in current frame:", .{});
        if (self.current_callframe) |cf| {
            for (cf.local_vars.items) |v| {
                std.log.debug("  {s}", .{v.toString().data});
            }
        }

        std.log.debug("Instructions executed: {d}", .{self.instructions_executed});
    }
};

pub const CallFrame = struct {
    function_index: usize,
    pc: usize,
    local_vars: std.ArrayList(Value),
    local_vars_types: std.ArrayList(ValueType),
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
