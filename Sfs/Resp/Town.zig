const std = @import("std");
const Codec = @import("../Codec.zig");
const Replay = @import("../Replay.zig");
const System = @import("System.zig");

const entries = [_]Codec.Entry{
    .{ .key = "dal0", .val = Codec.Val{ .int = 21 } },
    .{ .key = "act0", .val = Codec.Val{ .int = 1 } },
    .{ .key = "use3", .val = Codec.Val{ .str = "penis" } },
    .{ .key = "pla3", .val = Codec.Val{ .int = 1001 } },
    .{ .key = "pla13", .val = Codec.Val{ .boolean = false } },
    .{ .key = "cha1", .val = Codec.Val{ .int = 2001 } },
    .{ .key = "cha2", .val = Codec.Val{ .str = "Emu" } },
    .{ .key = "cha12", .val = Codec.Val{ .str = "M" } },
    .{ .key = "cha20", .val = Codec.Val{ .int = 1 } },
    .{ .key = "cha21", .val = Codec.Val{ .int = 1 } },
    .{ .key = "cha22", .val = Codec.Val{ .int = 1 } },
    .{ .key = "cha109", .val = Codec.Val{ .str = "" } },
    .{ .key = "cha4", .val = Codec.Val{ .int = 1 } },
    .{ .key = "cha5", .val = Codec.Val{ .long = 0 } },
    .{ .key = "chal9", .val = Codec.Val{ .long = 0 } },
    .{ .key = "chal10", .val = Codec.Val{ .long = 0 } },
    .{ .key = "cha19", .val = Codec.Val{ .int = 0 } },
    .{ .key = "cha6", .val = Codec.Val{ .int = 1 } },
    .{ .key = "cha7", .val = Codec.Val{ .int = 1 } },
    .{ .key = "cha8", .val = Codec.Val{ .int = 1 } },
    .{ .key = "cha24", .val = Codec.Val{ .int = 1 } },
    .{ .key = "cha94", .val = Codec.Val{ .int = 0 } },
    .{ .key = "cha25", .val = Codec.Val{ .int = 0 } },
    .{ .key = "cha26", .val = Codec.Val{ .str = "2026-10-10 12:00:00" } },
    .{ .key = "cha96", .val = Codec.Val{ .str = "2026-10-10 12:00:00" } },
    .{ .key = "cha41", .val = Codec.Val{ .int = 0 } },
    .{ .key = "cha42", .val = Codec.Val{ .long = 0 } },
    .{ .key = "cha65", .val = Codec.Val{ .long = 0 } },
    .{ .key = "cha15", .val = Codec.Val{ .boolean = false } },
    .{ .key = "cha34", .val = Codec.Val{ .boolean = false } },
    .{ .key = "cha32", .val = Codec.Val{ .boolean = false } },
    .{ .key = "cha35", .val = Codec.Val{ .boolean = true } },
    .{ .key = "cha36", .val = Codec.Val{ .int = 0 } },
    .{ .key = "cha40", .val = Codec.Val{ .boolean = true } },
    .{ .key = "cha82", .val = Codec.Val{ .boolean = true } },
    .{ .key = "cha48", .val = Codec.Val{ .boolean = true } },
    .{ .key = "cha93", .val = Codec.Val{ .boolean = true } },
    .{ .key = "cha133", .val = Codec.Val{ .boolean = true } },
    .{ .key = "cha134", .val = Codec.Val{ .boolean = true } },
    .{ .key = "cha91", .val = Codec.Val{ .long = 0 } },
    .{ .key = "cha27", .val = Codec.Val{ .int = 100 } },
    .{ .key = "cha28", .val = Codec.Val{ .long = 0 } },
    .{ .key = "cha97", .val = Codec.Val{ .long = 0 } },
    .{ .key = "cha29", .val = Codec.Val{ .int = 10 } },
    .{ .key = "cha30", .val = Codec.Val{ .long = 0 } },
    .{ .key = "cha98", .val = Codec.Val{ .long = 0 } },
    .{ .key = "cha67", .val = Codec.Val{ .int = 0 } },
    .{ .key = "cha68", .val = Codec.Val{ .long = 0 } },
    .{ .key = "cha101", .val = Codec.Val{ .long = 0 } },
    .{ .key = "cha74", .val = Codec.Val{ .intArr = &.{} } },
    .{ .key = "cha143", .val = Codec.Val{ .arr = &.{} } },
    .{ .key = "pvp1", .val = Codec.Val{ .int = 0 } },
    .{ .key = "rif1", .val = Codec.Val{ .int = 0 } },
    .{ .key = "gau1", .val = Codec.Val{ .int = 0 } },
    .{ .key = "gvg1", .val = Codec.Val{ .int = 0 } },
    .{ .key = "inv1", .val = Codec.Val{ .int = 0 } },
    .{ .key = "fise1", .val = Codec.Val{ .int = 0 } },
    .{ .key = "gve1", .val = Codec.Val{ .int = 0 } },
};

fn craftedChar() Codec.Val {
    return Codec.Val{ .obj = &entries };
}

pub fn platform(alloc: std.mem.Allocator, cap: ?Codec.Val) ![]u8 {
    const inner = if (cap) |found| found else craftedChar();
    var params = [_]Codec.Entry{
        .{ .key = "c", .val = Codec.Val{ .str = "ServerExtension" } },
        .{ .key = "p", .val = inner },
    };
    return Codec.outerPacket(alloc, 1, 13, &params);
}

