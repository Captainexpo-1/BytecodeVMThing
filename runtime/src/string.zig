const std = @import("std");
const fmt = std.fmt;
pub const String = struct {
    data: []const u8,
    len: usize,

    pub fn new(data: []const u8) String {
        return String{ .data = data, .len = data.len };
    }

    pub fn alloc(self: String, allocator: std.mem.Allocator) !*String {
        const s = try allocator.create(String);
        s.* = self;
        return s;
    }

    pub fn add(self: String, other: String) String {
        var buffer = std.ArrayList(u8).init(std.heap.page_allocator);
        defer buffer.deinit();
        buffer.appendSlice(self.data) catch {
            std.debug.print("Error appending slice\n", .{});
            return String{ .data = "", .len = 0 };
        };
        buffer.appendSlice(other.data) catch {
            std.debug.print("Error appending slice\n", .{});
            return String{ .data = "", .len = 0 };
        };
        return String{ .data = buffer.toOwnedSlice() catch {
            std.debug.print("Error converting to owned slice\n", .{});
            return String{ .data = "", .len = 0 };
        }, .len = buffer.items.len };
    }

    pub fn fromInt(value: i64) String {
        const s = std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{value}) catch "";
        return String{ .data = s, .len = s.len };
    }

    pub fn fromFloat(value: f64) String {
        const s = std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{value}) catch "";
        return String{ .data = s, .len = s.len };
    }

    pub fn fromBool(value: bool) String {
        return String{ .data = if (value) "true" else "false", .len = if (value) 4 else 5 };
    }

    pub fn toSlice(self: String) []const u8 {
        return self.data;
    }

    pub fn isEmpty(self: String) bool {
        return self.len == 0;
    }

    pub fn isEqual(self: String, other: String) bool {
        if (self.len != other.len) {
            return false;
        }
        return std.mem.eql(u8, self.data, other.data);
    }

    pub fn at(self: String, index: usize) ?u8 {
        if (index >= self.len) {
            return null;
        }
        return self.data[index];
    }

    pub fn substring(self: String, start: usize, end: usize) ?String {
        if (start >= self.len or end > self.len or start >= end) {
            return null;
        }
        return String{ .data = self.data[start..end] };
    }

    pub fn split(self: String, delimiter: u8) []String {
        var list = std.ArrayList(String).init(std.heap.page_allocator);
        defer list.deinit();
        var start = 0;
        var i: usize = 0;
        for (self.data) |c| {
            if (c == delimiter) {
                if (start < i) {
                    _ = list.append(String{ .data = self.data[start..i], .len = i - start });
                }
                start = i + 1;
            }
            i += 1;
        }
        if (start < self.len) {
            _ = list.append(String{ .data = self.data[start..], .len = self.len - start });
        }
        return list.toOwnedSlice();
    }
};
