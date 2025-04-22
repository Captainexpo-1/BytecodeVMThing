const std = @import("std");
const ValueType = @import("value.zig").ValueType;
const Instruction = @import("instruction.zig").Instruction;
const Global = @import("global.zig");
const StackWord = Global.StackWord;
const Value = @import("value.zig");
const String = @import("string.zig");
const Stack = @import("stack.zig").Stack;

const stdio = @cImport({
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cInclude("stdio.h");
});

// Define the function type
pub const FFIFn = *const fn (stack: *Stack) StackWord;

pub const FFIData = struct {
    arg_types: []const ValueType,
    ret: ValueType,
    function: FFIFn,
    arbitrary_args: bool,

    pub fn call(self: FFIData, stack: *Stack) !StackWord {
        return self.function(stack);
    }
};

// Create a hashmap from string to function
pub var FFI_mapping = std.StringHashMap(FFIData).init(std.heap.page_allocator);
pub var FFI_mapping_linear = std.ArrayList(FFIData).init(std.heap.page_allocator);

pub fn print(stack: *Stack) StackWord {
    std.debug.print("{s}", .{Value.valueToString(.String, stack.pop(), std.heap.page_allocator) catch {
        std.log.err("print: Error converting value to string\n", .{});
        return @as(StackWord, 1);
    }});
    return @as(StackWord, 0);
}

pub fn str_concat(stack: *Stack) StackWord {

    // Get the string pointers and lengths - implementation depends on string memory layout
    const str1_ptr = @as([*]const u8, @ptrFromInt(@as(usize, stack.pop())));
    const str1_len = @as(*const usize, @ptrCast(@alignCast(str1_ptr))).*;
    const str1 = str1_ptr[8 .. 8 + str1_len];

    const str2_ptr = @as([*]const u8, @ptrFromInt(@as(usize, stack.pop())));
    const str2_len = @as(*const usize, @ptrCast(@alignCast(str2_ptr))).*;
    const str2 = str2_ptr[8 .. 8 + str2_len];

    // Concatenate strings
    const result = String.concat(str1, str2, std.heap.page_allocator) catch {
        std.log.err("str_concat: Error allocating memory for result\n", .{});
        return @as(StackWord, 1);
    };

    // Allocate new string with length prefix
    const full_len = result.len + 8;
    const memory = std.heap.page_allocator.alloc(u8, full_len) catch {
        std.log.err("str_concat: Error allocating memory for result\n", .{});
        return @as(StackWord, 1);
    };

    // Store length in first 8 bytes
    @as(*usize, @ptrCast(@alignCast(memory.ptr))).* = result.len;

    // Copy string data
    @memcpy(memory[8..], result);

    return @as(StackWord, @intFromPtr(memory.ptr));
}

pub fn input(stack: *Stack) StackWord {
    _ = stack;

    // returns a String ptr as a StackWord
    const stdin = std.io.getStdIn();
    const reader = stdin.reader();

    const in = reader.readUntilDelimiterOrEofAlloc(std.heap.page_allocator, '\n', 1024) catch {
        std.log.err("input: Error reading from stdin\n", .{});
        return @as(StackWord, 1);
    } orelse {
        std.log.err("input: Error reading from stdin\n", .{});
        return @as(StackWord, 1);
    };

    // Allocate new string with length prefix
    const full_len = in.len + 8;
    const memory = std.heap.page_allocator.alloc(u8, full_len) catch {
        std.log.err("input: Error allocating memory for result\n", .{});
        return @as(StackWord, 1);
    };
    // Store length in first 8 bytes
    @as(*usize, @ptrCast(@alignCast(memory.ptr))).* = in.len;
    // Copy string data
    @memcpy(memory[8..], in);
    return @as(StackWord, @intFromPtr(memory.ptr));
}

pub fn intFromString(stack: *Stack) StackWord {
    const str_ptr = @as([*]const u8, @ptrFromInt(@as(usize, stack.pop())));
    const str_len = @as(*const usize, @ptrCast(@alignCast(str_ptr))).*;
    const str = str_ptr[8 .. 8 + str_len];

    const intval = std.fmt.parseInt(i64, str, 10) catch {
        std.log.err("intFromString: Error parsing integer\n", .{});
        return @as(StackWord, 1);
    };

    return Global.toStackWord(intval);
}

