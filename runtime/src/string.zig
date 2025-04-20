const std = @import("std");
const Global = @import("global.zig");
const StackWord = Global.StackWord;

pub fn concat(str1: []const u8, str2: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    var buffer = try allocator.alloc(u8, str1.len + str2.len);
    @memcpy(buffer[0..str1.len], str1);
    @memcpy(buffer[str1.len..], str2);
    return buffer;
}

pub fn fromInt(value: i64, allocator: std.mem.Allocator) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "{d}", .{value});
}

pub fn fromFloat(value: f64, allocator: std.mem.Allocator) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "{d}", .{value});
}

pub fn fromBool(value: bool, allocator: std.mem.Allocator) ![]const u8 {
    return try allocator.dupe(u8, if (value) "true" else "false");
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

pub fn split(str: []const u8, delimiter: u8, allocator: std.mem.Allocator) ![][]const u8 {
    var list = std.ArrayList([]const u8).init(allocator);
    defer list.deinit();

    var start: usize = 0;
    for (str, 0..) |c, i| {
        if (c == delimiter) {
            try list.append(try allocator.dupe(u8, str[start..i]));
            start = i + 1;
        }
    }

    if (start < str.len) {
        try list.append(try allocator.dupe(u8, str[start..]));
    }

    return list.toOwnedSlice();
}
