const std = @import("std");
const testing = std.testing;

pub inline fn interfaceCast(comptime I: type, ctx: anytype) I {
    if (@typeInfo(I) != .@"struct") @compileError(@typeName(I) ++ " must be a struct, found '" ++ @tagName(@typeInfo(I)) ++ "'");
    const T = comptime ContextType(@TypeOf(ctx));
    const VTable = comptime VTableType(I);
    const ctx_field = comptime checkContextField(I);
    comptime validateTableFunctions(VTable, T);

    var interface: I = undefined;

    @field(interface, ctx_field) = @ptrCast(ctx);
    @field(interface, "vtable") = &(comptime blk: {
        var table: VTable = undefined;
        for (@typeInfo(VTable).@"struct".fields) |f| {
            @field(table, f.name) = @ptrCast(&@field(T, &funcName(f.name)));
        }
        break :blk table;
    });
    return interface;
}

inline fn ContextType(T: type) type {
    const info = @typeInfo(T);
    if (info != .pointer or info.pointer.is_const or info.pointer.size != .one or @typeInfo(info.pointer.child) != .@"struct") {
        @compileError("data must be a mutable pointer to one struct element, found '" ++ @typeName(T) ++ "'");
    }
    return info.pointer.child;
}

inline fn VTableType(comptime I: type) type {
    if (!@hasField(I, "vtable")) {
        @compileError(@typeName(I) ++ " must have a 'vtable' field");
    }
    const FieldType = @FieldType(I, "vtable");
    const info = @typeInfo(FieldType);
    if (info != .pointer or !info.pointer.is_const or info.pointer.size != .one or @typeInfo(info.pointer.child) != .@"struct") {
        @compileError("'vtable' field must be a const pointer to one struct element, found '" ++ @typeName(FieldType) ++ "'");
    }
    return info.pointer.child;
}

inline fn checkContextField(comptime I: type) []const u8 {
    const names = .{ "context", "ptr", "data", "userdata" };
    for (names) |name| {
        if (@hasField(I, name) and @FieldType(I, name) == *anyopaque) {
            return name;
        }
    }
    @compileError(@typeName(I) ++ " must have a 'context', 'ptr', 'data' or 'userdata' field of type '*anyopaque'");
}

inline fn validateTableFunctions(comptime VTable: type, comptime T: type) void {
    const fields = @typeInfo(VTable).@"struct".fields;
    for (fields) |field| {
        checkFunctions(VTable, T, field.name);
    }
}

inline fn checkFunctions(comptime VTable: type, comptime T: type, comptime name: []const u8) void {
    if (@typeInfo(@FieldType(VTable, name)) != .pointer or @typeInfo(@typeInfo(@FieldType(VTable, name)).pointer.child) != .@"fn") {
        @compileError("'" ++ name ++ "' field of vtable must be a pointer to a function");
    }

    const func_name = comptime funcName(name);
    if (!@hasDecl(T, &func_name)) {
        @compileError(@typeName(T) ++ " does not have a declaration for '" ++ &func_name ++ "'");
    }

    const interface_fn_info = @typeInfo(@typeInfo(@FieldType(VTable, name)).pointer.child).@"fn";
    const data_fn_info = @typeInfo(@TypeOf(@field(T, &func_name))).@"fn";
    if (interface_fn_info.params.len != data_fn_info.params.len) {
        @compileError("Function '" ++ &func_name ++ "' in " ++ @typeName(T) ++ " has a different number of parameters than the vtable function: expected " ++ data_fn_info.params.len ++ ", found " ++ interface_fn_info.params.len);
    }

    validateFunctions(interface_fn_info, data_fn_info, T, name);
}

