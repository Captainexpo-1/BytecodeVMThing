const std = @import("std");
const Value = @import("value.zig").Value;
const ValueType = @import("value.zig").ValueType;
const Instruction = @import("instruction.zig").Instruction;

// Define the function type
pub const FFIFn = *const fn (args: []Value) Value;

pub const FFIData = struct {
    arg_types: []const ValueType,
    ret: ValueType,
    function: FFIFn,
    does_return_void: bool = true,

    pub fn call(self: FFIData, args: []Value) !Value {
        if (args.len != self.arg_types.len) {
            return error.InvalidArgumentCount;
        }
        // Validate argument types
        for (args, 0..) |arg, i| {
            if (arg.vtype != self.arg_types[i]) {
                std.log.err("FFI call error: Argument {d} type mismatch: expected {s}, got {s}\n", .{
                    i,
                    @tagName(self.arg_types[i]),
                    @tagName(arg.vtype),
                });
                return error.InvalidArgumentType;
            }
        }
        // Call the function and return the result
        return self.function(args);
    }
};

// Create a hashmap from string to function
pub var FFI_mapping = std.StringHashMap(FFIData).init(std.heap.page_allocator);

pub fn print(args: []Value) Value {
    if (args.len == 0) {
        std.log.err("print: No arguments provided\n", .{});
        return Value.newValue(.{ .none = {} }, .None);
    }
    // fmt string
    const str = args[0].toString().data;

    const stdout = std.io.getStdOut();
    // Print the formatted string
    _ = stdout.writer().writeAll(str) catch {
        std.log.err("print: Error writing to stdout\n", .{});
        return Value.initNone();
    };

    return Value.initNone();
}

pub fn intToString(args: []Value) Value {
    if (args.len == 0) {
        std.log.err("intToString: No arguments provided\n", .{});
        return Value.newValue(.{ .none = {} }, .None);
    }
    if (args.len > 1) {
        std.log.err("intToString: Too many arguments provided\n", .{});
        return Value.newValue(.{ .none = {} }, .None);
    }
    // Convert the integer to a string
    return Value.newValue(.{ .string = args[0].toString() }, .String);
}

pub fn registerFFI(comptime name: []const u8, comptime args: []const ValueType, comptime ret: ValueType, comptime returns_void: bool, comptime function: FFIFn) !void {
    // Make a copy of the args slice to own it

    const ffi_data = FFIData{
        .arg_types = args,
        .ret = ret,
        .function = function,
        .does_return_void = returns_void,
    };
    try FFI_mapping.put(name, ffi_data);
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
    try registerFFI("print", &[_]ValueType{.String}, .None, true, print);
    try registerFFI("intToString", &[_]ValueType{.Int}, .String, false, intToString);
}

pub fn deinitFFI() void {
    // No specific deinitialization needed for FFI,
    // but we can clear the mapping if necessary.
    FFI_mapping.deinit();
}

pub fn printFFIRegistry() void {
    std.log.debug("Registered FFI functions:\n", .{});
    var keyIter = FFI_mapping.keyIterator();
    for (0..FFI_mapping.count()) |_| {
        const key = keyIter.next() orelse break;
        const value = FFI_mapping.get(key.*) orelse continue;
        std.log.debug("  '{s}': args={d}, ret={s}, returns_void={}", .{
            key.*,
            value.arg_types.len,
            @tagName(value.ret),
            value.does_return_void,
        });
    }
    if (FFI_mapping.count() == 0) {
        std.log.debug("  No functions registered", .{});
    }
}
