const std = @import("std");
const ValueType = @import("value.zig").ValueType;
const Instruction = @import("instruction.zig").Instruction;
const Global = @import("global.zig");
const StackWord = Global.StackWord;
const Value = @import("value.zig");
const String = @import("string.zig");
// Define the function type
pub const FFIFn = *const fn (args: []StackWord) StackWord;

pub const FFIData = struct {
    arg_types: []const ValueType,
    ret: ValueType,
    function: FFIFn,

    pub fn call(self: FFIData, args: []StackWord) !StackWord {
        if (args.len != self.arg_types.len) {
            return error.InvalidArgumentCount;
        }
        return self.function(args);
    }
};

// Create a hashmap from string to function
pub var FFI_mapping = std.StringHashMap(FFIData).init(std.heap.page_allocator);
pub var FFI_mapping_linear = std.ArrayList(FFIData).init(std.heap.page_allocator);

pub fn print(args: []StackWord) StackWord {
    if (args.len != 2) {
        std.log.err("print: Invalid number of arguments\n", .{});
        return @as(StackWord, 1);
    }
    // fmt string

    const value_type = @as(ValueType, @enumFromInt(args[1]));
    const val = args[0];
    const out_string = Value.valueToString(value_type, val, std.heap.page_allocator) catch {
        return @as(StackWord, 1);
    };

    const stdout = std.io.getStdOut();
    // Print the formatted string
    _ = stdout.writer().writeAll(out_string) catch {
        std.log.err("print: Error writing to stdout\n", .{});
        return @as(StackWord, 1);
    };

    return @as(StackWord, 0);
}

// In ffi.zig, update string handling functions
pub fn str_concat(args: []StackWord) StackWord {
    if (args.len != 2) {
        std.log.err("str_concat: Invalid number of arguments\n", .{});
        return @as(StackWord, 1);
    }

    // Get the string pointers and lengths - implementation depends on string memory layout
    const str1_ptr = @as([*]const u8, @ptrFromInt(@as(usize, args[0])));
    const str1_len = @as(*const usize, @ptrCast(@alignCast(str1_ptr))).*;
    const str1 = str1_ptr[8 .. 8 + str1_len];

    const str2_ptr = @as([*]const u8, @ptrFromInt(@as(usize, args[1])));
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

pub fn input(args: []StackWord) StackWord {
    _ = args;

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

pub fn registerFFI(comptime name: []const u8, comptime args: []const ValueType, comptime ret: ValueType, comptime function: FFIFn) !void {
    // Make a copy of the args slice to own it

    const ffi_data = FFIData{
        .arg_types = args,
        .ret = ret,
        .function = function,
    };
    try FFI_mapping.put(name, ffi_data);
    try FFI_mapping_linear.append(ffi_data);
}

pub fn getFFIArgLen(name: []const u8) !usize {
    const ffi_data = FFI_mapping.get(name) orelse return error.FunctionNotFound;
    return ffi_data.arg_types.len;
}

pub fn callFFI(name: []const u8, args: []Value) !Value {
    const ffi_data = FFI_mapping.get(name);
    if (ffi_data) |data| {
        return data.call(args);
    } else {
        return error.FunctionNotFound;
    }
}

pub fn initFFI() !void {
    // Register the print function
    try registerFFI("print", &[_]ValueType{ .Int, .Int }, .None, print);
    try registerFFI("str_concat", &[_]ValueType{ .String, .String }, .String, str_concat);
    try registerFFI("input", &[_]ValueType{}, .String, input);
}

pub fn deinitFFI() void {
    // No specific deinitialization needed for FFI,
    // but we can clear the mapping if necessary.
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
