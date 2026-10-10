const std = @import("std");
const Codec = @import("Codec.zig");

pub const Book = struct {
    name: []const u8,
    b64: []const u8,
};
pub const Cap = struct {
    login: ?Codec.Val,
    char: ?Codec.Val,
    enter: ?Codec.Val,
    books: ?[]const Book,
};

const LoadError = error{
    BadCapture,
    OutOfMemory,
};

fn numI64(val: std.json.Value) LoadError!i64 {
    return switch (val) {
        .integer => |num| num,
        .float => |num| @intFromFloat(num),
        else => error.BadCapture,
    };
}

fn numF64(val: std.json.Value) LoadError!f64 {
    return switch (val) {
        .float => |num| num,
        .integer => |num| @floatFromInt(num),
        else => error.BadCapture,
    };
}

fn tagOf(val: std.json.Value) LoadError!u8 {
    const num = try numI64(val);
    if (num < 0 or num > 255) return error.BadCapture;
    return @intCast(num);
}

fn toNode(alloc: std.mem.Allocator, node: std.json.Value) LoadError!Codec.Val {
    if (node != .object) return error.BadCapture;
    if (node.object.get("__buf")) |buf| {
        if (buf != .string) return error.BadCapture;
        const raw = Codec.b64dec(alloc, buf.string) catch return error.OutOfMemory;
        return Codec.Val{ .byteArr = raw };
    }
    const tagNode = node.object.get("t") orelse return error.BadCapture;
    const valNode = node.object.get("v") orelse return error.BadCapture;
    const tag = try tagOf(tagNode);
    switch (tag) {
        0 => return Codec.Val.null,
        1 => {
            if (valNode != .bool) return error.BadCapture;
            return Codec.Val{ .boolean = valNode.bool };
        },
        2 => return Codec.Val{ .byte = @intCast(try numI64(valNode)) },
        3 => return Codec.Val{ .short = @intCast(try numI64(valNode)) },
        4 => return Codec.Val{ .int = @intCast(try numI64(valNode)) },
        5 => return Codec.Val{ .long = try numI64(valNode) },
        6 => return Codec.Val{ .float = @floatCast(try numF64(valNode)) },
        7 => return Codec.Val{ .double = try numF64(valNode) },
        8 => {
            if (valNode != .string) return error.BadCapture;
            const dup = alloc.dupe(u8, valNode.string) catch return error.OutOfMemory;
            return Codec.Val{ .str = dup };
        },
        9 => {
            if (valNode != .array) return error.BadCapture;
            const items = alloc.alloc(bool, valNode.array.items.len) catch return error.OutOfMemory;
            for (valNode.array.items, 0..) |entry, idx| {
                if (entry != .bool) return error.BadCapture;
                items[idx] = entry.bool;
            }
            return Codec.Val{ .boolArr = items };
        },
        10 => {
            if (valNode == .string) {
                const raw = Codec.b64dec(alloc, valNode.string) catch return error.OutOfMemory;
                return Codec.Val{ .byteArr = raw };
            }
            if (valNode != .array) return error.BadCapture;
            const items = alloc.alloc(u8, valNode.array.items.len) catch return error.OutOfMemory;
            for (valNode.array.items, 0..) |entry, idx| {
                items[idx] = @intCast(try numI64(entry));
            }
            return Codec.Val{ .byteArr = items };
        },
        11 => {
            if (valNode != .array) return error.BadCapture;
            const items = alloc.alloc(i16, valNode.array.items.len) catch return error.OutOfMemory;
            for (valNode.array.items, 0..) |entry, idx| {
                items[idx] = @intCast(try numI64(entry));
            }
            return Codec.Val{ .shortArr = items };
        },
        12 => {
            if (valNode != .array) return error.BadCapture;
            const items = alloc.alloc(i32, valNode.array.items.len) catch return error.OutOfMemory;
            for (valNode.array.items, 0..) |entry, idx| {
                items[idx] = @intCast(try numI64(entry));
            }
            return Codec.Val{ .intArr = items };
        },
        13 => {
            if (valNode != .array) return error.BadCapture;
            const items = alloc.alloc(i64, valNode.array.items.len) catch return error.OutOfMemory;
            for (valNode.array.items, 0..) |entry, idx| {
                items[idx] = try numI64(entry);
            }
            return Codec.Val{ .longArr = items };
        },
        14 => {
            if (valNode != .array) return error.BadCapture;
            const items = alloc.alloc(f32, valNode.array.items.len) catch return error.OutOfMemory;
            for (valNode.array.items, 0..) |entry, idx| {
                items[idx] = @floatCast(try numF64(entry));
            }
            return Codec.Val{ .floatArr = items };
        },
        15 => {
            if (valNode != .array) return error.BadCapture;
            const items = alloc.alloc(f64, valNode.array.items.len) catch return error.OutOfMemory;
            for (valNode.array.items, 0..) |entry, idx| {
                items[idx] = try numF64(entry);
            }
            return Codec.Val{ .doubleArr = items };
        },
        16 => {
            if (valNode != .array) return error.BadCapture;
            const items = alloc.alloc([]const u8, valNode.array.items.len) catch return error.OutOfMemory;
            for (valNode.array.items, 0..) |entry, idx| {
                if (entry != .string) return error.BadCapture;
                items[idx] = alloc.dupe(u8, entry.string) catch return error.OutOfMemory;
            }
            return Codec.Val{ .strArr = items };
        },
        17 => {
            if (valNode != .array) return error.BadCapture;
            const items = alloc.alloc(Codec.Elem, valNode.array.items.len) catch return error.OutOfMemory;
            for (valNode.array.items, 0..) |entry, idx| {
                if (entry != .object) return error.BadCapture;
                const et = entry.object.get("t") orelse return error.BadCapture;
                items[idx] = Codec.Elem{
                    .tag = try tagOf(et),
                    .val = try toNode(alloc, entry),
                };
            }
            return Codec.Val{ .arr = items };
        },
        18 => {
            if (valNode != .object) return error.BadCapture;
            return toObjFrom(alloc, valNode.object);
        },
        20 => {
            if (valNode != .string) return error.BadCapture;
            const dup = alloc.dupe(u8, valNode.string) catch return error.OutOfMemory;
            return Codec.Val{ .text = dup };
        },
        else => return error.BadCapture,
    }
}

