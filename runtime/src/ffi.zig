const std = @import("std");
const Value = @import("value.zig").Value;
const ValueType = @import("value.zig").ValueType;
const Instruction = @import("instruction.zig").Instruction;

// Define the function type
const FFI_Fn = fn (args: []Value) Value;

const FFI_Data = struct {
    name: []const u8,
    args: []ValueType,
    ret: ValueType,
    function: FFI_Fn,

    pub fn call(self: FFI_Data, args: []Value) !Value {
        if (args.len != self.args.len) {
            return error.InvalidArgumentCount;
        }
        // Validate argument types
        for (args, 0..) |arg, i| {
            if (arg.type != self.args[i]) {
                return error.InvalidArgumentType;
            }
        }
        // Call the function and return the result
        return self.function(args);
    }
};

// Create a hashmap from string to function
const FFI_mapping: std.AutoHashMap([]const u8, FFI_Data) = std.AutoHashMap([]const u8, FFI_Data).init(std.heap.page_allocator);

pub fn print(args: []Value) Value {
    if (args.len == 0) {
        std.debug.print("print: No arguments provided\n", .{});
        return Value.newValue(.{ .none = null }, .None);
    }
    // fmt string
    const str = args[0].toString().data;

    // Collect arguments for formatting
    var format_args: []anyopaque = &.{};
    if (args.len > 1) {
        format_args = args[1..].map(Value.toAnyOpaque);
    }
    const stdout = std.io.getStdOut();
    // Print the formatted string
    stdout.write(str) catch |err| {
        std.debug.print("print: Error writing to stdout: {s}\n", .{err});
        return Value.initNone();
    };

    return Value.initNone();
}

pub fn registerFFI(name: []const u8, args: []ValueType, ret: ValueType, function: FFI_Fn) !void {
    const ffi_data = FFI_Data{
        .name = name,
        .args = args,
        .ret = ret,
        .function = function,
    };
    const result = FFI_mapping.put(name, ffi_data);
    if (result) |err| {
        return err;
    }
}

pub fn getFFIArgLen(name: []const u8) !usize {
    const ffi_data = FFI_mapping.get(name);
    if (ffi_data) |data| {
        return data.args.len;
    } else {
        return error.FunctionNotFound;
    }
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
    try registerFFI("print", &.{.String}, .None, print);
}
