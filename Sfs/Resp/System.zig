const std = @import("std");
const Codec = @import("../Codec.zig");

pub fn handshake(alloc: std.mem.Allocator) ![]u8 {
    var params = [_]Codec.Entry{
        .{ .key = "tk", .val = Codec.Val{ .str = "fmznk.dev" } },
        .{ .key = "ct", .val = Codec.Val{ .int = 1024 } },
        .{ .key = "ms", .val = Codec.Val{ .int = 500000 } },
    };
    return Codec.outerPacket(alloc, 0, 0, &params);
}

pub fn login(alloc: std.mem.Allocator, cap: ?Codec.Val) ![]u8 {
    if (cap) |found| {
        if (found == .obj) {
            return Codec.outerPacket(alloc, 0, 1, found.obj);
        }
    }
    var pEntries = [_]Codec.Entry{
        .{ .key = "serv1", .val = Codec.Val{ .str = "1" } },
        .{ .key = "serv0", .val = Codec.Val{ .str = "2026-10-10 12:00:00" } },
    };
    var params = [_]Codec.Entry{
        .{ .key = "id", .val = Codec.Val{ .int = 1 } },
        .{ .key = "un", .val = Codec.Val{ .str = "Hero" } },
        .{ .key = "pi", .val = Codec.Val{ .short = 0 } },
        .{ .key = "rs", .val = Codec.Val{ .short = 0 } },
        .{ .key = "zn", .val = Codec.Val{ .str = "PixelQuest" } },
        .{ .key = "rl", .val = Codec.Val{ .arr = &.{} } },
        .{ .key = "p", .val = Codec.Val{ .obj = &pEntries } },
    };
    return Codec.outerPacket(alloc, 0, 1, &params);
}
