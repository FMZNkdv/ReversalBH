const std = @import("std");
const Io = std.Io;
const heap = std.heap.page_allocator;
const Codec = @import("../Sfs/Codec.zig");
const Replay = @import("../Sfs/Replay.zig");
const System = @import("../Sfs/Resp/System.zig");
const Town = @import("../Sfs/Resp/Town.zig");
const Http = @import("Http.zig");
const log = std.debug.print;

fn entryVal(entries: []const Codec.Entry, key: []const u8) ?Codec.Val {
    for (entries) |entry| {
        if (std.mem.eql(u8, entry.key, key)) return entry.val;
    }
    return null;
}

fn asI32(val: ?Codec.Val, dflt: i32) i32 {
    const cur = val orelse return dflt;
    return switch (cur) {
        .int => |num| num,
        .byte => |num| @as(i32, num),
        .short => |num| @as(i32, num),
        .long => |num| @intCast(num),
        .float => |num| @intFromFloat(num),
        .double => |num| @intFromFloat(num),
        else => dflt,
    };
}

fn asF32(val: ?Codec.Val, dflt: f32) f32 {
    const cur = val orelse return dflt;
    return switch (cur) {
        .float => |num| num,
        .double => |num| @floatCast(num),
        .int => |num| @floatFromInt(num),
        .long => |num| @floatFromInt(num),
        else => dflt,
    };
}

fn asStr(val: ?Codec.Val) []const u8 {
    const cur = val orelse return "";
    return switch (cur) {
        .str => |txt| txt,
        .text => |txt| txt,
        else => "",
    };
}

fn selfId(cap: *const Replay.Cap) i32 {
    const found = cap.char orelse return 0;
    if (found != .obj) return 0;
    return asI32(entryVal(found.obj, "cha1"), 0);
}

fn peer(stream: Io.net.Stream, buf: *[64]u8) []const u8 {
    var addr: std.os.linux.sockaddr = undefined;
    var len: std.os.linux.socklen_t = @sizeOf(std.os.linux.sockaddr);
    if (std.os.linux.getpeername(stream.socket.handle, &addr, &len) != 0) return "?";
    if (addr.family != std.os.linux.AF.INET) return "?";
    const in: *const std.os.linux.sockaddr.in = @ptrCast(@alignCast(&addr));
    const quad = @as([4]u8, @bitCast(in.addr));
    const port = std.mem.bigToNative(u16, in.port);
    return std.fmt.bufPrint(buf, "{d}.{d}.{d}.{d}:{d}", .{ quad[0], quad[1], quad[2], quad[3], port }) catch "?";
}

fn sendPacket(io: Io, stream: Io.net.Stream, data: []const u8) !void {
    var sbuf: [4096]u8 = undefined;
    var out = stream.writer(io, &sbuf);
    try out.interface.writeAll(data);
    try out.interface.flush();
}

fn handlePacket(io: Io, stream: Io.net.Stream, tag: []const u8, header: u8, body: []const u8, cap: *const Replay.Cap, pushed: *bool) !void {
    var raw = body;
    if (header & 0x20 != 0) raw = try Codec.inflateZlib(heap, body);
    const outer = try Codec.parseOuter(heap, raw);

    log("[{s}] -> c={d} a={d}\n", .{ tag, outer.controller, outer.action });

    if (outer.controller == 0 and outer.action == 0) {
        try sendPacket(io, stream, try System.handshake(heap));
        log("[{s}] <- handshake\n", .{tag});
    } else if (outer.controller == 0 and outer.action == 1) {
        try sendPacket(io, stream, try System.login(heap, cap.login));
        log("[{s}] <- login\n", .{tag});
    } else if (outer.controller == 1) {
        const cmd = asStr(entryVal(outer.params, "c"));
        const innerV = entryVal(outer.params, "p") orelse Codec.Val{ .obj = &.{} };
        const inner: []const Codec.Entry = if (innerV == .obj) innerV.obj else &.{};
        const dal0 = asI32(entryVal(inner, "dal0"), 0);
        const act0 = asI32(entryVal(inner, "act0"), 0);

        if (std.mem.eql(u8, cmd, "ServerExtension") and dal0 == 21 and act0 == 1) {
            try sendPacket(io, stream, try Town.platform(heap, cap.char));
            log("[{s}] <- platform-login\n", .{tag});
        } else if (std.mem.eql(u8, cmd, "InstanceExtension")) {
            const room = asI32(entryVal(outer.params, "r"), 0);
            const dest = asI32(entryVal(inner, "ins2"), 0);
            const spd = asF32(entryVal(inner, "ins3"), 1);
            try sendPacket(io, stream, try Town.instanceEcho(heap, room, act0, selfId(cap), dest, spd));
            log("[{s}] <- act0={d} tile={d}\n", .{ tag, act0, dest });
        } else {
            const now = Io.Clock.real.now(io).toMilliseconds();
            try sendPacket(io, stream, try Town.ack(heap, dal0, act0, cap.books, now));
            log("[{s}] <- ack dal0={d} act0={d}\n", .{ tag, dal0, act0 });
            if (std.mem.eql(u8, cmd, "ServerExtension") and dal0 == 1 and act0 == 80 and !pushed.*) {
                if (cap.enter) |enter| {
                    pushed.* = true;
                    try sendPacket(io, stream, try Town.enterPush(heap, enter));
                    log("[{s}] <- push enter-town\n", .{tag});
                }
            }
        }
    } else {
        log("[{s}] -> unknown c={d} a={d}\n", .{ tag, outer.controller, outer.action });
    }
}

pub fn listen(io: Io, stream: Io.net.Stream, cap: *const Replay.Cap) void {
    var listener = stream;
    defer listener.close(io);

    var buf: [64]u8 = undefined;
    const peerListener = peer(listener, &buf);

    log("[{s}] -> connect\n", .{peerListener});
    defer log("[{s}] <- close\n", .{peerListener});
    var acc: std.ArrayList(u8) = .empty;
    var off: usize = 0;
    var pushed = false;
    var first = true;
    var tmp: [8192]u8 = undefined;

    while (true) {
        var bufs = [_][]u8{tmp[0..]};
        const got = listener.read(io, &bufs) catch break;
        if (got == 0) break;
        if (first) {
            first = false;
            if (Http.isHttp(tmp[0..got])) {
                Http.serve(io, listener, tmp[0..got]);
                return;
            }
        }
        acc.appendSlice(heap, tmp[0..got]) catch break;
        while (true) {
            const fr = Codec.nextFrame(acc.items, &off) catch {
                log("[{s}] <- bad frame\n", .{peerListener});
                off = 0;
                acc.clearRetainingCapacity();
                break;
            } orelse break;
            handlePacket(io, listener, peerListener, fr.header, fr.body, cap, &pushed) catch |err| log("[{s}] <- err {any}\n", .{ peerListener, err });
        }
        if (off > 0) {
            const remain = acc.items.len - off;
            std.mem.copyForwards(u8, acc.items[0..remain], acc.items[off..]);
            acc.shrinkRetainingCapacity(remain);
            off = 0;
        }
    }
}
