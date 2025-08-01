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
            @field(table, f.name) = @ptrCast(&@field(T, f.name));
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

    if (!@hasDecl(T, name)) {
        @compileError(@typeName(T) ++ " does not have a declaration for '" ++ name ++ "'");
    }

    const interface_fn_info = @typeInfo(@typeInfo(@FieldType(VTable, name)).pointer.child).@"fn";
    const data_fn_info = @typeInfo(@TypeOf(@field(T, name))).@"fn";
    if (interface_fn_info.params.len != data_fn_info.params.len) {
        @compileError("Function '" ++ name ++ "' in " ++ @typeName(T) ++ " has a different number of parameters than the vtable function: expected " ++ data_fn_info.params.len ++ ", found " ++ interface_fn_info.params.len);
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
    if (interface_fn.return_type != null and @typeInfo(interface_fn.return_type.?) == .error_union and data_fn.return_type != null and @typeInfo(data_fn.return_type.?) == .error_union) {
        const interface_union = @typeInfo(interface_fn.return_type.?).error_union;
        const data_union = @typeInfo(data_fn.return_type.?).error_union;
        if (!isSuperSetOf(interface_union.error_set, data_union.error_set)) {
            @compileError("Return type error union mismatch in function '" ++ name ++ "': expected a superset of " ++ @typeName(data_union.error_set) ++ ", found " ++ @typeName(interface_union.error_set));
        }
        if (interface_union.payload != data_union.payload) {
            @compileError("Return type error union payload mismatch in function '" ++ name ++ "': expected " ++ @typeName(data_union.payload) ++ ", found " ++ @typeName(interface_union.payload));
        }
    } else if (interface_fn.return_type != data_fn.return_type) {
        @compileError("Return type mismatch in function '" ++ name ++ "': expected " ++ @typeName(data_fn.return_type.?) ++ ", found " ++ @typeName(interface_fn.return_type.?));
    }
}

inline fn isSuperSetOf(comptime A: type, comptime B: type) bool {
    std.debug.assert(@typeInfo(A) == .error_set);
    std.debug.assert(@typeInfo(B) == .error_set);
    const a_set = @typeInfo(A).error_set;
    const b_set = @typeInfo(B).error_set;

    if (a_set == null) return true;
    if (b_set == null) return false;

    m: for (b_set.?) |b| {
        for (a_set.?) |a| {
            if (std.mem.eql(u8, a.name, b.name)) continue :m;
        }
        return false;
    }
    return true;
}

test isSuperSetOf {
    const A = error{ A, B, C };
    const B = error{ B, C };
    const C = error{C};

    try testing.expect(isSuperSetOf(A, A));
    try testing.expect(isSuperSetOf(A, B));
    try testing.expect(isSuperSetOf(A, C));
    try testing.expect(!isSuperSetOf(B, A));
    try testing.expect(isSuperSetOf(B, B));
    try testing.expect(isSuperSetOf(B, C));
    try testing.expect(!isSuperSetOf(C, A));
    try testing.expect(!isSuperSetOf(C, B));
    try testing.expect(isSuperSetOf(C, C));
    try testing.expect(!isSuperSetOf(A, anyerror));
    try testing.expect(!isSuperSetOf(B, anyerror));
    try testing.expect(!isSuperSetOf(C, anyerror));
    try testing.expect(isSuperSetOf(anyerror, A));
    try testing.expect(isSuperSetOf(anyerror, B));
    try testing.expect(isSuperSetOf(anyerror, C));
}
