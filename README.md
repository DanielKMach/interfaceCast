# interfaceCast

A Zig-ish way of handling interfaces.

### Features

- [x] `interfaceCast` allows you to cast any struct into an interface.
    - Interfaces are just structs that have both a `vtable` and a `context` field.
    - The `context` (`ptr`, `data` and `userdata` also works) field must be of type `*anyopaque`.
    - The `vtable` field must be a constant pointer to a struct and each field of that struct must be a constant pointer to a function.
- [x] Automatic casting of `*anyopaque` into the interface's context type.
- [x] Automatic error coercion if the interface returns an error superset of its context type's (see example below).
- [x] Allows for generic interfaces (see example below).
- [x] Friendly with predefined interfaces (like the ones from std).

### Example

```zig
const std = @import("std");
const interfaceCast = @import("interfaceCast").interfaceCast;
const print = std.debug.print;
const assert = std.debug.assert;

/// This is an interface that can be used to represent a list
/// that can append and pop elements of type `T`.
pub fn AnyList(comptime T: type) type {

    // Interfaces are just structs with `context` and `vtable` fields.
    return struct {

        // This is the context field, which must of type `*anyopaque`.
        context: *anyopaque,

        // This is the vtable field, which must be a constant pointer to a struct.
        //
        // Each field in the vtable must be a constant pointer to a function
        //
        // The name of each field is significant, as it directly maps to the context type's function names.
        // Since we want this interface to append and pop elements, we define the vtable with `append` and `pop` fields.
        // The function signatures must match the context type's function signatures.
        vtable: *const struct {
            append: *const fn (self: *anyopaque, value: T) error{ OutOfMemory, Overflow }!void,
            pop: *const fn (self: *anyopaque) ?T,
        },

        // Notice how the following function return type is an error union with `OutOfMemory` and `Overflow`.
        // This is the case because `ArrayList` might return `error.OutOfMemory` when appending an element,
        // and `BoundedArray` might return `error.Overflow` when trying to append an element
        // that exceeds its defined capacity.
        //
        // So to allow both `ArrayList` and `BoundedArray` to be cast to this interface,
        // we need to define the return type to be an error union that is a superset
        // of both `ArrayList` and `BoundedArray` error sets.
        //
        // This is possible because `interfaceCast` automatically detects that the return
        // type is a superset of the context type's.
        pub fn append(self: @This(), value: T) error{ OutOfMemory, Overflow }!void {
            // Here we call the function from the vtable.
            try self.vtable.append(self.context, value);
        }

        // Interfaces can also return values.
        pub fn pop(self: @This()) ?T {
            // Here we also call the function from the vtable.
            return self.vtable.pop(self.context);
        }
    };
}

/// Appends numbers from 0 to `count - 1` to the provided list.
pub fn appendNumbers(list: AnyList(usize), count: usize) anyerror!void {
    for (0..count) |i| {
        try list.append(i);
    }
}

/// Pops all elements from the list and prints them.
pub fn popAll(list: AnyList(usize)) void {
    while (list.pop()) |item| {
        print("{d} ", .{item});
    }
    print("\r\n", .{});
}

pub fn main() !void {
    // Lets try casting an `ArrayList` to the `AnyList` interface.
    var arraylist = std.ArrayList(usize).init(std.heap.page_allocator);
    defer arraylist.deinit();

    const any_list = interfaceCast(AnyList(usize), &arraylist);
    try appendNumbers(any_list, 5);
    assert(arraylist.items.len == 5);
    // Notice how we fed `any_list` to `appendNumbers`, and `arraylist` gets updated.

    popAll(any_list); // Prints: 4 3 2 1 0
    assert(arraylist.items.len == 0);

    // Lets try the same thing, but now with a `BoundedArray`.
    var bounded_array = std.BoundedArray(usize, 3){};

    const any_list2 = interfaceCast(AnyList(usize), &bounded_array);
    try appendNumbers(any_list2, 3);
    assert(bounded_array.len == 3);
    // Just like the last time, when we append to `any_list2`, `bounded_array` gets updated.

    assert(any_list2.append(3) == error.Overflow);
    // Interfaces can also return errors.

    popAll(any_list2); // Prints: 2 1 0
    assert(bounded_array.len == 0);
}
```

## Adding to a project

Run the following command to add the package to your project.

```bash
zig fetch --save git+https://github.com/DanielKMach/interfaceCast#main
```

Then add it as an import in your `build.zig`

```zig
const interface_cast = b.dependency("interfaceCast", .{
    .target = target,
    .optimize = optimize,
});

your_exe_module.addImport("interfaceCast", interface_cast.module("interfaceCast"));
```

Now you are ready to use it in your code.

```zig
const interfaceCast = @import("interfaceCast").interfaceCast;
```

## Contributing

Feel free to open an issue or make a PR.