inline fn validateFunctions(interface_fn: std.builtin.Type.Fn, data_fn: std.builtin.Type.Fn, comptime T: type, comptime name: []const u8) void {
    if (interface_fn.params.len != data_fn.params.len) {
        @compileError("Function parameter count mismatch: expected " ++ interface_fn.params.len ++ ", found " ++ data_fn.params.len);
    }
    for (interface_fn.params, data_fn.params, 0..) |interface_param, data_param, i| {
        if (i == 0) {
            if (interface_param.type != *anyopaque) @compileError("First parameter of '" ++ name ++ "' field of vtable must be of type '*anyopaque', found " ++ @typeName(interface_param.type));
            if (@typeInfo(data_param.type.?) != .pointer) @compileError("First parameter of function '" ++ name ++ "' in " ++ @typeName(T) ++ " must be a pointer to " ++ @typeName(T) ++ ", found " ++ @typeName(data_param.type.?));
            if (@typeInfo(data_param.type.?).pointer.child != T) {
                @compileError("First parameter of function '" ++ name ++ "' in " ++ @typeName(T) ++ " must be a pointer to " ++ @typeName(T) ++ ", found " ++ @typeName(data_param.type.?));
            }
            continue;
        }
        if (interface_param.type != data_param.type) {
            @compileError("Parameter type mismatch in function '" ++ name ++ "': expected " ++ @typeName(data_param.type.?) ++ ", found " ++ @typeName(interface_param.type.?));
        }
    }
    if (interface_fn.return_type != data_fn.return_type) {
        @compileError("Return type mismatch in function '" ++ name ++ "': expected " ++ @typeName(data_fn.return_type.?) ++ ", found " ++ @typeName(interface_fn.return_type.?));
    }
}

fn funcName(comptime field: []const u8) [funcNameCount(field)]u8 {
    var new_name: [funcNameCount(field)]u8 = undefined;
    var off: usize = 0;
    for (0..new_name.len) |i| {
        if (field[i + off] == '_') {
            off += 1;
            new_name[i] = std.ascii.toUpper(field[i + off]);
        } else {
            new_name[i] = field[i + off];
        }
    }
    return new_name;
}

inline fn funcNameCount(comptime field: []const u8) usize {
    return field.len - std.mem.count(u8, field, "_");
}

test funcName {
    const test_cases = [_][]const u8{
        "test_function",
        "another_test_function",
        "simpleFunction",
        "functionWithNoUnderscores",
    };
    const expected_results = [_][]const u8{
        "testFunction",
        "anotherTestFunction",
        "simpleFunction",
        "functionWithNoUnderscores",
    };

    inline for (test_cases, expected_results) |test_case, expected| {
        const result = funcName(test_case);
        const comptime_result = comptime funcName(test_case);
        try testing.expectEqualSlices(u8, &result, expected);
        try testing.expectEqualSlices(u8, &comptime_result, expected);
    }
}

test "interface" {
    const Entity = struct {
        data: *anyopaque,
        vtable: *const struct {
            health: *const fn (self: *anyopaque) u32,
            move: *const fn (self: *anyopaque, x: f32, y: f32) void,
        },

        pub fn health(self: @This()) u32 {
            return self.vtable.health(self.data);
        }

        pub fn move(self: @This(), x: f32, y: f32) void {
            self.vtable.move(self.data, x, y);
        }
    };

    const Player = struct {
        current_health: u32,
        x: f32,
        y: f32,

        pub fn health(self: *const @This()) u32 {
            return self.current_health;
        }

        pub fn move(self: *@This(), x: f32, y: f32) void {
            self.x += x;
            self.y += y;
        }
    };

    var player = Player{ .current_health = 100, .x = 0, .y = 0 };
    const entity = interfaceCast(Entity, &player);

    try testing.expectEqual(Entity, @TypeOf(entity));

    try testing.expectEqual(entity.data, @as(*anyopaque, @ptrCast(&player)));
    try testing.expectEqual(entity.health(), 100);

    entity.move(5, 10);
    try testing.expectEqual(player.x, 5);
    try testing.expectEqual(player.y, 10);

    entity.move(10, 5);
    try testing.expectEqual(player.x, 15);
    try testing.expectEqual(player.y, 15);
}
