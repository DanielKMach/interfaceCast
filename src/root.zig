const std = @import("std");
const testing = std.testing;

pub inline fn interfaceCast(comptime I: type, data: anytype) I {
    if (@typeInfo(I) != .@"struct") @compileError(@typeName(I) ++ " is not a struct type");
    const T = DataType(data);
    comptime validateDataField(I);
    comptime validateVTableField(I);
    comptime validateTableFunctions(I, T);

    const funcs = @typeInfo(@FieldType(I, "vtable")).@"struct".fields;
    var interface: I = undefined;

    interface.data = @ptrCast(data);
    inline for (funcs) |f| {
        const func_name = comptime funcName(f.name);
        @field(interface.vtable, f.name) = @ptrCast(&@field(T, &func_name));
    }
    return interface;
}

inline fn DataType(data: anytype) type {
    if (@typeInfo(@TypeOf(data)) != .pointer) @compileError("data must be a pointer type");
    const T = @typeInfo(@TypeOf(data)).pointer.child;
    if (@typeInfo(T) != .@"struct") @compileError("data must be a pointer to a struct");
    return T;
}

inline fn validateDataField(comptime I: type) void {
    if (!@hasField(I, "data")) @compileError(@typeName(I) ++ " does not have a 'data' field");
    if (@FieldType(I, "data") != *anyopaque) @compileError("'data' field of " ++ @typeName(I) ++ " must be of type '*anyopaque'");
}

inline fn validateVTableField(comptime I: type) void {
    if (!@hasField(I, "vtable")) @compileError(@typeName(I) ++ " does not have a 'vtable' field");
    if (@typeInfo(@FieldType(I, "vtable")) != .@"struct") @compileError("'vtable' field of " ++ @typeName(I) ++ " must be a struct");
}

inline fn validateTableFunctions(comptime I: type, comptime T: type) void {
    const fields = @typeInfo(@FieldType(I, "vtable")).@"struct".fields;
    for (fields) |field| {
        if (@typeInfo(field.type) != .pointer or @typeInfo(@typeInfo(field.type).pointer.child) != .@"fn") @compileError("'" ++ field.name ++ "' field of vtable must be a pointer to a function");

        const func_name = comptime funcName(field.name);
        if (!@hasDecl(T, &func_name)) @compileError(@typeName(T) ++ " does not have a declaration for '" ++ field.name ++ "'");

        const interface_fn_info = @typeInfo(@typeInfo(field.type).pointer.child).@"fn";
        const data_fn_info = @typeInfo(@TypeOf(@field(T, &func_name))).@"fn";
        if (interface_fn_info.params.len == 0) @compileError("'" ++ field.name ++ "' field of vtable must have at least one parameter");
        if (interface_fn_info.params.len != data_fn_info.params.len) @compileError("Function '" ++ &func_name ++ "' in " ++ @typeName(T) ++ " has a different number of parameters than the vtable function: expected " ++ data_fn_info.params.len ++ ", found " ++ interface_fn_info.params.len);

        for (interface_fn_info.params, data_fn_info.params, 0..) |interface_param, data_param, i| {
            if (i == 0) {
                if (interface_param.type != *anyopaque) @compileError("First parameter of '" ++ field.name ++ "' field of vtable must be of type '*anyopaque', found " ++ @typeName(interface_param.type));
                if (data_param.type != *T and data_param.type != *const T) @compileError("First parameter of function '" ++ &func_name ++ "' in " ++ @typeName(T) ++ " must be of type '*" ++ @typeName(T) ++ "', found " ++ @typeName(data_param.type.?));
                continue;
            }
            if (interface_param.type != data_param.type) {
                @compileError("Parameter type mismatch in function '" ++ &func_name ++ "': expected " ++ @typeName(data_param.type.?) ++ ", found " ++ @typeName(interface_param.type.?));
            }
        }
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
        vtable: struct {
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
    try testing.expectEqual(entity.health(), 100);

    entity.move(5, 10);
    try testing.expectEqual(player.x, 5);
    try testing.expectEqual(player.y, 10);
}
