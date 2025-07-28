const std = @import("std");
const interfaceCast = @import("interfaceCast").interfaceCast;
const print = std.debug.print;

pub fn AnyList(comptime T: type) type {
    return struct {
        data: *anyopaque,
        vtable: *const struct {
            append: *const fn (self: *anyopaque, value: T) error{ OutOfMemory, Overflow }!void,
        },

        pub fn append(self: @This(), value: T) error{ OutOfMemory, Overflow }!void {
            return self.vtable.append(self.data, value);
        }
    };
}

pub fn main() !void {
    var array = std.ArrayList(usize).init(std.heap.page_allocator);
    defer array.deinit();

    var bounded = std.BoundedArray(usize, 3){};

    var any_list = interfaceCast(AnyList(usize), &array);
    try appendNumbers(any_list, 5);

    any_list = interfaceCast(AnyList(usize), &bounded);
    try appendNumbers(any_list, 3);

    print("Numbers (ArrayList): ", .{});
    for (array.items) |item| {
        print("{d} ", .{item});
    }
    print("\r\n", .{});
    print("Numbers (BoundedArray): ", .{});
    for (bounded.slice()) |item| {
        print("{d} ", .{item});
    }
    print("\r\n", .{});
}

pub fn appendNumbers(list: AnyList(usize), count: usize) anyerror!void {
    for (0..count) |i| {
        try list.append(i);
    }
}