pub fn toString(stack: *Stack) StackWord {
    const val_type = @as(ValueType, @enumFromInt(stack.pop()));
    const val = stack.pop();

    const result = Value.valueToString(val_type, val, std.heap.page_allocator) catch {
        std.log.err("toString: Error converting value to string\n", .{});
        return @as(StackWord, 1);
    };

    // Allocate new string with length prefix
    const full_len = result.len + 8;
    const memory = std.heap.page_allocator.alloc(u8, full_len) catch {
        std.log.err("toString: Error allocating memory for result\n", .{});
        return @as(StackWord, 1);
    };
    // Store length in first 8 bytes
    @as(*usize, @ptrCast(@alignCast(memory.ptr))).* = result.len;
    // Copy string data
    @memcpy(memory[8..], result);
    return @as(StackWord, @intFromPtr(memory.ptr));
}

pub fn system(stack: *Stack) StackWord {
    var command_args = std.heap.page_allocator.alloc([]const u8, stack.sp) catch {
        std.log.err("system: Error allocating memory for command arguments\n", .{});
        return @as(StackWord, 1);
    };

    for (0..stack.sp) |i| {
        const str_ptr = @as([*]const u8, @ptrFromInt(@as(usize, stack.pop())));
        const str_len = @as(*const usize, @ptrCast(@alignCast(str_ptr))).*;
        const str = str_ptr[8 .. 8 + str_len];
        command_args[i] = str;
    }

    const result = std.process.Child.run(.{ .allocator = std.heap.page_allocator, .argv = command_args }) catch {
        std.log.err("system: Error executing command\n", .{});
        return @as(StackWord, 1);
    };
    const res = std.heap.page_allocator.alloc(u8, result.stdout.len) catch {
        std.log.err("system: Error allocating memory for result\n", .{});
        return @as(StackWord, 1);
    };
    @memcpy(res, result.stdout);
    return @as(StackWord, @intFromPtr(res.ptr));
}

pub fn initFFI() !void {
    // Register the print function
    try registerFFI("print", &[_]ValueType{.String}, .None, print, false);
    try registerFFI("str_concat", &[_]ValueType{ .String, .String }, .String, str_concat, false);
    try registerFFI("input", &[_]ValueType{}, .String, input, false);
    try registerFFI("intFromString", &[_]ValueType{.String}, .Int, intFromString, false);
    try registerFFI("system", &[_]ValueType{}, .String, system, true);
    try registerFFI("toString", &[_]ValueType{.Int}, .String, toString, false);
}

pub fn registerFFI(comptime name: []const u8, comptime args: []const ValueType, comptime ret: ValueType, comptime function: FFIFn, comptime arbitrary_args: bool) !void {
    const ffi_data = FFIData{
        .arg_types = args,
        .ret = ret,
        .function = function,
        .arbitrary_args = arbitrary_args,
    };
    try FFI_mapping.put(name, ffi_data);
    try FFI_mapping_linear.append(ffi_data);
}

pub fn getFFIArgLen(name: []const u8) !usize {
    const ffi_data = FFI_mapping.get(name) orelse return error.FunctionNotFound;
    return ffi_data.arg_types.len;
}

pub fn callFFI(name: []const u8, stack: *Stack) !Value {
    const ffi_data = FFI_mapping.get(name);
    if (ffi_data) |data| {
        return data.call(stack);
    } else {
        return error.FunctionNotFound;
    }
}

pub fn deinitFFI() void {
    FFI_mapping.deinit();
    FFI_mapping_linear.deinit();
    std.log.debug("FFI deinitialized", .{});
}

pub fn printFFIRegistry() void {
    std.log.debug("Registered FFI functions:", .{});
    var keyIter = FFI_mapping.keyIterator();
    for (0..FFI_mapping.count()) |_| {
        const key = keyIter.next() orelse break;
        const value = FFI_mapping.get(key.*) orelse continue;
        std.log.debug("  '{s}': args={d}, ret={s}", .{
            key.*,
            value.arg_types.len,
            @tagName(value.ret),
        });
    }
    if (FFI_mapping.count() == 0) {
        std.log.debug("  No functions registered", .{});
    }
}
