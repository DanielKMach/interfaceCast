# interfaceCast

A more Zig-like way of making interfaces.

## Example

```zig
const std = @import("std");
const interfaceCast = @import("interfaceCast").interfaceCast;

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

    std.debug.print("Player health: {d}%\r\n", .{entity.health()}); // Player health: 100%
    player.current_health -= 25;
    std.debug.print("Player health: {d}%\r\n", .{entity.health()}); // Player health: 75%

    std.debug.print("Player is at ({d}, {d})\r\n", .{ player.x, player.y }); // Player is at (0, 0)
    entity.move(10, 5);
    std.debug.print("Player is at ({d}, {d})\r\n", .{ player.x, player.y }); // Player is at (10, 5)
    entity.move(5, 10);
    std.debug.print("Player is at ({d}, {d})\r\n", .{ player.x, player.y }); // Player is at (15, 15)
}
```

## Adding to a project

Run the following command to add the library to your project.

```bash
zig fetch --save git+https://github.com/DanielKMach/interfaceCast#main
```

Then import the module through your `build.zig`

```zig
const interface_cast = b.dependency("interfaceCast", .{
    .target = b.standardTargetOptions(.{}),
    .optimize = b.standardOptimizeOption(.{}),
});

your_exe.root_module.addImport("interfaceCast", interface_cast.module("interfaceCast"));
```

## Collaborating

Feel free to open an issue or make a PR.