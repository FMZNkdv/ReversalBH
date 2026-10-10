const std = @import("std");
const Io = std.Io;
const heap = std.heap.page_allocator;
const PORT: u16 = 8080;
const log = std.debug.print;
const Replay = @import("Sfs/Replay.zig");
const Session = @import("Net/Session.zig");

var capture: Replay.Cap = .{ .login = null, .char = null, .enter = null, .books = null };

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    capture = try Replay.load(heap, io, "capture");

    const host = try Io.net.IpAddress.parse("0.0.0.0", PORT);
    var listener = try host.listen(io, .{ .reuse_address = true });
    defer listener.deinit(io);

    log("[0.0.0.0:{d}] running in {d}!\n", .{ PORT, PORT });

    while (true) {
        const stream = listener.accept(io) catch continue;
        const tread = std.Thread.spawn(.{}, Session.listen, .{ io, stream, &capture }) catch {
            var straem = stream;
            straem.close(io);
            continue;
        };
        tread.detach();
    }
}
