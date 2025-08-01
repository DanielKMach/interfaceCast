const std = @import("std");
const interfaceCast = @import("interfaceCast").interfaceCast;
const print = std.debug.print;
const testing = std.testing;

pub fn AnyIterator(comptime T: type) type {
    return struct {
        context: *anyopaque,
        vtable: *const struct {
            next: *const fn (self: *anyopaque) ?T,
        },

        pub fn next(self: @This()) ?T {
            return self.vtable.next(self.context);
        }
    };
}

const AnyStringIterator = AnyIterator([:0]const u8);

pub fn main() !void {
    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    defer args.deinit();

    const iterator = interfaceCast(AnyStringIterator, &args);
    printAll(iterator);
}

pub fn printAll(iterator: AnyStringIterator) void {
    while (iterator.next()) |item| {
        print("next() -> \"{s}\"\r\n", .{item});
    }
}

test "iterator" {
    const expected_items = &.{ "hello", "world" };
    var split = std.mem.splitScalar(u8, "hello world", ' ');

    const iterator = interfaceCast(AnyIterator([]const u8), &split);
    try testing.expectEqual(AnyIterator([]const u8), @TypeOf(iterator));
    try testing.expectEqual(iterator.context, @as(*anyopaque, @ptrCast(&split)));

    inline for (expected_items) |item| {
        const item_str = iterator.next();
        try testing.expect(item_str != null);
        try testing.expectEqualStrings(item, item_str.?);
    }
    try testing.expectEqual(null, iterator.next());
}
