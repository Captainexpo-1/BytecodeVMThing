const std = @import("std");
const Global = @import("global.zig");
const StackWord = Global.StackWord;

pub fn concat(str1: []const u8, str2: []const u8, allocator: std.mem.Allocator) ![:0]const u8 {
    var buffer = try allocator.allocSentinel(u8, str1.len + str2.len, 0);
    @memcpy(buffer[0..str1.len], str1);
    @memcpy(buffer[str1.len..], str2);
    return buffer;
}

pub fn fromInt(value: i64, allocator: std.mem.Allocator) ![:0]const u8 {
    return try std.fmt.allocPrintZ(allocator, "{d}", .{value});
}

pub fn fromFloat(value: f64, allocator: std.mem.Allocator) ![:0]const u8 {
    return try std.fmt.allocPrintZ(allocator, "{d}", .{value});
}

pub fn fromBool(value: bool, allocator: std.mem.Allocator) ![:0]const u8 {
    return try allocator.dupeZ(u8, if (value) "true" else "false");
}

pub fn isEqual(str1: []const u8, str2: []const u8) bool {
    return std.mem.eql(u8, str1, str2);
}

pub fn substring(str: []const u8, start: usize, end: usize) ?[]const u8 {
    if ((start >= str.len) or (end > str.len) or (start >= end)) {
        return null;
    }
    return str[start..end];
}

pub fn fromPointer(ptr: *const u8, allocator: std.mem.Allocator) ![:0]const u8 {
    return try std.fmt.allocPrintZ(allocator, "{p}", .{ptr});
}