fn toObjFrom(alloc: std.mem.Allocator, obj: std.json.ObjectMap) LoadError!Codec.Val {
    const entries = alloc.alloc(Codec.Entry, obj.count()) catch return error.OutOfMemory;
    var it = obj.iterator();
    var idx: usize = 0;
    while (it.next()) |entry| {
        entries[idx] = Codec.Entry{
            .key = alloc.dupe(u8, entry.key_ptr.*) catch return error.OutOfMemory,
            .val = try toNode(alloc, entry.value_ptr.*),
        };
        idx += 1;
    }
    return Codec.Val{ .obj = entries };
}

fn loadTree(alloc: std.mem.Allocator, io: std.Io, dir: []const u8, name: []const u8) ?Codec.Val {
    const path = std.fmt.allocPrint(alloc, "{s}/{s}", .{ dir, name }) catch return null;
    defer alloc.free(path);
    const data = std.Io.Dir.cwd().readFileAlloc(io, path, alloc, .limited(32 * 1024 * 1024)) catch return null;
    defer alloc.free(data);
    var parsed = std.json.parseFromSlice(std.json.Value, alloc, data, .{}) catch return null;
    defer parsed.deinit();
    if (parsed.value != .object) return null;
    return toObjFrom(alloc, parsed.value.object) catch null;
}

fn loadBooks(alloc: std.mem.Allocator, io: std.Io, dir: []const u8) ?[]const Book {
    const path = std.fmt.allocPrint(alloc, "{s}/books-raw.json", .{dir}) catch return null;
    defer alloc.free(path);
    const data = std.Io.Dir.cwd().readFileAlloc(io, path, alloc, .limited(64 * 1024 * 1024)) catch return null;
    defer alloc.free(data);
    var parsed = std.json.parseFromSlice(std.json.Value, alloc, data, .{}) catch return null;
    defer parsed.deinit();
    if (parsed.value != .object) return null;
    var list: std.ArrayList(Book) = .empty;
    var it = parsed.value.object.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.* != .string) return null;
        const key = alloc.dupe(u8, entry.key_ptr.*) catch return null;
        const dat = alloc.dupe(u8, entry.value_ptr.string) catch return null;
        list.append(alloc, .{ .name = key, .b64 = dat }) catch return null;
    }
    return list.toOwnedSlice(alloc) catch return null;
}

pub fn load(alloc: std.mem.Allocator, io: std.Io, dir: []const u8) !Cap {
    return Cap{
        .login = loadTree(alloc, io, dir, "login-p.json"),
        .char = loadTree(alloc, io, dir, "char.json"),
        .enter = loadTree(alloc, io, dir, "enter-town.json"),
        .books = loadBooks(alloc, io, dir),
    };
}
