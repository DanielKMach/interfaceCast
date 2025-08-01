const std = @import("std");
const interfaceCast = @import("interfaceCast").interfaceCast;
const print = std.debug.print;
const testing = std.testing;

pub const Entity = struct {
    context: *anyopaque,
    vtable: *const struct {
        health: *const fn (self: *anyopaque) u32,
        move: *const fn (self: *anyopaque, x: f32, y: f32) void,
    },

    pub fn health(self: Entity) u32 {
        return self.vtable.health(self.context);
    }

    pub fn move(self: Entity, x: f32, y: f32) void {
        self.vtable.move(self.context, x, y);
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

test "player" {
    var player = Player{ .current_health = 100, .x = 0, .y = 0 };
    const entity = interfaceCast(Entity, &player);

    try testing.expectEqual(Entity, @TypeOf(entity));

    try testing.expectEqual(entity.context, @as(*anyopaque, @ptrCast(&player)));
    try testing.expectEqual(entity.health(), 100);

    entity.move(5, 10);
    try testing.expectEqual(player.x, 5);
    try testing.expectEqual(player.y, 10);

    entity.move(10, 5);
    try testing.expectEqual(player.x, 15);
    try testing.expectEqual(player.y, 15);
}
