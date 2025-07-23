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
        @field(interface.vtable, f.name) = &@field(T, &func_name);
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
        const field_info = @typeInfo(@typeInfo(field.type).pointer.child).@"fn";
        if (field_info.params.len == 0) @compileError("'" ++ field.name ++ "' field of vtable must have at least one parameter");
        if (field_info.params[0].type != *anyopaque) @compileError("First parameter of '" ++ field.name ++ "' field of vtable must be of type '*anyopaque'");

        const func_name = comptime funcName(field.name);
        if (!@hasDecl(T, &func_name)) @compileError(@TypeOf(T) ++ " does not have a declaration for '" ++ field.name ++ "'");
        if (@TypeOf(&@field(T, &func_name)) != field.type) {
            @compileError("Signature of function '" ++ &func_name ++ "' in " ++ @typeName(T) ++ " does not match type in vtable: expected " ++ @typeName(field.type) ++ ", found " ++ @typeName(@TypeOf(@field(T, &func_name))));
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
        },

        pub fn health(self: @This()) u32 {
            return self.vtable.health(self.data);
        }
    };

    const Player = struct {
        current_health: u32,

        pub fn health(self: *anyopaque) u32 {
            const player: *@This() = @alignCast(@ptrCast(self));
            return player.current_health;
        }
    };

    var player = Player{ .current_health = 100 };
    const entity = interfaceCast(Entity, &player);

    try testing.expectEqual(Entity, @TypeOf(entity));
    try testing.expectEqual(entity.health(), 100);
}
