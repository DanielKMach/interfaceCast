const std = @import("std");
const interfaceCast = @import("interfaceCast").interfaceCast;
const print = std.debug.print;

pub fn Iterator(comptime T: type) type {
    return struct {
        data: *anyopaque,
        vtable: *const struct {
            next: *const fn (self: *anyopaque) ?T,
        },

        pub fn next(self: @This()) ?T {
            return self.vtable.next(self.data);
        }
    };
}

const StringIterator = Iterator([:0]const u8);

pub fn main() !void {
    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    defer args.deinit();

    const iterator = interfaceCast(StringIterator, &args);
    printAll(iterator);
}

pub fn printAll(iterator: StringIterator) void {
    while (iterator.next()) |item| {
        print("next() -> \"{s}\"\r\n", .{item});
    }
}
