const std = @import("std");

pub const Tag = struct {
    pub const NULL: u8 = 0;
    pub const BOOL: u8 = 1;
    pub const BYTE: u8 = 2;
    pub const SHORT: u8 = 3;
    pub const INT: u8 = 4;
    pub const LONG: u8 = 5;
    pub const FLOAT: u8 = 6;
    pub const DOUBLE: u8 = 7;
    pub const UTFSTRING: u8 = 8;
    pub const BOOLARRAY: u8 = 9;
    pub const BYTEARRAY: u8 = 10;
    pub const SHORTARRAY: u8 = 11;
    pub const INTARRAY: u8 = 12;
    pub const LONGARRAY: u8 = 13;
    pub const FLOATARRAY: u8 = 14;
    pub const DOUBLEARRAY: u8 = 15;
    pub const UTFSTRINGARRAY: u8 = 16;
    pub const SFSARRAY: u8 = 17;
    pub const SFSOBJECT: u8 = 18;
    pub const CLASS: u8 = 19;
    pub const TEXT: u8 = 20;
};

pub const Elem = struct {
    tag: u8,
    val: Val,
};

pub const Entry = struct {
    key: []const u8,
    val: Val,
};

pub const Val = union(enum) {
    null: void,
    boolean: bool,
    byte: u8,
    short: i16,
    int: i32,
    long: i64,
    float: f32,
    double: f64,
    str: []const u8,
    text: []const u8,
    boolArr: []const bool,
    byteArr: []const u8,
    shortArr: []const i16,
    intArr: []const i32,
    longArr: []const i64,
    floatArr: []const f32,
    doubleArr: []const f64,
    strArr: []const []const u8,
    arr: []const Elem,
    obj: []const Entry,
};
pub const Outer = struct {
    controller: u8,
    action: i16,
    params: []const Entry,
};
pub const Frame = struct {
    header: u8,
    body: []const u8,
};
const EncodeError = std.mem.Allocator.Error || error{ UtfTooLong, TextTooLong, TooLarge, TypeMismatch, UnknownType };
const DecodeError = std.mem.Allocator.Error || error{ Truncated, BadMarker, BadLength, UnknownType, BadOuter };
fn tagOfVal(val: Val) EncodeError!u8 {
    return switch (val) {
        .null => Tag.NULL,
        .boolean => Tag.BOOL,
        .byte => Tag.BYTE,
        .short => Tag.SHORT,
        .int => Tag.INT,
        .long => Tag.LONG,
        .float => Tag.FLOAT,
        .double => Tag.DOUBLE,
        .str => Tag.UTFSTRING,
        .boolArr => Tag.BOOLARRAY,
        .byteArr => Tag.BYTEARRAY,
        .shortArr => Tag.SHORTARRAY,
        .intArr => Tag.INTARRAY,
        .longArr => Tag.LONGARRAY,
        .floatArr => Tag.FLOATARRAY,
        .doubleArr => Tag.DOUBLEARRAY,
        .strArr => Tag.UTFSTRINGARRAY,
        .arr => Tag.SFSARRAY,
        .obj => Tag.SFSOBJECT,
        .text => Tag.TEXT,
    };
}
fn appendByte(list: *std.ArrayList(u8), alloc: std.mem.Allocator, val: u8) EncodeError!void {
    try list.append(alloc, val);
}
fn appendShort(list: *std.ArrayList(u8), alloc: std.mem.Allocator, val: i16) EncodeError!void {
    var buf: [2]u8 = undefined;
    std.mem.writeInt(i16, &buf, val, .big);
    try list.appendSlice(alloc, &buf);
}
fn appendUShort(list: *std.ArrayList(u8), alloc: std.mem.Allocator, val: u16) EncodeError!void {
    var buf: [2]u8 = undefined;
    std.mem.writeInt(u16, &buf, val, .big);
    try list.appendSlice(alloc, &buf);
}
fn appendInt(list: *std.ArrayList(u8), alloc: std.mem.Allocator, val: i32) EncodeError!void {
    var buf: [4]u8 = undefined;
    std.mem.writeInt(i32, &buf, val, .big);
    try list.appendSlice(alloc, &buf);
}
fn appendLong(list: *std.ArrayList(u8), alloc: std.mem.Allocator, val: i64) EncodeError!void {
    var buf: [8]u8 = undefined;
    std.mem.writeInt(i64, &buf, val, .big);
    try list.appendSlice(alloc, &buf);
}
fn appendFloat(list: *std.ArrayList(u8), alloc: std.mem.Allocator, val: f32) EncodeError!void {
    var buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &buf, @bitCast(val), .big);
    try list.appendSlice(alloc, &buf);
}
fn appendDouble(list: *std.ArrayList(u8), alloc: std.mem.Allocator, val: f64) EncodeError!void {
    var buf: [8]u8 = undefined;
    std.mem.writeInt(u64, &buf, @bitCast(val), .big);
    try list.appendSlice(alloc, &buf);
}
fn appendUtf(list: *std.ArrayList(u8), alloc: std.mem.Allocator, str: []const u8) EncodeError!void {
    if (str.len > 32767) return error.UtfTooLong;
    try appendUShort(list, alloc, @intCast(str.len));
    try list.appendSlice(alloc, str);
}
fn appendText(list: *std.ArrayList(u8), alloc: std.mem.Allocator, str: []const u8) EncodeError!void {
    if (str.len > 0x7fffffff) return error.TextTooLong;
    try appendInt(list, alloc, @intCast(str.len));
    try list.appendSlice(alloc, str);
}
fn appendCountShort(list: *std.ArrayList(u8), alloc: std.mem.Allocator, count: usize) EncodeError!void {
    if (count > 32767) return error.TooLarge;
    try appendShort(list, alloc, @intCast(count));
}
fn appendCountInt(list: *std.ArrayList(u8), alloc: std.mem.Allocator, count: usize) EncodeError!void {
    if (count > 0x7fffffff) return error.TooLarge;
    try appendInt(list, alloc, @intCast(count));
}
fn encodeValInto(list: *std.ArrayList(u8), alloc: std.mem.Allocator, val: Val) EncodeError!void {
    switch (val) {
        .null => try appendByte(list, alloc, Tag.NULL),
        .boolean => |flag| {
            try appendByte(list, alloc, Tag.BOOL);
            try appendByte(list, alloc, if (flag) 1 else 0);
        },
        .byte => |num| {
            try appendByte(list, alloc, Tag.BYTE);
            try appendByte(list, alloc, num);
        },
        .short => |num| {
            try appendByte(list, alloc, Tag.SHORT);
            try appendShort(list, alloc, num);
        },
        .int => |num| {
            try appendByte(list, alloc, Tag.INT);
            try appendInt(list, alloc, num);
        },
        .long => |num| {
            try appendByte(list, alloc, Tag.LONG);
            try appendLong(list, alloc, num);
        },
        .float => |num| {
            try appendByte(list, alloc, Tag.FLOAT);
            try appendFloat(list, alloc, num);
        },
        .double => |num| {
            try appendByte(list, alloc, Tag.DOUBLE);
            try appendDouble(list, alloc, num);
        },
        .str => |str| {
            try appendByte(list, alloc, Tag.UTFSTRING);
            try appendUtf(list, alloc, str);
        },
        .text => |str| {
            try appendByte(list, alloc, Tag.TEXT);
            try appendText(list, alloc, str);
        },
        .boolArr => |arr| {
            try appendByte(list, alloc, Tag.BOOLARRAY);
            try appendCountShort(list, alloc, arr.len);
            for (arr) |flag| try appendByte(list, alloc, if (flag) 1 else 0);
        },
        .byteArr => |arr| {
            try appendByte(list, alloc, Tag.BYTEARRAY);
            try appendCountInt(list, alloc, arr.len);
            try list.appendSlice(alloc, arr);
        },
        .shortArr => |arr| {
            try appendByte(list, alloc, Tag.SHORTARRAY);
            try appendCountShort(list, alloc, arr.len);
            for (arr) |num| try appendShort(list, alloc, num);
        },
        .intArr => |arr| {
            try appendByte(list, alloc, Tag.INTARRAY);
            try appendCountShort(list, alloc, arr.len);
            for (arr) |num| try appendInt(list, alloc, num);
        },
        .longArr => |arr| {
            try appendByte(list, alloc, Tag.LONGARRAY);
            try appendCountShort(list, alloc, arr.len);
            for (arr) |num| try appendLong(list, alloc, num);
        },
        .floatArr => |arr| {
            try appendByte(list, alloc, Tag.FLOATARRAY);
            try appendCountShort(list, alloc, arr.len);
            for (arr) |num| try appendFloat(list, alloc, num);
        },
        .doubleArr => |arr| {
            try appendByte(list, alloc, Tag.DOUBLEARRAY);
            try appendCountShort(list, alloc, arr.len);
            for (arr) |num| try appendDouble(list, alloc, num);
        },
        .strArr => |arr| {
            try appendByte(list, alloc, Tag.UTFSTRINGARRAY);
            try appendCountShort(list, alloc, arr.len);
            for (arr) |str| try appendUtf(list, alloc, str);
        },
        .arr => |arr| try encodeArrInto(list, alloc, arr),
        .obj => |obj| try encodeObjInto(list, alloc, obj),
    }
}
fn encodeElemInto(list: *std.ArrayList(u8), alloc: std.mem.Allocator, elem: Elem) EncodeError!void {
    const want = try tagOfVal(elem.val);
    if (want != elem.tag) return error.TypeMismatch;
    if (elem.tag == Tag.CLASS) return error.UnknownType;
    try encodeValInto(list, alloc, elem.val);
}
fn encodeObjInto(list: *std.ArrayList(u8), alloc: std.mem.Allocator, entries: []const Entry) EncodeError!void {
    if (entries.len > 32767) return error.TooLarge;
    try appendByte(list, alloc, Tag.SFSOBJECT);
    try appendShort(list, alloc, @intCast(entries.len));
    for (entries) |entry| {
        try appendUtf(list, alloc, entry.key);
        try encodeValInto(list, alloc, entry.val);
    }
}
fn encodeArrInto(list: *std.ArrayList(u8), alloc: std.mem.Allocator, elems: []const Elem) EncodeError!void {
    if (elems.len > 32767) return error.TooLarge;
    try appendByte(list, alloc, Tag.SFSARRAY);
    try appendShort(list, alloc, @intCast(elems.len));
    for (elems) |elem| try encodeElemInto(list, alloc, elem);
}
pub fn encodeObj(alloc: std.mem.Allocator, entries: []const Entry) ![]u8 {
    var list: std.ArrayList(u8) = .empty;
    errdefer list.deinit(alloc);
    try encodeObjInto(&list, alloc, entries);
    return try list.toOwnedSlice(alloc);
}
pub fn encodeFrame(alloc: std.mem.Allocator, body: []const u8) ![]u8 {
    if (body.len > 60000) {
        if (body.len > 0x7fffffff) return error.TooLarge;
        const out = try alloc.alloc(u8, 5 + body.len);
        out[0] = 0x88;
        std.mem.writeInt(i32, out[1..5], @intCast(body.len), .big);
        @memcpy(out[5..], body);
        return out;
    } else {
        const out = try alloc.alloc(u8, 3 + body.len);
        out[0] = 0x80;
        std.mem.writeInt(u16, out[1..3], @intCast(body.len), .big);
        @memcpy(out[3..], body);
        return out;
    }
}
pub fn outerPacket(alloc: std.mem.Allocator, controller: u8, action: i16, params: []const Entry) ![]u8 {
    const entries = [_]Entry{
        .{ .key = "c", .val = .{ .byte = controller } },
        .{ .key = "a", .val = .{ .short = action } },
        .{ .key = "p", .val = .{ .obj = params } },
    };
    const body = try encodeObj(alloc, &entries);
    defer alloc.free(body);
    return try encodeFrame(alloc, body);
}
pub fn nextFrame(buf: []const u8, off: *usize) !?Frame {
    if (off.* >= buf.len) return null;
    if (buf.len - off.* < 3) return null;
    const header = buf[off.*];
    if ((header & 0x80) == 0) return error.BadHeader;
    const big = (header & 0x08) != 0;
    if (big) {
        if (buf.len - off.* < 5) return null;
        const len = std.mem.readInt(i32, buf[off.* + 1 ..][0..4], .big);
        if (len < 0) return error.BadLength;
        const ulen: usize = @intCast(len);
        if (buf.len - off.* - 5 < ulen) return null;
        const body = buf[off.* + 5 .. off.* + 5 + ulen];
        off.* += 5 + ulen;
        return Frame{ .header = header, .body = body };
    } else {
        const len = std.mem.readInt(u16, buf[off.* + 1 ..][0..2], .big);
        if (buf.len - off.* - 3 < len) return null;
        const body = buf[off.* + 3 .. off.* + 3 + len];
        off.* += 3 + len;
        return Frame{ .header = header, .body = body };
    }
}
fn readByteAt(bytes: []const u8, pos: *usize) DecodeError!u8 {
    if (pos.* >= bytes.len) return error.Truncated;
    const byte = bytes[pos.*];
    pos.* += 1;
    return byte;
}
fn readSliceAt(bytes: []const u8, pos: *usize, count: usize) DecodeError![]const u8 {
    if (bytes.len - pos.* < count) return error.Truncated;
    const slice = bytes[pos.* .. pos.* + count];
    pos.* += count;
    return slice;
}
fn readI16At(bytes: []const u8, pos: *usize) DecodeError!i16 {
    const slice = try readSliceAt(bytes, pos, 2);
    return std.mem.readInt(i16, slice[0..2], .big);
}
fn readU16At(bytes: []const u8, pos: *usize) DecodeError!u16 {
    const slice = try readSliceAt(bytes, pos, 2);
    return std.mem.readInt(u16, slice[0..2], .big);
}
fn readI32At(bytes: []const u8, pos: *usize) DecodeError!i32 {
    const slice = try readSliceAt(bytes, pos, 4);
    return std.mem.readInt(i32, slice[0..4], .big);
}
fn readI64At(bytes: []const u8, pos: *usize) DecodeError!i64 {
    const slice = try readSliceAt(bytes, pos, 8);
    return std.mem.readInt(i64, slice[0..8], .big);
}
fn readF32At(bytes: []const u8, pos: *usize) DecodeError!f32 {
    const slice = try readSliceAt(bytes, pos, 4);
    const bits = std.mem.readInt(u32, slice[0..4], .big);
    return @bitCast(bits);
}
fn readF64At(bytes: []const u8, pos: *usize) DecodeError!f64 {
    const slice = try readSliceAt(bytes, pos, 8);
    const bits = std.mem.readInt(u64, slice[0..8], .big);
    return @bitCast(bits);
}
fn readUtfAt(bytes: []const u8, pos: *usize) DecodeError![]const u8 {
    const len = try readU16At(bytes, pos);
    return try readSliceAt(bytes, pos, len);
}
fn readTextAt(bytes: []const u8, pos: *usize) DecodeError![]const u8 {
    const len = try readI32At(bytes, pos);
    if (len < 0) return error.BadLength;
    return try readSliceAt(bytes, pos, @intCast(len));
}
fn decodeElemAt(alloc: std.mem.Allocator, bytes: []const u8, pos: *usize) DecodeError!Elem {
    const tag = try readByteAt(bytes, pos);
    switch (tag) {
        Tag.NULL => return Elem{ .tag = tag, .val = .{ .null = {} } },
        Tag.BOOL => {
            const flag = try readByteAt(bytes, pos);
            return Elem{ .tag = tag, .val = .{ .boolean = flag == 1 } };
        },
        Tag.BYTE => {
            const byte = try readByteAt(bytes, pos);
            return Elem{ .tag = tag, .val = .{ .byte = byte } };
        },
        Tag.SHORT => {
            const num = try readI16At(bytes, pos);
            return Elem{ .tag = tag, .val = .{ .short = num } };
        },
        Tag.INT => {
            const num = try readI32At(bytes, pos);
            return Elem{ .tag = tag, .val = .{ .int = num } };
        },
        Tag.LONG => {
            const num = try readI64At(bytes, pos);
            return Elem{ .tag = tag, .val = .{ .long = num } };
        },
        Tag.FLOAT => {
            const num = try readF32At(bytes, pos);
            return Elem{ .tag = tag, .val = .{ .float = num } };
        },
        Tag.DOUBLE => {
            const num = try readF64At(bytes, pos);
            return Elem{ .tag = tag, .val = .{ .double = num } };
        },
        Tag.UTFSTRING => {
            const str = try readUtfAt(bytes, pos);
            return Elem{ .tag = tag, .val = .{ .str = str } };
        },
        Tag.TEXT => {
            const str = try readTextAt(bytes, pos);
            return Elem{ .tag = tag, .val = .{ .text = str } };
        },
        Tag.BOOLARRAY => {
            const count = try readI16At(bytes, pos);
            if (count < 0) return error.BadLength;
            const arr = try alloc.alloc(bool, @intCast(count));
            var idx: usize = 0;
            while (idx < arr.len) : (idx += 1) {
                const flag = try readByteAt(bytes, pos);
                arr[idx] = flag == 1;
            }
            return Elem{ .tag = tag, .val = .{ .boolArr = arr } };
        },
        Tag.BYTEARRAY => {
            const count = try readI32At(bytes, pos);
            if (count < 0) return error.BadLength;
            const str = try readSliceAt(bytes, pos, @intCast(count));
            return Elem{ .tag = tag, .val = .{ .byteArr = str } };
        },
        Tag.SHORTARRAY => {
            const count = try readI16At(bytes, pos);
            if (count < 0) return error.BadLength;
            const arr = try alloc.alloc(i16, @intCast(count));
            var idx: usize = 0;
            while (idx < arr.len) : (idx += 1) arr[idx] = try readI16At(bytes, pos);
            return Elem{ .tag = tag, .val = .{ .shortArr = arr } };
        },
        Tag.INTARRAY => {
            const count = try readI16At(bytes, pos);
            if (count < 0) return error.BadLength;
            const arr = try alloc.alloc(i32, @intCast(count));
            var idx: usize = 0;
            while (idx < arr.len) : (idx += 1) arr[idx] = try readI32At(bytes, pos);
            return Elem{ .tag = tag, .val = .{ .intArr = arr } };
        },
        Tag.LONGARRAY => {
            const count = try readI16At(bytes, pos);
            if (count < 0) return error.BadLength;
            const arr = try alloc.alloc(i64, @intCast(count));
            var idx: usize = 0;
            while (idx < arr.len) : (idx += 1) arr[idx] = try readI64At(bytes, pos);
            return Elem{ .tag = tag, .val = .{ .longArr = arr } };
        },
        Tag.FLOATARRAY => {
            const count = try readI16At(bytes, pos);
            if (count < 0) return error.BadLength;
            const arr = try alloc.alloc(f32, @intCast(count));
            var idx: usize = 0;
            while (idx < arr.len) : (idx += 1) arr[idx] = try readF32At(bytes, pos);
            return Elem{ .tag = tag, .val = .{ .floatArr = arr } };
        },
        Tag.DOUBLEARRAY => {
            const count = try readI16At(bytes, pos);
            if (count < 0) return error.BadLength;
            const arr = try alloc.alloc(f64, @intCast(count));
            var idx: usize = 0;
            while (idx < arr.len) : (idx += 1) arr[idx] = try readF64At(bytes, pos);
            return Elem{ .tag = tag, .val = .{ .doubleArr = arr } };
        },
        Tag.UTFSTRINGARRAY => {
            const count = try readI16At(bytes, pos);
            if (count < 0) return error.BadLength;
            const arr = try alloc.alloc([]const u8, @intCast(count));
            var idx: usize = 0;
            while (idx < arr.len) : (idx += 1) arr[idx] = try readUtfAt(bytes, pos);
            return Elem{ .tag = tag, .val = .{ .strArr = arr } };
        },
        Tag.SFSARRAY => {
            pos.* -= 1;
            const arr = try decodeArrInner(alloc, bytes, pos);
            return Elem{ .tag = tag, .val = .{ .arr = arr } };
        },
        Tag.SFSOBJECT => {
            pos.* -= 1;
            const obj = try decodeObjInner(alloc, bytes, pos);
            return Elem{ .tag = tag, .val = .{ .obj = obj } };
        },
        else => return error.UnknownType,
    }
}
fn decodeObjInner(alloc: std.mem.Allocator, bytes: []const u8, pos: *usize) DecodeError![]const Entry {
    const mark = try readByteAt(bytes, pos);
    if (mark != Tag.SFSOBJECT) return error.BadMarker;
    const count = try readI16At(bytes, pos);
    if (count < 0) return error.BadLength;
    const entries = try alloc.alloc(Entry, @intCast(count));
    var idx: usize = 0;
    while (idx < entries.len) : (idx += 1) {
        const key = try readUtfAt(bytes, pos);
        const elem = try decodeElemAt(alloc, bytes, pos);
        entries[idx] = Entry{ .key = key, .val = elem.val };
    }
    return entries;
}
fn decodeArrInner(alloc: std.mem.Allocator, bytes: []const u8, pos: *usize) DecodeError![]const Elem {
    const mark = try readByteAt(bytes, pos);
    if (mark != Tag.SFSARRAY) return error.BadMarker;
    const count = try readI16At(bytes, pos);
    if (count < 0) return error.BadLength;
    const elems = try alloc.alloc(Elem, @intCast(count));
    var idx: usize = 0;
    while (idx < elems.len) : (idx += 1) elems[idx] = try decodeElemAt(alloc, bytes, pos);
    return elems;
}
pub fn decodeObj(alloc: std.mem.Allocator, bytes: []const u8) !struct { entries: []const Entry, len: usize } {
    var pos: usize = 0;
    const entries = try decodeObjInner(alloc, bytes, &pos);
    return .{ .entries = entries, .len = pos };
}
pub fn parseOuter(alloc: std.mem.Allocator, body: []const u8) !Outer {
    const dec = try decodeObj(alloc, body);
    var cFound = false;
    var aFound = false;
    var pFound = false;
    var controller: u8 = 0;
    var action: i16 = 0;
    var params: []const Entry = &.{};
    for (dec.entries) |entry| {
        if (std.mem.eql(u8, entry.key, "c")) {
            switch (entry.val) {
                .byte => |num| {
                    controller = num;
                    cFound = true;
                },
                else => return error.BadOuter,
            }
        } else if (std.mem.eql(u8, entry.key, "a")) {
            switch (entry.val) {
                .short => |num| {
                    action = num;
                    aFound = true;
                },
                else => return error.BadOuter,
            }
        } else if (std.mem.eql(u8, entry.key, "p")) {
            switch (entry.val) {
                .obj => |obj| {
                    params = obj;
                    pFound = true;
                },
                else => return error.BadOuter,
            }
        }
    }
    if (!cFound or !aFound or !pFound) return error.BadOuter;
    return Outer{ .controller = controller, .action = action, .params = params };
}
pub fn inflateZlib(alloc: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var inR: std.Io.Reader = .fixed(bytes);
    const window = try alloc.alloc(u8, std.compress.flate.max_window_len);
    defer alloc.free(window);
    var dec: std.compress.flate.Decompress = .init(&inR, .zlib, window);
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(alloc);
    while (dec.reader.peekGreedy(1)) |chunk| {
        try out.appendSlice(alloc, chunk);
        dec.reader.toss(chunk.len);
    } else |err| switch (err) {
        error.ReadFailed => {
            if (dec.err) |fail| return fail;
            return error.DecompressFailed;
        },
        error.EndOfStream => {},
    }
    return try out.toOwnedSlice(alloc);
}
pub fn deflateZlib(alloc: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(alloc);
    errdefer aw.deinit();
    try aw.ensureTotalCapacity(16);
    const window = try alloc.alloc(u8, std.compress.flate.max_window_len * 2);
    defer alloc.free(window);
    var comp = try std.compress.flate.Compress.init(&aw.writer, window, .raw, .default);
    try comp.writer.writeAll(bytes);
    try comp.finish();
    const raw = aw.written();
    const out = try alloc.alloc(u8, 2 + raw.len + 4);
    errdefer alloc.free(out);
    out[0] = 0x78;
    out[1] = 0x9C;
    @memcpy(out[2 .. 2 + raw.len], raw);
    const adler = std.hash.Adler32.hash(bytes);
    std.mem.writeInt(u32, out[2 + raw.len ..][0..4], adler, .big);
    aw.deinit();
    return out;
}
pub fn b64dec(alloc: std.mem.Allocator, str: []const u8) ![]u8 {
    const len = try std.base64.standard.Decoder.calcSizeForSlice(str);
    const out = try alloc.alloc(u8, len);
    errdefer alloc.free(out);
    try std.base64.standard.Decoder.decode(out, str);
    return out;
}
fn hexVal(char: u8) !u8 {
    return switch (char) {
        '0'...'9' => char - '0',
        'a'...'f' => char - 'a' + 10,
        'A'...'F' => char - 'A' + 10,
        else => error.BadHex,
    };
}
fn hexDec(alloc: std.mem.Allocator, hex: []const u8) ![]u8 {
    if (hex.len % 2 != 0) return error.BadHex;
    const out = try alloc.alloc(u8, hex.len / 2);
    errdefer alloc.free(out);
    var idx: usize = 0;
    while (idx < out.len) : (idx += 1) {
        const hi = try hexVal(hex[idx * 2]);
        const lo = try hexVal(hex[idx * 2 + 1]);
        out[idx] = hi * 16 + lo;
    }
    return out;
}
fn findEntry(entries: []const Entry, key: []const u8) ?Val {
    var found: ?Val = null;
    for (entries) |entry| {
        if (std.mem.eql(u8, entry.key, key)) found = entry.val;
    }
    return found;
}
test "handshake outer packet byte exact" {
    const alloc = std.testing.allocator;
    const params = [_]Entry{
        .{ .key = "tk", .val = .{ .str = "emu-token-1" } },
        .{ .key = "ct", .val = .{ .int = 1024 } },
        .{ .key = "ms", .val = .{ .int = 500000 } },
    };
    const pkt = try outerPacket(alloc, 0, 0, &params);
    defer alloc.free(pkt);
    const expHex = "80003812000300016302000001610300000001701200030002746b08000b656d752d746f6b656e2d3100026374040000040000026d73040007a120";
    const exp = try hexDec(alloc, expHex);
    defer alloc.free(exp);
    try std.testing.expectEqualSlices(u8, exp, pkt);
    var off: usize = 0;
    const fr = (try nextFrame(pkt, &off)).?;
    try std.testing.expectEqual(@as(u8, 0x80), fr.header);
    try std.testing.expectEqual(pkt.len - 3, fr.body.len);
    try std.testing.expectEqual(pkt.len, off);
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const outer = try parseOuter(arena.allocator(), fr.body);
    try std.testing.expectEqual(@as(u8, 0), outer.controller);
    try std.testing.expectEqual(@as(i16, 0), outer.action);
    try std.testing.expectEqual(@as(usize, 3), outer.params.len);
    const tk = findEntry(outer.params, "tk").?;
    try std.testing.expectEqualStrings("emu-token-1", tk.str);
    const ct = findEntry(outer.params, "ct").?;
    try std.testing.expectEqual(@as(i32, 1024), ct.int);
    const ms = findEntry(outer.params, "ms").?;
    try std.testing.expectEqual(@as(i32, 500000), ms.int);
}
test "login and platform outer packets byte exact" {
    const alloc = std.testing.allocator;
    const loginParams = [_]Entry{
        .{ .key = "id", .val = .{ .int = 1 } },
        .{ .key = "un", .val = .{ .str = "EmuHero" } },
        .{ .key = "zn", .val = .{ .str = "PixelQuest" } },
    };
    const loginPkt = try outerPacket(alloc, 0, 1, &loginParams);
    defer alloc.free(loginPkt);
    const loginExpHex = "80003c12000300016302000001610300010001701200030002696404000000010002756e080007456d754865726f00027a6e08000a506978656c5175657374";
    const loginExp = try hexDec(alloc, loginExpHex);
    defer alloc.free(loginExp);
    try std.testing.expectEqualSlices(u8, loginExp, loginPkt);
    const inner = [_]Entry{
        .{ .key = "dal0", .val = .{ .int = 21 } },
        .{ .key = "act0", .val = .{ .int = 1 } },
    };
    const platParams = [_]Entry{
        .{ .key = "c", .val = .{ .str = "ServerExtension" } },
        .{ .key = "p", .val = .{ .obj = &inner } },
    };
    const platPkt = try outerPacket(alloc, 1, 13, &platParams);
    defer alloc.free(platPkt);
    const platExpHex = "800045120003000163020100016103000d00017012000200016308000f536572766572457874656e73696f6e000170120002000464616c3004000000150004616374300400000001";
    const platExp = try hexDec(alloc, platExpHex);
    defer alloc.free(platExp);
    try std.testing.expectEqualSlices(u8, platExp, platPkt);
    var off: usize = 0;
    const fr = (try nextFrame(platPkt, &off)).?;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const outer = try parseOuter(arena.allocator(), fr.body);
    try std.testing.expectEqual(@as(u8, 1), outer.controller);
    try std.testing.expectEqual(@as(i16, 13), outer.action);
}
test "frame boundaries 0x80 and 0x88" {
    const alloc = std.testing.allocator;
    const empty = try encodeFrame(alloc, &.{});
    defer alloc.free(empty);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x80, 0x00, 0x00 }, empty);
    const b5 = [_]u8{ 0xAB, 0xAB, 0xAB, 0xAB, 0xAB };
    const f5 = try encodeFrame(alloc, &b5);
    defer alloc.free(f5);
    try std.testing.expectEqual(@as(usize, 8), f5.len);
    try std.testing.expectEqual(@as(u8, 0x80), f5[0]);
    try std.testing.expectEqual(@as(u8, 0x00), f5[1]);
    try std.testing.expectEqual(@as(u8, 0x05), f5[2]);
    const body60k = try alloc.alloc(u8, 60000);
    defer alloc.free(body60k);
    @memset(body60k, 0xAB);
    const f60k = try encodeFrame(alloc, body60k);
    defer alloc.free(f60k);
    try std.testing.expectEqual(@as(usize, 60003), f60k.len);
    try std.testing.expectEqual(@as(u8, 0x80), f60k[0]);
    try std.testing.expectEqual(@as(u8, 0xEA), f60k[1]);
    try std.testing.expectEqual(@as(u8, 0x60), f60k[2]);
    const body60001 = try alloc.alloc(u8, 60001);
    defer alloc.free(body60001);
    @memset(body60001, 0xAB);
    const f60001 = try encodeFrame(alloc, body60001);
    defer alloc.free(f60001);
    try std.testing.expectEqual(@as(usize, 60006), f60001.len);
    try std.testing.expectEqual(@as(u8, 0x88), f60001[0]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x00, 0xEA, 0x61 }, f60001[1..5]);
    var off: usize = 0;
    const fr1 = (try nextFrame(f60k, &off)).?;
    try std.testing.expectEqual(@as(u8, 0x80), fr1.header);
    try std.testing.expectEqual(@as(usize, 60000), fr1.body.len);
    try std.testing.expectEqual(f60k.len, off);
    off = 0;
    const fr2 = (try nextFrame(f60001, &off)).?;
    try std.testing.expectEqual(@as(u8, 0x88), fr2.header);
    try std.testing.expectEqual(@as(usize, 60001), fr2.body.len);
    try std.testing.expectEqual(f60001.len, off);
    const smallHex = "80000b1200010001610400000007";
    const smallFr = try hexDec(alloc, smallHex);
    defer alloc.free(smallFr);
    off = 0;
    const fr3 = (try nextFrame(smallFr, &off)).?;
    try std.testing.expectEqual(@as(u8, 0x80), fr3.header);
    const smallBodyHex = "1200010001610400000007";
    const smallBody = try hexDec(alloc, smallBodyHex);
    defer alloc.free(smallBody);
    try std.testing.expectEqualSlices(u8, smallBody, fr3.body);
}
test "nextFrame incomplete and bad header" {
    const alloc = std.testing.allocator;
    var off: usize = 0;
    const empty: []const u8 = &.{};
    try std.testing.expectEqual(@as(?Frame, null), try nextFrame(empty, &off));
    try std.testing.expectEqual(@as(usize, 0), off);
    const short: []const u8 = &[_]u8{ 0x80, 0x00 };
    off = 0;
    try std.testing.expectEqual(@as(?Frame, null), try nextFrame(short, &off));
    try std.testing.expectEqual(@as(usize, 0), off);
    const hdr = [_]u8{ 0x80, 0x00, 0x05, 0x01, 0x02 };
    off = 0;
    const r1 = try nextFrame(&hdr, &off);
    try std.testing.expectEqual(@as(?Frame, null), r1);
    try std.testing.expectEqual(@as(usize, 0), off);
    const bad = [_]u8{ 0x00, 0x00, 0x05 };
    off = 0;
    try std.testing.expectError(error.BadHeader, nextFrame(&bad, &off));
    const bigShort = [_]u8{ 0x88, 0x00, 0x00 };
    off = 0;
    try std.testing.expectEqual(@as(?Frame, null), try nextFrame(&bigShort, &off));
    const body = [_]u8{ 1, 2, 3, 4, 5 };
    const first = try encodeFrame(alloc, &body);
    defer alloc.free(first);
    const f2 = try encodeFrame(alloc, &body);
    defer alloc.free(f2);
    var both: std.ArrayList(u8) = .empty;
    defer both.deinit(alloc);
    try both.appendSlice(alloc, first);
    try both.appendSlice(alloc, f2);
    off = 0;
    const p1 = (try nextFrame(both.items, &off)).?;
    try std.testing.expectEqualSlices(u8, &body, p1.body);
    const p2 = (try nextFrame(both.items, &off)).?;
    try std.testing.expectEqualSlices(u8, &body, p2.body);
    try std.testing.expectEqual(both.items.len, off);
    try std.testing.expectEqual(@as(?Frame, null), try nextFrame(both.items, &off));
}
test "all types encode byte exact and decode roundtrip" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const aa = arena.allocator();
    const boolArr = [_]bool{ true, false, true };
    const byteArr = [_]u8{ 0, 1, 2, 255 };
    const shortArr = [_]i16{ -1, 0, 300 };
    const intArr = [_]i32{ 0, -1, 2147483647 };
    const longArr = [_]i64{ 0, 5, -5 };
    const floatArr = [_]f32{ 1.5, -2.25 };
    const doubleArr = [_]f64{ 0.1, -0.2 };
    const strArr = [_][]const u8{ "a", "", "bc" };
    const arrElems = [_]Elem{
        .{ .tag = Tag.INT, .val = .{ .int = 1 } },
        .{ .tag = Tag.UTFSTRING, .val = .{ .str = "x" } },
        .{ .tag = Tag.NULL, .val = .{ .null = {} } },
    };
    const objEntries = [_]Entry{
        .{ .key = "nested", .val = .{ .int = 42 } },
        .{ .key = "s", .val = .{ .str = "n" } },
    };
    const entries = [_]Entry{
        .{ .key = "f_null", .val = .{ .null = {} } },
        .{ .key = "f_bool_t", .val = .{ .boolean = true } },
        .{ .key = "f_bool_f", .val = .{ .boolean = false } },
        .{ .key = "f_byte", .val = .{ .byte = 200 } },
        .{ .key = "f_short_neg", .val = .{ .short = -1234 } },
        .{ .key = "f_short_max", .val = .{ .short = 32767 } },
        .{ .key = "f_int_neg", .val = .{ .int = -123456 } },
        .{ .key = "f_int_min", .val = .{ .int = -2147483648 } },
        .{ .key = "f_long", .val = .{ .long = 1234567890123 } },
        .{ .key = "f_long_neg", .val = .{ .long = -987654321098 } },
        .{ .key = "f_float", .val = .{ .float = 1.5 } },
        .{ .key = "f_double", .val = .{ .double = -123.456 } },
        .{ .key = "f_str", .val = .{ .str = "hello" } },
        .{ .key = "f_str_uni", .val = .{ .str = "привет ☃" } },
        .{ .key = "f_str_empty", .val = .{ .str = "" } },
        .{ .key = "f_text", .val = .{ .text = "big text body" } },
        .{ .key = "f_bool_arr", .val = .{ .boolArr = &boolArr } },
        .{ .key = "f_bool_arr_empty", .val = .{ .boolArr = &.{} } },
        .{ .key = "f_byte_arr", .val = .{ .byteArr = &byteArr } },
        .{ .key = "f_byte_arr_empty", .val = .{ .byteArr = &.{} } },
        .{ .key = "f_short_arr", .val = .{ .shortArr = &shortArr } },
        .{ .key = "f_int_arr", .val = .{ .intArr = &intArr } },
        .{ .key = "f_long_arr", .val = .{ .longArr = &longArr } },
        .{ .key = "f_float_arr", .val = .{ .floatArr = &floatArr } },
        .{ .key = "f_double_arr", .val = .{ .doubleArr = &doubleArr } },
        .{ .key = "f_str_arr", .val = .{ .strArr = &strArr } },
        .{ .key = "f_str_arr_empty", .val = .{ .strArr = &.{} } },
        .{ .key = "f_arr", .val = .{ .arr = &arrElems } },
        .{ .key = "f_arr_empty", .val = .{ .arr = &.{} } },
        .{ .key = "f_obj", .val = .{ .obj = &objEntries } },
        .{ .key = "f_obj_empty", .val = .{ .obj = &.{} } },
    };
    const enc = try encodeObj(aa, &entries);
    const expHex = "12001f0006665f6e756c6c000008665f626f6f6c5f7401010008665f626f6f6c5f6601000006665f6279746502c8000b665f73686f72745f6e656703fb2e000b665f73686f72745f6d6178037fff0009665f696e745f6e656704fffe1dc00009665f696e745f6d696e04800000000006665f6c6f6e67050000011f71fb04cb000a665f6c6f6e675f6e656705ffffff1a0b370c360007665f666c6f6174063fc000000008665f646f75626c6507c05edd2f1a9fbe770005665f73747208000568656c6c6f0009665f7374725f756e69080010d0bfd180d0b8d0b2d0b5d18220e29883000b665f7374725f656d7074790800000006665f74657874140000000d626967207465787420626f6479000a665f626f6f6c5f6172720900030100010010665f626f6f6c5f6172725f656d707479090000000a665f627974655f6172720a00000004000102ff0010665f627974655f6172725f656d7074790a00000000000b665f73686f72745f6172720b0003ffff0000012c0009665f696e745f6172720c000300000000ffffffff7fffffff000a665f6c6f6e675f6172720d000300000000000000000000000000000005fffffffffffffffb000b665f666c6f61745f6172720e00023fc00000c0100000000c665f646f75626c655f6172720f00023fb999999999999abfc999999999999a0009665f7374725f617272100003000161000000026263000f665f7374725f6172725f656d7074791000000005665f61727211000304000000010800017800000b665f6172725f656d7074791100000005665f6f626a12000200066e6573746564040000002a0001730800016e000b665f6f626a5f656d707479120000";
    const exp = try hexDec(aa, expHex);
    try std.testing.expectEqualSlices(u8, exp, enc);
    const dec = try decodeObj(aa, enc);
    try std.testing.expectEqual(enc.len, dec.len);
    try std.testing.expectEqual(@as(usize, 31), dec.entries.len);
    try std.testing.expectEqualStrings("f_null", dec.entries[0].key);
    try std.testing.expect(dec.entries[0].val == .null);
    try std.testing.expectEqual(true, dec.entries[1].val.boolean);
    try std.testing.expectEqual(false, dec.entries[2].val.boolean);
    try std.testing.expectEqual(@as(u8, 200), dec.entries[3].val.byte);
    try std.testing.expectEqual(@as(i16, -1234), dec.entries[4].val.short);
    try std.testing.expectEqual(@as(i16, 32767), dec.entries[5].val.short);
    try std.testing.expectEqual(@as(i32, -123456), dec.entries[6].val.int);
    try std.testing.expectEqual(@as(i32, -2147483648), dec.entries[7].val.int);
    try std.testing.expectEqual(@as(i64, 1234567890123), dec.entries[8].val.long);
    try std.testing.expectEqual(@as(i64, -987654321098), dec.entries[9].val.long);
    try std.testing.expectEqual(@as(u32, @bitCast(@as(f32, 1.5))), @as(u32, @bitCast(dec.entries[10].val.float)));
    try std.testing.expectEqual(@as(u64, @bitCast(@as(f64, -123.456))), @as(u64, @bitCast(dec.entries[11].val.double)));
    try std.testing.expectEqualStrings("hello", dec.entries[12].val.str);
    try std.testing.expectEqualStrings("привет ☃", dec.entries[13].val.str);
    try std.testing.expectEqualStrings("", dec.entries[14].val.str);
    try std.testing.expectEqualStrings("big text body", dec.entries[15].val.text);
    try std.testing.expectEqualSlices(bool, &boolArr, dec.entries[16].val.boolArr);
    try std.testing.expectEqual(@as(usize, 0), dec.entries[17].val.boolArr.len);
    try std.testing.expectEqualSlices(u8, &byteArr, dec.entries[18].val.byteArr);
    try std.testing.expectEqual(@as(usize, 0), dec.entries[19].val.byteArr.len);
    try std.testing.expectEqualSlices(i16, &shortArr, dec.entries[20].val.shortArr);
    try std.testing.expectEqualSlices(i32, &intArr, dec.entries[21].val.intArr);
    try std.testing.expectEqualSlices(i64, &longArr, dec.entries[22].val.longArr);
    {
        const got = dec.entries[23].val.floatArr;
        try std.testing.expectEqual(@as(usize, 2), got.len);
        try std.testing.expectEqual(@as(u32, @bitCast(floatArr[0])), @as(u32, @bitCast(got[0])));
        try std.testing.expectEqual(@as(u32, @bitCast(floatArr[1])), @as(u32, @bitCast(got[1])));
    }
    {
        const got = dec.entries[24].val.doubleArr;
        try std.testing.expectEqual(@as(usize, 2), got.len);
        try std.testing.expectEqual(@as(u64, @bitCast(doubleArr[0])), @as(u64, @bitCast(got[0])));
        try std.testing.expectEqual(@as(u64, @bitCast(doubleArr[1])), @as(u64, @bitCast(got[1])));
    }
    {
        const got = dec.entries[25].val.strArr;
        try std.testing.expectEqual(@as(usize, 3), got.len);
        try std.testing.expectEqualStrings("a", got[0]);
        try std.testing.expectEqualStrings("", got[1]);
        try std.testing.expectEqualStrings("bc", got[2]);
    }
    try std.testing.expectEqual(@as(usize, 0), dec.entries[26].val.strArr.len);
    {
        const got = dec.entries[27].val.arr;
        try std.testing.expectEqual(@as(usize, 3), got.len);
        try std.testing.expectEqual(@as(u8, Tag.INT), got[0].tag);
        try std.testing.expectEqual(@as(i32, 1), got[0].val.int);
        try std.testing.expectEqual(@as(u8, Tag.UTFSTRING), got[1].tag);
        try std.testing.expectEqualStrings("x", got[1].val.str);
        try std.testing.expectEqual(@as(u8, Tag.NULL), got[2].tag);
    }
    try std.testing.expectEqual(@as(usize, 0), dec.entries[28].val.arr.len);
    {
        const got = dec.entries[29].val.obj;
        try std.testing.expectEqual(@as(usize, 2), got.len);
        try std.testing.expectEqualStrings("nested", got[0].key);
        try std.testing.expectEqual(@as(i32, 42), got[0].val.int);
        try std.testing.expectEqualStrings("s", got[1].key);
        try std.testing.expectEqualStrings("n", got[1].val.str);
    }
    try std.testing.expectEqual(@as(usize, 0), dec.entries[30].val.obj.len);
    const re = try encodeObj(aa, dec.entries);
    try std.testing.expectEqualSlices(u8, enc, re);
}
test "nested array byte exact" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const aa = arena.allocator();
    const innerObj = [_]Entry{.{ .key = "a", .val = .{ .int = 1 } }};
    const innerArr = [_]Elem{.{ .tag = Tag.BOOL, .val = .{ .boolean = true } }};
    const elems = [_]Elem{
        .{ .tag = Tag.SFSOBJECT, .val = .{ .obj = &innerObj } },
        .{ .tag = Tag.SFSARRAY, .val = .{ .arr = &innerArr } },
    };
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(aa);
    try encodeArrInto(&list, aa, &elems);
    const exp = try hexDec(aa, "11000212000100016104000000011100010101");
    try std.testing.expectEqualSlices(u8, exp, list.items);
    var pos: usize = 0;
    const got = try decodeArrInner(aa, list.items, &pos);
    try std.testing.expectEqual(list.items.len, pos);
    try std.testing.expectEqual(@as(usize, 2), got.len);
}
test "unknown type and bad marker errors" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const aa = arena.allocator();
    const bad = [_]u8{ Tag.SFSOBJECT, 0x00, 0x01, 0x00, 0x01, 0x6B, 19, 0x00 };
    try std.testing.expectError(error.UnknownType, decodeObj(aa, &bad));
    const badm = [_]u8{ 0x00, 0x00, 0x00 };
    try std.testing.expectError(error.BadMarker, decodeObj(aa, &badm));
    const trunc = [_]u8{ Tag.SFSOBJECT, 0x00 };
    try std.testing.expectError(error.Truncated, decodeObj(aa, &trunc));
    const elem = Elem{ .tag = Tag.INT, .val = .{ .str = "x" } };
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(aa);
    try std.testing.expectError(error.TypeMismatch, encodeElemInto(&list, aa, elem));
}
test "inflate node zlib blob" {
    const alloc = std.testing.allocator;
    const origB64 = "VGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4gVGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4gVGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4gVGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4gVGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4gVGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4gVGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4gVGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4gVGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4gVGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4gVGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4gVGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4gVGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4gVGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4gVGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4gVGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4gVGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4gVGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4gVGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4gVGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4g0L/RgNC40LLQtdGC";
    const compB64 = "eJwLyUhVKCzNTM5WSCrKL89TSMuvUMgqzS0oVsgvSy1SKMlIVchJrKpUSMlP11MIGVU8GhqjaSOJyjnlwv6LDRd2XNh0YevFJgCnJkve";
    const orig = try b64dec(alloc, origB64);
    defer alloc.free(orig);
    const comp = try b64dec(alloc, compB64);
    defer alloc.free(comp);
    try std.testing.expectEqual(@as(u8, 0x78), comp[0]);
    try std.testing.expectEqual(@as(u8, 0x9C), comp[1]);
    const inflated = try inflateZlib(alloc, comp);
    defer alloc.free(inflated);
    try std.testing.expectEqualSlices(u8, orig, inflated);
    const smallComp = try b64dec(alloc, "eJzLyAQAATsA0g==");
    defer alloc.free(smallComp);
    const smallInflated = try inflateZlib(alloc, smallComp);
    defer alloc.free(smallInflated);
    try std.testing.expectEqualSlices(u8, "hi", smallInflated);
    const emptyComp = try b64dec(alloc, "eJwDAAAAAAE=");
    defer alloc.free(emptyComp);
    const emptyInflated = try inflateZlib(alloc, emptyComp);
    defer alloc.free(emptyInflated);
    try std.testing.expectEqual(@as(usize, 0), emptyInflated.len);
}
test "deflate roundtrip and zlib header" {
    const alloc = std.testing.allocator;
    const msg = "The quick brown fox jumps over the lazy dog. The quick brown fox.";
    const comp = try deflateZlib(alloc, msg);
    defer alloc.free(comp);
    try std.testing.expect(comp.len > 2);
    try std.testing.expectEqual(@as(u8, 0x78), comp[0]);
    try std.testing.expectEqual(@as(u8, 0x9C), comp[1]);
    const back = try inflateZlib(alloc, comp);
    defer alloc.free(back);
    try std.testing.expectEqualSlices(u8, msg, back);
    const emptyComp = try deflateZlib(alloc, "");
    defer alloc.free(emptyComp);
    try std.testing.expectEqual(@as(u8, 0x78), emptyComp[0]);
    try std.testing.expectEqual(@as(u8, 0x9C), emptyComp[1]);
    const emptyBack = try inflateZlib(alloc, emptyComp);
    defer alloc.free(emptyBack);
    try std.testing.expectEqual(@as(usize, 0), emptyBack.len);
    const uni = "привет ☃ hello";
    const ucomp = try deflateZlib(alloc, uni);
    defer alloc.free(ucomp);
    const uback = try inflateZlib(alloc, ucomp);
    defer alloc.free(uback);
    try std.testing.expectEqualSlices(u8, uni, uback);
}
test "b64dec vectors" {
    const alloc = std.testing.allocator;
    const hello = try b64dec(alloc, "aGVsbG8=");
    defer alloc.free(hello);
    try std.testing.expectEqualSlices(u8, "hello", hello);
    const empty = try b64dec(alloc, "");
    defer alloc.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);
}
