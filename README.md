# interfaceCast

A Zig-ish way of handling interfaces.

### Features

- [x] `interfaceCast` allows you to cast any struct into an interface.
- [x] Friendly with predefined interfaces (like the ones from std) as long as they have both a `vtable` and `context` fields.
    - The `context` (`ptr`, `data` and `userdata` also works) field must be of type `*anyopaque`.
    - The `vtable` field must be a pointer to a constant struct and must only contain contant pointers to functions.
- [x] Automatic casting of `*anyopaque` into its context type.
- [x] Automatic error coercion if the interface's function returns an error superset of its context's function return type (see `examples/list.zig`).
- [x] Since interfaces are just structs, `interfaceCast` also supports generic interfaces (check `examples/iterator.zig` and `examples/list.zig`).

### Example

```zig
const std = @import("std");
const interfaceCast = @import("interfaceCast").interfaceCast;
const print = std.debug.print;

pub const Entity = struct {
    data: *anyopaque,
    vtable: *const struct {
        health: *const fn (self: *anyopaque) u32,
        move: *const fn (self: *anyopaque, x: f32, y: f32) void,
    },

    pub fn health(self: Entity) u32 {
        return self.vtable.health(self.data);
    }

    pub fn move(self: Entity, x: f32, y: f32) void {
        self.vtable.move(self.data, x, y);
    }
};

pub const Player = struct {
    current_health: u32,
    x: f32,
    y: f32,

    pub fn health(self: *const Player) u32 {
        return self.current_health;
    }

    pub fn move(self: *Player, x: f32, y: f32) void {
        self.x += x;
        self.y += y;
    }
};

pub fn main() void {
    var player = Player{ .current_health = 100, .x = 0, .y = 0 };
    const entity = interfaceCast(Entity, &player);

    print("Player health: {d}%\r\n", .{entity.health()}); // Player health: 100%
    player.current_health -= 25;
    print("Player health: {d}%\r\n", .{entity.health()}); // Player health: 75%

    print("Player is at ({d}, {d})\r\n", .{ player.x, player.y }); // Player is at (0, 0)
    entity.move(10, 5);
    print("Player is at ({d}, {d})\r\n", .{ player.x, player.y }); // Player is at (10, 5)
    entity.move(5, 10);
    print("Player is at ({d}, {d})\r\n", .{ player.x, player.y }); // Player is at (15, 15)
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