pub const StackWord = u64;

pub inline fn toStackWord(value: anytype) StackWord {
    return @as(StackWord, @bitCast(value));
}

pub inline fn fromStackWord(comptime T: type, value: StackWord) T {
    return @as(T, @bitCast(value));
}