pub fn ack(alloc: std.mem.Allocator, dal: i32, act: i32, books: ?[]const Replay.Book, nowMs: i64) ![]u8 {
    var extra = [_]Codec.Entry{
        .{ .key = "", .val = Codec.Val.null },
        .{ .key = "", .val = Codec.Val.null },
        .{ .key = "", .val = Codec.Val.null },
    };
    var extraLen: usize = 0;
    var itemsHolder: []Codec.Elem = &.{};
    if (dal == 1 and act == 70) {
        extra[0] = Codec.Entry{ .key = "booster02", .val = Codec.Val{ .arr = &.{} } };
        extra[1] = Codec.Entry{ .key = "booster05", .val = Codec.Val{ .arr = &.{} } };
        extraLen = 2;
    } else if (dal == 0 and act == 7) {
        extra[0] = Codec.Entry{ .key = "cha45", .val = Codec.Val{ .intArr = &.{} } };
        extraLen = 1;
    } else if (dal == 1 and act == 8) {
        extra[0] = Codec.Entry{ .key = "cha41", .val = Codec.Val{ .int = 1 } };
        extra[1] = Codec.Entry{ .key = "cha42", .val = Codec.Val{ .long = nowMs + 24 * 3600 * 1000 } };
        extraLen = 2;
    } else if (dal == 4 and act == 5) {
        if (books) |list| {
            const items = try alloc.alloc(Codec.Elem, list.len);
            itemsHolder = items;
            var idx: usize = 0;
            while (idx < list.len) : (idx += 1) {
                const raw = try Codec.b64dec(alloc, list[idx].b64);
                const xentries = try alloc.alloc(Codec.Entry, 2);
                xentries[0] = Codec.Entry{ .key = "xml1", .val = Codec.Val{ .str = list[idx].name } };
                xentries[1] = Codec.Entry{ .key = "xml2", .val = Codec.Val{ .byteArr = raw } };
                items[idx] = Codec.Elem{ .tag = Codec.Tag.SFSOBJECT, .val = Codec.Val{ .obj = xentries } };
            }
        } else {
            const items = try alloc.alloc(Codec.Elem, 2);
            itemsHolder = items;
            const zb = try Codec.deflateZlib(alloc, "<data><zones><zone xml=\"Zone_1.xml\" /></zones></data>");
            var e0 = [_]Codec.Entry{
                .{ .key = "xml1", .val = Codec.Val{ .str = "ZoneBook.xml" } },
                .{ .key = "xml2", .val = Codec.Val{ .byteArr = zb } },
            };
            items[0] = Codec.Elem{ .tag = Codec.Tag.SFSOBJECT, .val = Codec.Val{ .obj = &e0 } };
            const z1 = try Codec.deflateZlib(alloc, "<data><zone asset=\"emu\" /></data>");
            var e1 = [_]Codec.Entry{
                .{ .key = "xml1", .val = Codec.Val{ .str = "Zone_1.xml" } },
                .{ .key = "xml2", .val = Codec.Val{ .byteArr = z1 } },
            };
            items[1] = Codec.Elem{ .tag = Codec.Tag.SFSOBJECT, .val = Codec.Val{ .obj = &e1 } };
        }
        extra[0] = Codec.Entry{ .key = "xml0", .val = Codec.Val{ .arr = itemsHolder } };
        extraLen = 1;
    }
    var innerBuf = [_]Codec.Entry{
        .{ .key = "dal0", .val = Codec.Val{ .int = dal } },
        .{ .key = "act0", .val = Codec.Val{ .int = act } },
        .{ .key = "", .val = Codec.Val.null },
        .{ .key = "", .val = Codec.Val.null },
        .{ .key = "", .val = Codec.Val.null },
    };
    @memcpy(innerBuf[2 .. 2 + extraLen], extra[0..extraLen]);
    const inner = innerBuf[0 .. 2 + extraLen];
    var params = [_]Codec.Entry{
        .{ .key = "c", .val = Codec.Val{ .str = "ServerExtension" } },
        .{ .key = "p", .val = Codec.Val{ .obj = inner } },
    };
    return Codec.outerPacket(alloc, 1, 13, &params);
}

pub fn instanceEcho(alloc: std.mem.Allocator, room: i32, act: i32, selfId: i32, dest: i32, spd: f32) ![]u8 {
    var inner = [_]Codec.Entry{
        .{ .key = "roo1", .val = Codec.Val{ .int = room } },
        .{ .key = "roo3", .val = Codec.Val{ .int = 0 } },
        .{ .key = "act0", .val = Codec.Val{ .int = act } },
        .{ .key = "cha1", .val = Codec.Val{ .int = selfId } },
        .{ .key = "ins2", .val = Codec.Val{ .int = dest } },
        .{ .key = "ins3", .val = Codec.Val{ .float = spd } },
    };
    var params = [_]Codec.Entry{
        .{ .key = "c", .val = Codec.Val{ .str = "InstanceExtension" } },
        .{ .key = "p", .val = Codec.Val{ .obj = &inner } },
    };
    return Codec.outerPacket(alloc, 1, 13, &params);
}

pub fn enterPush(alloc: std.mem.Allocator, enter: Codec.Val) ![]u8 {
    var params = [_]Codec.Entry{
        .{ .key = "c", .val = Codec.Val{ .str = "ServerExtension" } },
        .{ .key = "p", .val = enter },
    };
    return Codec.outerPacket(alloc, 1, 13, &params);
}
